-- Deterministic synthetic fixture. Seed 606; no runtime clock or floating money.
BEGIN;
INSERT INTO metadata VALUES('classification','SYNTHETIC — fictional educational data'),('seed','606'),('fiscal_year','2025'),('generator_version','1');
INSERT INTO branches VALUES(1,'North Bay'),(2,'Central Valley'),(3,'Coastal'),(4,'South Bay');
WITH RECURSIVE n(x) AS(VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<240)
INSERT INTO customers SELECT x,printf('Synthetic Customer %03d',x),CASE WHEN x%4=0 THEN 45 ELSE 30 END FROM n;
INSERT INTO employees VALUES(1,'Synthetic Sales Clerk',1),(2,'Synthetic Warehouse Clerk',1),(3,'Synthetic AR Clerk',2),(4,'Synthetic Controller',3),(5,'Synthetic GL Accountant',4),(6,'Synthetic Branch Manager',2);
INSERT INTO roles VALUES('sales'),('warehouse'),('cash'),('gl'),('approver');
INSERT INTO permissions VALUES('sales','create_invoice'),('warehouse','ship'),('cash','apply_cash'),('gl','post_manual'),('approver','approve_manual');
INSERT INTO employee_roles VALUES(1,'sales'),(2,'warehouse'),(3,'cash'),(4,'approver'),(5,'gl'),(6,'sales'),(6,'cash');
INSERT INTO products VALUES(1,'Brake pad set',12995),(2,'Oil filter',1895),(3,'Alternator',24995),(4,'Drive belt',4595),(5,'Battery',15995),(6,'Spark plug pack',3895);
CREATE TEMP TABLE seq AS WITH RECURSIVE n(x) AS(VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<12000) SELECT x FROM n;
-- Larger allocations in March-August and November-December; deterministic permutation within months.
CREATE TEMP TABLE schedule AS SELECT x,
 CASE WHEN x<=650 THEN 1 WHEN x<=1350 THEN 2 WHEN x<=2450 THEN 3 WHEN x<=3500 THEN 4 WHEN x<=4650 THEN 5 WHEN x<=5850 THEN 6 WHEN x<=7050 THEN 7 WHEN x<=8200 THEN 8 WHEN x<=9150 THEN 9 WHEN x<=10100 THEN 10 WHEN x<=11000 THEN 11 ELSE 12 END AS month FROM seq;
INSERT INTO orders SELECT x,CASE WHEN x%10<3 THEN 1+x%3 ELSE 4+(x*37+606)%237 END,1+x%4,
 date(printf('2025-%02d-01',month),printf('+%d days',(x*17+606)%25)),CASE WHEN x%500=40 THEN 6 ELSE 1 END FROM schedule;
-- Keep deliberately backdated recognition within fiscal 2025.
UPDATE orders SET order_date='2025-02-01' WHERE order_id IN (31,531);
INSERT INTO order_lines SELECT order_id,1,1+order_id%6,1+(order_id*13)%12,p.unit_price_cents FROM orders JOIN products p ON p.product_id=1+order_id%6;
INSERT INTO order_lines SELECT order_id,2,2,2+order_id%5,1895 FROM orders;
INSERT INTO shipments SELECT order_id,order_id,date(order_date,'+2 days'),2 FROM orders WHERE order_id%500<>20;
INSERT INTO shipment_lines SELECT s.shipment_id,l.line_no,l.order_id,l.line_no,l.quantity FROM shipments s JOIN order_lines l USING(order_id);
-- Clean split shipment: total quantity conserved and last shipment controls recognition.
INSERT INTO shipments SELECT 20001,101,date(order_date,'+3 days'),2 FROM orders WHERE order_id=101;
UPDATE shipment_lines SET quantity=quantity-1 WHERE shipment_id=101 AND line_no=2;
INSERT INTO shipment_lines VALUES(20001,2,101,2,1);
INSERT INTO invoices SELECT o.order_id,printf('SYN-2025-%05d',o.order_id),o.order_id,date(o.order_date,'+2 days'),date(o.order_date,'+2 days',printf('+%d days',c.terms_days)),
 CASE WHEN o.order_id%500=30 THEN date(o.order_date,'+1 day') WHEN o.order_id%500=31 THEN date(o.order_date,'start of month','-1 day') WHEN o.order_id=101 THEN date(o.order_date,'+3 days') ELSE date(o.order_date,'+2 days') END,
 sum(l.quantity*l.unit_price_cents)+CASE WHEN o.order_id%500=50 THEN 2500 ELSE 0 END,o.created_by
 FROM orders o JOIN customers c USING(customer_id) JOIN order_lines l USING(order_id) GROUP BY o.order_id;
