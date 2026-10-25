import sqlite3
import pytest
from revenue_audit.analytics import query, snapshot


def scalar(con, sql, params=()):
    return con.execute(sql, params).fetchone()[0]


def test_referential_integrity_and_nonnullable_money(con):
    assert con.execute("PRAGMA foreign_key_check").fetchall() == []
    assert scalar(con, "PRAGMA integrity_check") == "ok"
    assert scalar(con, "SELECT count(*) FROM invoices") == 12024
    assert scalar(con, "SELECT count(*) FROM invoices WHERE typeof(amount_cents)<>'integer'") == 0
    with pytest.raises(sqlite3.IntegrityError):
        con.execute("UPDATE invoices SET order_id=9999999 WHERE invoice_id=1")
    with pytest.raises(sqlite3.IntegrityError):
        con.execute("UPDATE invoices SET amount_cents=1.5 WHERE invoice_id=1")


def test_every_journal_balances_and_sale_direction(con):
    assert scalar(con, "SELECT count(*) FROM (SELECT journal_id FROM journal_lines GROUP BY journal_id HAVING sum(debit_cents)<>sum(credit_cents))") == 0
    assert scalar(con, "SELECT count(*) FROM journal_entries j JOIN journal_lines l USING(journal_id) WHERE source_type='invoice' AND ((account_id='1100' AND credit_cents>0) OR (account_id='4000' AND debit_cents>0))") == 0
    cash = scalar(con, "SELECT sum(amount_cents) FROM payments")
    assert cash == scalar(con, "SELECT sum(debit_cents-credit_cents) FROM journal_lines WHERE account_id='1000'")
    credits = scalar(con, "SELECT sum(amount_cents) FROM credit_memos")
    assert credits == scalar(con, "SELECT sum(debit_cents-credit_cents) FROM journal_lines WHERE account_id='4090'")


@pytest.mark.parametrize("as_of", ["2025-01-01", "2025-03-31", "2025-12-31", "2026-03-31"])
@pytest.mark.parametrize("branch", [0, 1, 2, 3, 4])
def test_rollforward_aging_and_bridge(con, as_of, branch):
    rec = query(con, "reconciliation", as_of, branch).iloc[0]
    assert int(rec.beginning_ar_cents+rec.credit_sales_cents-rec.collections_cents-rec.credits_cents) == int(rec.ending_ar_cents)
    # Independent event-union calculation, rather than calling the reconciliation CTE again.
    expected = scalar(con, """SELECT coalesce(sum(delta),0) FROM (
        SELECT i.recognition_date d,o.branch_id b,i.amount_cents delta FROM invoices i JOIN orders o USING(order_id)
        UNION ALL SELECT a.allocation_date,o.branch_id,-a.amount_cents FROM allocations a JOIN invoices i USING(invoice_id) JOIN orders o USING(order_id)
        UNION ALL SELECT c.credit_date,o.branch_id,-c.amount_cents FROM credit_memos c JOIN invoices i USING(invoice_id) JOIN orders o USING(order_id)
        ) WHERE d<=? AND (?=0 OR b=?)""", (as_of, branch, branch))
    assert int(rec.ending_ar_cents) == expected
    assert int(query(con, "aging", as_of, branch).balance_cents.sum()) == expected
    assert int(query(con, "bridge", as_of, branch).bridge_cents.sum()) == int(rec.gl_ar_cents)-expected


def test_partial_payment_two_dates(con):
    invoice = con.execute("SELECT * FROM invoices WHERE invoice_id=119").fetchone()
    allocations = con.execute("SELECT * FROM allocations WHERE invoice_id=119 ORDER BY allocation_date").fetchall()
    assert len(allocations) == 2
    assert sum(a["amount_cents"] for a in allocations) == invoice["amount_cents"]
    first = query(con, "aging", allocations[0]["allocation_date"])
    assert int(first.set_index("invoice_id").loc[119, "balance_cents"]) == invoice["amount_cents"]-allocations[0]["amount_cents"]
    final = query(con, "aging", allocations[1]["allocation_date"])
    assert int(final.set_index("invoice_id").loc[119, "balance_cents"]) == 0


def test_full_credit_and_unapplied_advance(con):
    credit_date = scalar(con, "SELECT credit_date FROM credit_memos WHERE invoice_id=103")
    aging = query(con, "aging", credit_date).set_index("invoice_id")
    assert int(aging.loc[103, "balance_cents"]) == 0
    assert scalar(con, "SELECT count(*) FROM allocations WHERE invoice_id=103") == 0
    assert scalar(con, "SELECT sum(credit_cents) FROM journal_lines WHERE journal_id=150001 AND account_id='2100'") == 150000
    assert scalar(con, "SELECT count(*) FROM allocations WHERE payment_id=50001") == 0


def test_credit_balance_is_retained(con):
    row = query(con, "aging", "2025-12-31").set_index("invoice_id").loc[107]
    assert int(row.balance_cents) == -5000
    assert row.aging_bucket == "Credit balance"


def test_zero_opening_and_empty_scope(con):
    assert scalar(con, "SELECT count(*) FROM invoices WHERE recognition_date<'2025-01-01'") == 0
    tables = snapshot(con, "2024-01-01")
    assert int(tables["reconciliation"].iloc[0].ending_ar_cents) == 0
    assert tables["exceptions"].empty


def test_generates_same_transactions_twice(database, tmp_path):
    from revenue_audit.generate import generate
    from revenue_audit.db import connect
    other = generate(tmp_path / "again.sqlite")
    left, right = connect(database[0]), connect(other)
    try:
        for table in ("invoices", "journal_lines", "allocations", "shipments"):
            assert list(map(tuple, left.execute(f"SELECT * FROM {table} ORDER BY rowid"))) == list(map(tuple, right.execute(f"SELECT * FROM {table} ORDER BY rowid")))
    finally:
        left.close()
        right.close()
