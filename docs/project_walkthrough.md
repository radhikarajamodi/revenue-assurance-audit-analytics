# Project walkthrough

## Why I built it

I wanted to connect revenue-cycle accounting with transaction-level analysis. An order, a shipment, an invoice, a cash receipt, and a journal posting describe different events. If I treated their dates or amounts as interchangeable, I could produce a plausible dashboard while missing a cutoff error or an incorrect customer balance.

I modeled Northstar Parts, a fictional four-branch automotive parts distributor, with 12,024 invoices for fiscal 2025. All company data is synthetic. The dataset includes related orders, shipments, partial payments, returns, credits, approvals, system activity, and balanced journal entries.

## Accounting choices

I used a simplified accrual model: credit sales debit AR and credit revenue; collections debit cash and credit AR; accepted returns debit sales returns and credit AR. An unapplied customer advance goes to customer deposits until it can be applied to a sale.

For this case, I assumed shipping-point contract terms and used shipment as evidence of control transfer. I kept the shipment, invoice, recognition, collection, application, and GL posting dates separate. Actual ASC 606 conclusions would require the contract and the full transfer-of-control facts.

I stored all financial amounts in integer cents. For a two-part payment, the first receipt gets half the net amount rounded down to a cent, and the second gets the exact remainder. That keeps the applications equal to the amount due.

## How I built the analysis

SQLite holds the source records and runs the matching, cutoff, approval, aging, and reconciliation queries. Python handles the pipeline and checks the accounting identities. I used pandas and openpyxl for the workpapers, then Streamlit and Plotly for the investigation interface.

I aggregated orders, shipments, invoice lines, and GL postings independently before comparing them. This avoids multiplying amounts when a transaction has multiple lines or shipments. I also placed the planted labels in a separate database. The analysis never reads that answer key; evaluation opens it afterward to compare expected and detected exceptions.

## What the results show

The tests produced 222 transaction exception rows across 197 economic items. Several invoices triggered more than one rule, so I grouped exposure by invoice, journal, or receipt and used the largest estimate for each item. The resulting potential exposure is $133,727.95. It is an investigation measure, not a proposed adjustment or an estimate of actual loss.

At December 31, 2025, subledger AR is $1,912,899.34 and GL AR is $1,924,878.04. I explained the $11,978.70 difference through three components:

- Invoice amount and posting-date effects: −$121.30.
- Cash application effects: +$100.00.
- Manual AR journals: +$12,000.00.

The bridge accounts for the difference, but each component still needs supporting evidence and a decision about correction. An authorized manual journal, for example, can still be missing from the subledger.

The collection analysis also identifies 29 repeat late payers and two customers representing at least 10% of YTD gross invoice value. I kept these indicators separate from transaction errors because lateness or concentration alone does not establish a loss.

## What I checked

All 38 pytest tests and 81 SQL checks passed. I tested clean cases alongside the planted problems: a split shipment, a full credit, a partially paid invoice, and an unapplied advance. I checked the AR rollforward, aging, and GL bridge at multiple dates and branch scopes, and confirmed that regeneration produces the same logical records.

One useful edge case was an invalid cash application dated before its invoice was recognized. Aging initially omitted that balance. I changed the query to retain the premature application as a credit balance so the detailed aging still agrees to the subledger.

I also opened all six dashboard tabs in Chrome and checked the CSV and Excel downloads against the underlying results. The saved test reports and screenshots document those checks.

## Controls I would prioritize

I would first restrict manual journal access and require independent approval before posting. Next, I would link invoice release to shipment evidence, block duplicate billing, validate cumulative cash allocations, and reconcile the billing and GL interfaces daily. The control matrix assigns proposed owners, thresholds, and follow-up procedures.

For collections, I would review repeat late payers, disputes, subsequent receipts, and customer credit limits. I would assess any allowance separately using evidence about collectibility rather than turning an aging bucket into an automatic loss estimate.

## Limits and next steps

This model excludes taxes, FX, inventory and COGS, allowance estimation, complex contracts, and historical changes in system access. Success against deliberately planted exceptions does not establish production detection accuracy.

Before applying these procedures to a real company, I would validate extract completeness against independent control totals, inspect contracts and carrier records, confirm selected customer balances, trace receipts to bank evidence, and review approvals and compensating controls. I would then support any correcting entries and retest the affected controls.

For further development, I would add entitlement history, event timestamps, independent shipping and bank feeds, line-level revenue treatment, and more varied test scenarios. Current numerical results are recorded in `reports/summary.json`.
