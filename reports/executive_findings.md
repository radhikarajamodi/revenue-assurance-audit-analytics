# Executive findings — SYNTHETIC

As of 2025-12-31: 12,024 invoices. These are analytical exceptions in a fictional dataset, not audit findings or proven fraud.

| Rule | Exceptions |
|---|---:|
| AMOUNT_MISMATCH | 48 |
| APPROVAL_FAILURE | 3 |
| CASH_CUSTOMER | 1 |
| CASH_OVERALLOCATED | 1 |
| CASH_TIMING | 1 |
| CREDIT_EXCESS | 1 |
| DUPLICATE | 24 |
| EARLY_REVENUE | 48 |
| MANUAL_UNAUTHORIZED | 1 |
| NO_SHIPMENT | 24 |
| SOD | 22 |
| WRONG_PERIOD | 48 |

Ending AR subledger: $1,912,899.34; GL AR: $1,924,878.04; difference: $11,978.70. The bridge in `bridge.csv` explains this difference in full. The reconciled bridge does not make the original records correct.

Conservative estimated potential exposure: $133,727.95. Unique flagged transaction value: $212,800.75. Quantified arithmetic differences: $1,710.00; these are extract discrepancies, not confirmed misstatements. Actual loss: **not assessed**. Never add rule exposure subtotals.

Immediate: restrict manual posting and require independent approval before release (IT access owner / controller). Within 30 days: enforce shipment-linked billing, duplicate blocks, validated cash application and daily GL interface reconciliation (billing / AR managers). Within 60 days: review repeat late payers, concentration and credit limits (credit manager). See controls.csv for individual thresholds, owners and evidence.

Next audit steps: validate extract completeness to independent control totals; inspect contracts, carrier evidence, bank statements and approvals; investigate false positives; propose supported correcting entries; retest remediation. No automatic correction is posted.
