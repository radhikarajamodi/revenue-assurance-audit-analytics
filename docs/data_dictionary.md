# Data dictionary — SYNTHETIC

Generated from the actual SQLite schema. Dates are ISO `YYYY-MM-DD`; date-only granularity has no intraday ordering. All monetary fields use integer USD cents; quantities and IDs are integers. An INTEGER PRIMARY KEY is non-null even where SQLite PRAGMA reports `notnull=0`. No names represent real people or customers.

## accounts

Simplified chart: cash, AR, deposits, opening equity, revenue and sales returns.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| account_id | TEXT | PK position 1 |  |
| name | TEXT | NOT NULL |  |

## activity_logs

System activity with employee and invoice/journal links; supports observed duties and permission tests.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| log_id | INTEGER | PK position 1 |  |
| employee_id | INTEGER |  | employees. |
| action | TEXT | NOT NULL |  |
| activity_date | TEXT | NOT NULL |  |
| invoice_id | INTEGER |  | invoices. |
| journal_id | INTEGER |  | journal_entries. |

## allocations

Dated application of receipt cents to an invoice; partial and multiple receipts are supported. Payer/date/cumulative balance business rules are intentionally tested rather than constrained away.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| allocation_id | INTEGER | PK position 1 |  |
| payment_id | INTEGER |  | payments. |
| invoice_id | INTEGER |  | invoices. |
| allocation_date | TEXT | NOT NULL |  |
| amount_cents | INTEGER |  |  |

## approvals

Journal approval actor/date/status; tested for independence, permission and timeliness.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| approval_id | INTEGER | PK position 1 |  |
| journal_id | INTEGER |  | journal_entries. |
| approved_by | INTEGER |  | employees. |
| approval_date | TEXT | NOT NULL |  |
| status | TEXT | NOT NULL |  |

## branches

Fictional operating locations; branch scope derives from the order except GL postings use journal branch.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| branch_id | INTEGER | PK position 1 |  |
| name | TEXT | NOT NULL |  |

## credit_memos

Dated AR/revenue reduction; return_id may be NULL for an unsupported commercial credit seed.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| credit_id | INTEGER | PK position 1 |  |
| invoice_id | INTEGER |  | invoices. |
| return_id | INTEGER |  | returns. |
| credit_date | TEXT | NOT NULL |  |
| amount_cents | INTEGER |  |  |

## customers

Synthetic account identifiers and contractual payment terms. No personal or contact information.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| customer_id | INTEGER | PK position 1 |  |
| name | TEXT | NOT NULL |  |
| terms_days | INTEGER | NOT NULL |  |

## employee_roles

Static extract of employee role assignments; no effective-date history.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| employee_id | INTEGER | PK position 1 | employees. |
| role_id | TEXT | PK position 2 | roles. |

## employees

Synthetic users; branch is an organizational attribute, not a branch-access entitlement.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| employee_id | INTEGER | PK position 1 |  |
| name | TEXT | NOT NULL |  |
| branch_id | INTEGER |  | branches. |

## invoice_lines

Billed quantities/prices linked to order lines; header and line totals are reconciled independently.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| invoice_id | INTEGER | PK position 1 | invoices. |
| line_no | INTEGER | PK position 2 |  |
| order_id | INTEGER |  | order_lines.order_id |
| line_ref | INTEGER |  | order_lines.line_no |
| quantity | INTEGER |  |  |
| unit_price_cents | INTEGER |  |  |

## invoices

Billing header and separate recorded recognition date. Invoice_no deliberately is not unique to allow duplicate billing seeds.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| invoice_id | INTEGER | PK position 1 |  |
| invoice_no | TEXT | NOT NULL |  |
| order_id | INTEGER | NOT NULL | orders. |
| invoice_date | TEXT | NOT NULL |  |
| due_date | TEXT | NOT NULL |  |
| recognition_date | TEXT | NOT NULL |  |
| amount_cents | INTEGER | NOT NULL |  |
| created_by | INTEGER |  | employees. |

## journal_entries

Accounting event and posting dates; source type and source record linkage. Manual journals require authorization and approval testing.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| journal_id | INTEGER | PK position 1 |  |
| entry_date | TEXT | NOT NULL |  |
| posting_date | TEXT | NOT NULL |  |
| source_type | TEXT | NOT NULL |  |
| invoice_id | INTEGER |  | invoices. |
| payment_id | INTEGER |  | payments. |
| credit_id | INTEGER |  | credit_memos. |
| branch_id | INTEGER |  | branches. |
| prepared_by | INTEGER |  | employees. |
| manual | INTEGER | NOT NULL |  |

