-- GL uses posting date. Subledger uses recognition / allocation / credit dates.
WITH bounds AS(SELECT :as_of AS as_of,date(:as_of,'start of month') AS period_start),
sl AS (SELECT
 coalesce(sum(CASE WHEN recognition_date<period_start THEN amount_cents ELSE 0 END),0) opening_sales,
 coalesce(sum(CASE WHEN recognition_date>=period_start THEN amount_cents ELSE 0 END),0) credit_sales
 FROM invoices i JOIN orders o USING(order_id),bounds WHERE recognition_date<=as_of AND (:branch=0 OR o.branch_id=:branch)),
ca AS (SELECT coalesce(sum(CASE WHEN allocation_date<period_start THEN a.amount_cents ELSE 0 END),0) opening_collections,coalesce(sum(CASE WHEN allocation_date>=period_start THEN a.amount_cents ELSE 0 END),0) collections FROM allocations a JOIN invoices i USING(invoice_id) JOIN orders o USING(order_id),bounds WHERE allocation_date<=as_of AND (:branch=0 OR o.branch_id=:branch)),
cr AS (SELECT coalesce(sum(CASE WHEN credit_date<period_start THEN c.amount_cents ELSE 0 END),0) opening_credits,coalesce(sum(CASE WHEN credit_date>=period_start THEN c.amount_cents ELSE 0 END),0) credits FROM credit_memos c JOIN invoices i USING(invoice_id) JOIN orders o USING(order_id),bounds WHERE credit_date<=as_of AND (:branch=0 OR o.branch_id=:branch)),
gl AS (SELECT coalesce(sum(l.debit_cents-l.credit_cents),0) gl_ar FROM journal_entries j JOIN journal_lines l USING(journal_id),bounds WHERE l.account_id='1100' AND j.posting_date<=as_of AND (:branch=0 OR j.branch_id=:branch))
SELECT opening_sales-opening_collections-opening_credits AS beginning_ar_cents,credit_sales AS credit_sales_cents,collections AS collections_cents,credits AS credits_cents,
 opening_sales-opening_collections-opening_credits+credit_sales-collections-credits AS ending_ar_cents,gl_ar AS gl_ar_cents,
 gl_ar-(opening_sales-opening_collections-opening_credits+credit_sales-collections-credits) AS difference_cents FROM sl,ca,cr,gl;