INSERT INTO invoice_lines SELECT order_id,line_no,order_id,line_no,quantity,unit_price_cents FROM order_lines;
-- Duplicate billing (same source order, lines and invoice number; a second accounting event).
INSERT INTO invoices SELECT invoice_id+12000,invoice_no,order_id,invoice_date,due_date,recognition_date,amount_cents,created_by FROM invoices WHERE invoice_id%500=10;
INSERT INTO invoice_lines SELECT i.invoice_id,l.line_no,l.order_id,l.line_no,l.quantity,l.unit_price_cents FROM invoices i JOIN order_lines l USING(order_id) WHERE i.invoice_id>12000;
INSERT INTO returns SELECT invoice_id,invoice_id,date(invoice_date,'+10 days'),CASE WHEN invoice_id=103 THEN amount_cents ELSE amount_cents/5 END FROM invoices WHERE (invoice_id%23=0 OR invoice_id=103) AND invoice_id<=12000;
INSERT INTO credit_memos SELECT return_id,invoice_id,return_id,return_date,amount_cents FROM returns;
-- Add an unsupported excess credit on one open invoice, still posted consistently.
INSERT INTO credit_memos SELECT 20001,107,NULL,date(invoice_date,'+3 days'),amount_cents+5000 FROM invoices WHERE invoice_id=107;
CREATE TEMP TABLE collectible AS SELECT i.*,o.customer_id,i.amount_cents-coalesce(c.amount_cents,0) AS net_cents,
 date(i.invoice_date,printf('+%d days',CASE WHEN o.customer_id<=3 THEN 75+i.invoice_id%40 WHEN o.customer_id%9=0 THEN 50+i.invoice_id%35 WHEN i.invoice_id%7=0 THEN 5+i.invoice_id%5 ELSE 8+i.invoice_id%20 END)) AS cash_date
 FROM invoices i JOIN orders o USING(order_id) LEFT JOIN credit_memos c USING(invoice_id) WHERE i.invoice_id<=12000 AND i.invoice_id%11<>0 AND i.invoice_id<>107;
INSERT INTO payments SELECT invoice_id,customer_id,cash_date,CASE WHEN invoice_id%7=0 THEN net_cents/2 ELSE net_cents END FROM collectible WHERE net_cents>0;
INSERT INTO allocations SELECT payment_id,payment_id,payment_id,payment_date,amount_cents FROM payments;
-- The remaining half arrives later; invoices divisible by 91 can stay partially unpaid.
INSERT INTO payments SELECT invoice_id+20000,customer_id,date(cash_date,'+20 days'),net_cents-net_cents/2 FROM collectible WHERE net_cents>0 AND invoice_id%7=0 AND invoice_id%13<>0;
INSERT INTO allocations SELECT payment_id,payment_id,payment_id-20000,payment_date,amount_cents FROM payments WHERE payment_id>20000;
-- Clean advance cash held in customer deposits, and unapplied receipt.
INSERT INTO payments VALUES(50001,240,'2025-12-28',150000);
-- Cash application defects: wrong customer, pre-receipt date, and excess allocation.
UPDATE allocations SET invoice_id=102 WHERE allocation_id=104;
UPDATE allocations SET allocation_date='2025-01-01' WHERE allocation_id=105;
UPDATE allocations SET amount_cents=amount_cents+10000 WHERE allocation_id=106;
INSERT INTO accounts VALUES('1000','Cash'),('1100','Accounts receivable'),('2100','Customer deposits'),('3000','Opening equity'),('4000','Parts revenue'),('4090','Sales returns and allowances');
-- Greenfield business: explicit zero beginning AR, no hidden opening plugs.
INSERT INTO journal_entries SELECT invoice_id,recognition_date,
 CASE WHEN invoice_id%500=32 THEN date(recognition_date,'start of month','+1 month') ELSE recognition_date END,
 'invoice',invoice_id,NULL,NULL,o.branch_id,5,0 FROM invoices i JOIN orders o USING(order_id);
