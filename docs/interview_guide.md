# Explaining the project in an interview

## A 90-second explanation

“I built an accounting-focused revenue assurance case for a fictional automotive parts distributor. The challenge was that an invoice, a shipment, a cash receipt and a GL posting represent different events, so a sales dashboard alone would miss cutoff and control problems. I generated about twelve thousand invoices with related orders, shipments, payments, partial applications, returns, credits and balanced journal entries. Every monetary calculation uses integer cents.

“I used SQLite for transaction matching, cutoff tests and accounting rollforwards; Python and pandas for orchestration and exports; and Streamlit/Plotly for investigation. The system links exceptions back to evidence and an accounting assertion. A separate answer key evaluates seeded problems without giving the detector access to those labels. I also tested clean edge cases, such as partial cash, a full credit, an unapplied advance and a split shipment.

“The actual result is in the generated workpapers: 12,024 invoices and 222 transaction exception rows, with overlapping rules grouped into 197 economic items. At year-end, subledger AR is $1,912,899.34 and GL AR is $1,924,878.04; a bridge explains the $11,978.70 difference. That is an explained discrepancy, not a clean reconciliation or a proven loss. My conservative exposure envelope is $133,727.95, not a proposed adjustment.

“An auditor would next validate extract completeness, inspect contracts and carrier evidence, confirm selected balances, inspect bank receipts and approvals, resolve false positives, and support any correction. I would prioritize shipment-linked billing, independent journal approval and validated cash application, then retest the controls.”

**Verification evidence:** 38 pytest tests and 81 SQL validation checks passed. The real Streamlit app rendered all six tabs in headless Chrome with no page errors; CSV and Excel downloads were checked against the underlying data. Six real screenshots and machine-readable verification records are included. The Python package pins are recorded for the tested macOS environment. Fixture success is not a real-world audit opinion or production accuracy claim.

## Questions to expect

- **Why not recognize revenue when paid?** The model is accrual accounting: assumed control transfer triggers revenue, while collections reduce AR.
- **Why shipping point?** It is an explicit fictional contract assumption. Real ASC 606 work requires the entire contract and transfer-of-control facts; shipment terms alone are insufficient.
- **What does a balanced journal prove?** Equal debits and credits, not the validity, date, authorization or account mapping of the entry.
- **What did reconciliation add?** A monthly rollforward and independently attributed GL bridge; aging must sum to the same subledger amount. Cross-customer application can leave company AR unchanged.
- **Why separate ground truth?** To measure synthetic detection without target leakage. It validates planted scenarios, not real-world precision or recall.
- **How did you avoid double counting?** Use a canonical invoice/journal/receipt key, take the maximum estimate across rules for each economic item, then sum. This is conservative and may understate separate errors on one item.
- **What is confirmed?** Arithmetic differences are confirmed within this synthetic extract. Accounting errors, fraud and actual losses are not confirmed without independent evidence.
- **What would you improve?** Historical entitlement snapshots, event timestamps, independent bank/shipping feeds, line-level revenue obligations, tax/COGS and allowance models, broader adversarial fixtures, and performance testing on larger populations.

Use `reports/summary.json` after regeneration as the source of current numbers; update this guide if the generator changes. Never claim the fictional recommendations created savings, reduced actual losses or improved a real company's controls.
