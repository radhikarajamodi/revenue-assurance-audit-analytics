SELECT
(SELECT count(*) FROM invoices i JOIN orders o USING(order_id) WHERE i.recognition_date<=:as_of AND (:branch=0 OR o.branch_id=:branch)) invoice_count,
(SELECT coalesce(sum(i.amount_cents),0) FROM invoices i JOIN orders o USING(order_id) WHERE i.recognition_date BETWEEN substr(:as_of,1,4)||'-01-01' AND :as_of AND (:branch=0 OR o.branch_id=:branch)) gross_sales_cents,
(SELECT coalesce(sum(l.credit_cents-l.debit_cents),0) FROM journal_entries j JOIN journal_lines l USING(journal_id) WHERE l.account_id IN ('4000','4090') AND j.posting_date BETWEEN substr(:as_of,1,4)||'-01-01' AND :as_of AND (:branch=0 OR j.branch_id=:branch)) gl_net_revenue_cents,
(SELECT coalesce(sum(l.debit_cents-l.credit_cents),0) FROM journal_entries j JOIN journal_lines l USING(journal_id) WHERE l.account_id='1000' AND j.posting_date<=:as_of AND (:branch=0 OR j.branch_id=:branch)) cash_cents;