## journal_lines

Positive debit or credit integer cents per account; exactly one side per line. Journal balancing is an aggregate test.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| journal_id | INTEGER | PK position 1 | journal_entries. |
| line_no | INTEGER | PK position 2 |  |
| account_id | TEXT |  | accounts. |
| debit_cents | INTEGER | NOT NULL |  |
| credit_cents | INTEGER | NOT NULL |  |

## metadata

Synthetic classification, fixed seed, fiscal year and generator version.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| key | TEXT | PK position 1 |  |
| value | TEXT | NOT NULL |  |

## order_lines

Order detail; quantity × unit_price_cents gives ordered line value.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| order_id | INTEGER | PK position 1 | orders. |
| line_no | INTEGER | PK position 2 |  |
| product_id | INTEGER |  | products. |
| quantity | INTEGER |  |  |
| unit_price_cents | INTEGER |  |  |

## orders

Customer order and originating branch; customer, branch and creator are foreign keys.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| order_id | INTEGER | PK position 1 |  |
| customer_id | INTEGER | NOT NULL | customers. |
| branch_id | INTEGER | NOT NULL | branches. |
| order_date | TEXT | NOT NULL |  |
| created_by | INTEGER |  | employees. |

## payments

Bank receipt event and remitting customer; no bank accounts or real financial records.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| payment_id | INTEGER | PK position 1 |  |
| customer_id | INTEGER |  | customers. |
| payment_date | TEXT | NOT NULL |  |
| amount_cents | INTEGER |  |  |

## permissions

Allowed action per role; one role can permit several actions.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| role_id | TEXT | PK position 1 | roles. |
| action | TEXT | PK position 2 |  |

## products

Fictional automotive parts with integer cent prices.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| product_id | INTEGER | PK position 1 |  |
| name | TEXT |  |  |
| unit_price_cents | INTEGER | NOT NULL |  |

## returns

Accepted synthetic return receipt and value. Inventory and COGS effects are out of scope.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| return_id | INTEGER | PK position 1 |  |
| invoice_id | INTEGER |  | invoices. |
| return_date | TEXT | NOT NULL |  |
| amount_cents | INTEGER |  |  |

## roles

Named business-system role catalog.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| role_id | TEXT | PK position 1 |  |

## shipment_lines

Quantity shipped against a specific order line. Shipment valuation uses order unit price.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| shipment_id | INTEGER | PK position 1 | shipments. |
| line_no | INTEGER | PK position 2 |  |
| order_id | INTEGER |  | order_lines.order_id |
| line_ref | INTEGER |  | order_lines.line_no |
| quantity | INTEGER |  |  |

## shipments

Dispatch evidence at date granularity. One order can have multiple shipments.

| Column | SQLite type | Required / key | References |
|---|---|---|---|
| shipment_id | INTEGER | PK position 1 |  |
| order_id | INTEGER | NOT NULL | orders. |
| ship_date | TEXT | NOT NULL |  |
| shipped_by | INTEGER |  | employees. |

## Derived views

| View | Purpose |
|---|---|
| v_order_totals | Independent order line value |
| v_shipment_totals | Shipment count, first/last dates and shipped value |
| v_gl_invoice | Independently aggregated AR/revenue posting support |
| v_invoice_evidence | Reconciled invoice/order/shipment/GL fields and duplicate rank |
| v_manual_evidence | Manual authorization and independent timely approval |
| v_permission_conflicts | Conflicting billing and cash permissions |
| v_exception_core / v_exceptions | Transaction exceptions and stable display order |
| v_line_issues | Missing/inconsistent quantities, prices or fulfillment links |
| v_credit_support_issues | Missing/inconsistent return support |

The separate `data/ground_truth/labels.sqlite` contains `labels(rule_id TEXT, risk_key TEXT, reason TEXT)` with a composite primary key. It is excluded from detector inputs.

`risk_key` is an economic invoice (`INV:`), journal (`JE:`), or receipt (`PAY:`). `discrepancy_cents` denotes measured arithmetic difference; `exposure_cents` is an investigation estimate. Neither is actual loss. Report IDs are display identifiers derived from sorted SQL results, not permanent workflow case IDs.
