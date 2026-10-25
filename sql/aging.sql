-- Named parameters: :as_of, :branch (0 = all). Snapshot dates apply to each event.
WITH amounts AS (
 SELECT i.invoice_id,i.order_id,o.customer_id,o.branch_id,i.due_date,CASE WHEN i.recognition_date<=:as_of THEN i.amount_cents ELSE 0 END amount_cents,
 coalesce((SELECT sum(a.amount_cents) FROM allocations a WHERE a.invoice_id=i.invoice_id AND a.allocation_date<=:as_of),0) applied_cents,
 coalesce((SELECT sum(c.amount_cents) FROM credit_memos c WHERE c.invoice_id=i.invoice_id AND c.credit_date<=:as_of),0) credits_cents
 FROM invoices i JOIN orders o USING(order_id) WHERE (i.recognition_date<=:as_of OR EXISTS(SELECT 1 FROM allocations a WHERE a.invoice_id=i.invoice_id AND a.allocation_date<=:as_of) OR EXISTS(SELECT 1 FROM credit_memos c WHERE c.invoice_id=i.invoice_id AND c.credit_date<=:as_of)) AND (:branch=0 OR o.branch_id=:branch)
), balances AS (SELECT *,amount_cents-applied_cents-credits_cents balance_cents,cast(julianday(:as_of)-julianday(due_date) AS INTEGER) days_past_due FROM amounts)
SELECT *,CASE WHEN balance_cents<0 THEN 'Credit balance' WHEN days_past_due<=0 THEN 'Current' WHEN days_past_due<=30 THEN '1–30' WHEN days_past_due<=60 THEN '31–60' WHEN days_past_due<=90 THEN '61–90' ELSE '90+' END aging_bucket FROM balances ORDER BY invoice_id;
