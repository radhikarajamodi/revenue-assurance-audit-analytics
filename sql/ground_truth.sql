-- EVALUATION ONLY. Run against a separate database; never attach to detector DB.
CREATE TABLE labels(rule_id TEXT,risk_key TEXT,reason TEXT,PRIMARY KEY(rule_id,risk_key));
WITH RECURSIVE k(n) AS(VALUES(0) UNION ALL SELECT n+1 FROM k WHERE n<23)
INSERT INTO labels SELECT 'DUPLICATE','INV:'||(12010+500*n),'Inserted second billing for same order' FROM k
 UNION ALL SELECT 'NO_SHIPMENT','INV:'||(20+500*n),'Shipment deliberately omitted' FROM k
 UNION ALL SELECT 'EARLY_REVENUE','INV:'||(30+500*n),'Recognized one day before shipment' FROM k
 UNION ALL SELECT 'EARLY_REVENUE','INV:'||(31+500*n),'Recognized in previous month' FROM k
 UNION ALL SELECT 'WRONG_PERIOD','INV:'||(31+500*n),'Recognition month moved backward' FROM k
 UNION ALL SELECT 'WRONG_PERIOD','INV:'||(32+500*n),'GL posting moved to next month' FROM k
 UNION ALL SELECT 'AMOUNT_MISMATCH','INV:'||(50+500*n),'Header exceeds line total by 2500 cents' FROM k
 UNION ALL SELECT 'AMOUNT_MISMATCH','INV:'||(60+500*n),'GL exceeds invoice by 4000 cents' FROM k
 UNION ALL SELECT 'SOD','INV:'||(40+500*n),'Same actor creates invoice and applies cash' FROM k WHERE (40+500*n)%11<>0;
INSERT INTO labels VALUES('MANUAL_UNAUTHORIZED','JE:300001','Sales employee posts manual journal'),('APPROVAL_FAILURE','JE:300001','Self approval'),('APPROVAL_FAILURE','JE:300002','Self approval'),('APPROVAL_FAILURE','JE:300003','Approval after posting'),('CASH_CUSTOMER','PAY:104','Receipt 104 applied to customer of invoice 102'),('CASH_TIMING','PAY:105','Application dated before cash receipt'),('CASH_OVERALLOCATED','PAY:106','Application exceeds cash by 10000 cents'),('CREDIT_EXCESS','INV:107','Credit exceeds invoice by 5000 cents');
