# Accounting methodology — synthetic educational model

Northstar Parts is a fictional four-branch automotive parts distributor. All names, events, balances and findings in this repository are synthetic. This is a portfolio case study, with no Big Four affiliation and no audit opinion. Fiscal year: January 1–December 31, 2025. Currency: USD; accounting amounts are integer cents throughout SQLite, Python, SQL, CSV and Excel. Chart plotting or percentage presentation must not feed back into accounting logic.

## Recognition and accounting assumptions

The fictional contracts specify ordinary shipping-point sales with no unusual acceptance, repurchase or consignment conditions. Shipment is assumed to evidence transfer of control. Actual ASC 606 conclusions depend on the enforceable contract, performance obligations, acceptance provisions and full facts. Shipping terms alone do not establish the conclusion. See the [FASB Topic 606 project](https://fasb.org/projects/recently-completed-projects/revenue-recognition-summary) and [FASB post-implementation review](https://storage.fasb.org/Post-Implementation%20Review%E2%80%94Revenue%20from%20Contracts%20with%20Customers%20%28Topic%20606%29.pdf) for the control-transfer principle.

| Event | Debit | Credit | Measurement / effective date |
|---|---|---|---|
| Ordinary credit sale | 1100 AR | 4000 Parts revenue | Invoice cents; recognition date should follow transfer of control |
| Cash applied to AR | 1000 Cash | 1100 AR | Receipt cents at cash receipt / GL posting; allocations are separate subledger events |
| Unallocated customer advance | 1000 Cash | 2100 Customer deposits | Receipt date; excluded from AR collections until applied |
| Accepted return / credit | 4090 Sales returns | 1100 AR | Credit amount and credit date; reduces net revenue |
| Manual AR/revenue adjustment | As specified by journal | As specified by journal | Entry and posting dates; requires appropriate access and independent approval |

This is a greenfield business with **zero initial AR at January 1, 2025**. There is no balancing plug. The approved manual journal is still an unreconciled subledger adjustment: authorization does not establish that a posting is correct. Manual journal support must determine whether to add a legitimate subledger adjustment or reverse an erroneous GL posting.

Invoice date records billing; order date records customer commitment; shipment date is the assumed evidence of control transfer; recognition date is the date recorded by the billing/accounting system; cash date is receipt; allocation date is AR application; GL entry date is accounting event date; posting date controls the GL reporting period in this simplified model. These are distinct fields. We deliberately inject inconsistent dates. A delayed posting affects period totals even if the effective entry date is earlier.

Most orders are one shipment. The clean split shipment (order 101) recognizes the entire invoice on final dispatch; no interim revenue is assumed for that specific contract. This rule is conservative and would need line-level performance-obligation treatment for other real partial-delivery contracts. Shipment value uses order unit prices, rather than a price stored on shipping documents. This is a valuation cross-check, not an independent selling-price confirmation.

## AR reconciliation

For any selected as-of date, period start is the first day of that month:

`Beginning AR + recognized credit sales − dated cash applications − dated credits = ending subledger AR`

Beginning AR uses all prior-dated subledger events. Ending AR and invoice aging use recognition, allocation and credit dates independently. A deliberately premature allocation can create a credit balance **before the invoice is recognized**; the aging query retains it rather than losing that bad application. Negative balances remain visible. Future cash and credits are excluded. The unpaid portion of partial payments remains open.

`GL AR − ending subledger AR = invoice amount/posting bridge + cash application bridge + credit bridge + manual/opening bridge`

SQL independently aggregates each side. The application raises an error if the bridge does not equal the observed difference or aging does not equal the subledger. A bridge that explains a difference does not resolve it. Receipts and allocations have different accounting roles: unallocated advances do not reduce AR, and misapplied cash can leave total company AR unchanged while customer balances are wrong. The branches on GL receipts reflect the originating invoice; a wrong application can create branch differences as well.

Revenue reconciliation compares YTD recognized gross invoices less dated credits to GL revenue net of returns by posting date. It includes manual revenue journals and posting differences. It does not use cash as a proxy for revenue.

## Exception and exposure interpretation

Each rule's assertion, evidence, SQL/Python logic, threshold, severity, exposure basis, false positives and investigation are in `docs/risk_control_matrix.csv` and the Excel matrix. SQL views contain the actual detector logic. The detector database contains no planted labels; the separately generated `data/ground_truth/labels.sqlite` is used only to evaluate fixture detection.

- **Flagged transaction value:** sum of the maximum underlying transaction value per invoice, manual journal or receipt among selected exceptions. This describes the workpaper population, not misstatement.
- **Estimated potential exposure:** maximum rule estimate per economic item (invoice, journal, or receipt), then sum across those items. Overlapping tests never add the same item's estimates. This conservative envelope can understate separate independent errors on one item and is **not** a statistical estimate, expected loss, or proposed adjustment.
- **Quantified arithmetic difference:** maximum measured numerical inconsistency per economic item, then sum. These demonstrate discrepancies within the extract. Confirmed business discrepancies / accounting misstatements require investigation against independent evidence and remain **unconfirmed** here.
- **Actual loss:** not assessed. Duplicate billing, cutoff differences, control conflicts and concentration are not proof of cash loss or fraud.

Timing exposure is the full invoice amount potentially affecting period recognition; it can reverse in a later period. Amount-matching exposure is the largest absolute difference across order, invoice header/lines, shipment and GL amounts. Missing shipments use full invoice support exposure. Unauthorized/manual approval tests use gross journal debits. Cash tests use the affected application or excess receipt allocation. Credits use the amount above the invoice. A permissions conflict, repeated late payments or customer concentration does not by itself estimate monetary loss, so its exposure is zero. Do not add totals displayed per rule; filters recompute the maximum per selected item.

High priority means unsupported recognition, an accuracy difference or an authorization failure with a direct revenue-cycle consequence. Medium priority means date validation or collection-risk indicators needing follow-up. Investigators consider assertion, evidence, age, amount and context. No probability scores, invented likelihoods or fraud scores are assigned.

## Control testing and risk indicators

The matrix distinguishes transaction procedures from two customer risk indicators. Repeat late settlement means at least three fully settled invoices with final payment after contractual due date, using only cash/credits through the as-of date. Concentration means at least 10% of recognized gross YTD invoice value. Neither threshold is an audit materiality level or an automatic allowance. Collection risk requires subsequent receipts, disputes and customer facts; aging does not estimate an allowance.

Full-extract tested population counts are disclosed alongside scope-filtered exception counts, without failure rates. Permission snapshots are static; activity logs support actual incompatible actions on the same invoice. No conclusion is made about historical role effective dates. Approval tests require an independent employee with approval permission, approved status, and approval date on or before GL posting. Date-only granularity cannot distinguish ordering within one day.

Exceptions are **retrospective**: full-extract supporting evidence is available when running the procedure, even for an earlier selected as-of date. Balance calculations themselves exclude future events. The application does not claim to reconstruct everything known to an auditor on each historical date.

## Deliberate simplifications and audit follow-up

No sales tax, discounts, freight, FX, inventory/COGS, perpetual inventory return entries, variable consideration, allowance estimation, complicated revenue contracts, netting agreements or bank reconciliation. Returns are accepted at recorded credit values; no inventory measurement conclusion is made. Customer activity is deterministic, not a fitted statistical distribution. Certain source errors are intentionally permitted as soft business rules so tests can detect them; structural foreign keys and integer money constraints are enforced.

The first real audit step is validating source-system extract completeness and accuracy against independent control totals. Then inspect contracts, shipping and carrier records, remittances and bank statements, approval evidence and subsequent activity; confirm selected AR; investigate anomalies and legitimate exceptions; propose supported corrections; evaluate deficiency severity using actual facts; and retest remediation. The synthetic answer key is not audit evidence.

## Cent allocation policy

Synthetic percentage returns use integer division by five (round down to a whole cent). A two-part cash settlement allocates `net_cents // 2` to the first receipt and the exact remaining cents to the second. No cent disappears through repeated rounding. This simple stated policy is part of the fictional model, not a recommendation for every contract's rounding requirements.