INSERT INTO journal_lines SELECT journal_id,1,'1100',i.amount_cents+CASE WHEN i.invoice_id%500=60 THEN 4000 ELSE 0 END,0 FROM journal_entries j JOIN invoices i USING(invoice_id);
INSERT INTO journal_lines SELECT journal_id,2,'4000',0,i.amount_cents+CASE WHEN i.invoice_id%500=60 THEN 4000 ELSE 0 END FROM journal_entries j JOIN invoices i USING(invoice_id);
INSERT INTO journal_entries SELECT 100000+p.payment_id,p.payment_date,p.payment_date,'payment',NULL,p.payment_id,NULL,coalesce(o.branch_id,4),3,0 FROM payments p LEFT JOIN invoices i ON i.invoice_id=CASE WHEN p.payment_id>20000 THEN p.payment_id-20000 ELSE p.payment_id END LEFT JOIN orders o USING(order_id);
INSERT INTO journal_lines SELECT j.journal_id,1,'1000',p.amount_cents,0 FROM journal_entries j JOIN payments p USING(payment_id);
INSERT INTO journal_lines SELECT j.journal_id,2,CASE WHEN p.payment_id=50001 THEN '2100' ELSE '1100' END,0,p.amount_cents FROM journal_entries j JOIN payments p USING(payment_id);
INSERT INTO journal_entries SELECT 200000+c.credit_id,c.credit_date,c.credit_date,'credit',c.invoice_id,NULL,c.credit_id,o.branch_id,3,0 FROM credit_memos c JOIN invoices i USING(invoice_id) JOIN orders o USING(order_id);
INSERT INTO journal_lines SELECT j.journal_id,1,'4090',c.amount_cents,0 FROM journal_entries j JOIN credit_memos c USING(credit_id);
INSERT INTO journal_lines SELECT j.journal_id,2,'1100',0,c.amount_cents FROM journal_entries j JOIN credit_memos c USING(credit_id);
INSERT INTO journal_entries VALUES(300001,'2025-12-31','2025-12-31','manual',NULL,NULL,NULL,1,1,1),(300002,'2025-12-31','2025-12-31','manual',NULL,NULL,NULL,2,5,1),(300003,'2025-12-31','2025-12-31','manual',NULL,NULL,NULL,3,5,1),(300004,'2025-12-31','2025-12-31','manual',NULL,NULL,NULL,4,5,1);
INSERT INTO journal_lines VALUES(300001,1,'1100',800000,0),(300001,2,'4000',0,800000),(300002,1,'1100',250000,0),(300002,2,'4000',0,250000),(300003,1,'1100',100000,0),(300003,2,'4000',0,100000),(300004,1,'1100',50000,0),(300004,2,'4000',0,50000);
INSERT INTO approvals VALUES(1,300001,1,'2025-12-31','approved'),(2,300002,5,'2025-12-31','approved'),(3,300003,4,'2026-01-02','approved'),(4,300004,4,'2025-12-31','approved');
INSERT INTO activity_logs SELECT invoice_id,created_by,'create_invoice',invoice_date,invoice_id,NULL FROM invoices;
INSERT INTO activity_logs SELECT 100000+allocation_id,CASE WHEN invoice_id%500=40 THEN 6 ELSE 3 END,'apply_cash',allocation_date,invoice_id,NULL FROM allocations;
INSERT INTO activity_logs SELECT 1000000+journal_id,prepared_by,'post_manual',posting_date,NULL,journal_id FROM journal_entries WHERE manual=1;
INSERT INTO activity_logs SELECT 2000000+approval_id,approved_by,'approve_manual',approval_date,NULL,journal_id FROM approvals;
DROP TABLE seq; DROP TABLE schedule; DROP TABLE collectible;
COMMIT;
