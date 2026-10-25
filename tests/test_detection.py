from contextlib import closing
import sqlite3
from revenue_audit.analytics import exceptions, exposure, query


def test_seeded_detection_exact_set(con, database):
    # Ground truth is opened separately for evaluation, never attached to detector inputs.
    with closing(sqlite3.connect(database[1])) as labels:
        expected = set(labels.execute("SELECT rule_id,risk_key FROM labels"))
    actual = {tuple(r) for r in con.execute("SELECT rule_id,risk_key FROM v_exceptions")}
    actual = set(map(tuple, actual))
    assert expected-actual == set(), f"Missed seeds: {expected-actual}"
    assert actual-expected == set(), f"Unexpected flags: {actual-expected}"


def test_detector_has_no_truth_access(con):
    assert [r[1] for r in con.execute("PRAGMA database_list")] == ["main"]
    assert con.execute("SELECT name FROM sqlite_master WHERE name LIKE '%label%' OR name LIKE '%truth%'").fetchall() == []


def test_clean_split_shipment_not_flagged(con):
    assert con.execute("SELECT * FROM v_exceptions WHERE invoice_id=101").fetchall() == []
    assert con.execute("SELECT count(*) FROM shipments WHERE order_id=101").fetchone()[0] == 2
    assert con.execute("SELECT * FROM v_line_issues WHERE invoice_id=101").fetchall() == []


def test_cutoff_and_independent_approval(con):
    assert con.execute("SELECT count(*) FROM v_exceptions WHERE invoice_id=30 AND rule_id='EARLY_REVENUE'").fetchone()[0] == 1
    assert con.execute("SELECT count(*) FROM v_exceptions WHERE invoice_id=31 AND rule_id='WRONG_PERIOD'").fetchone()[0] == 1
    assert con.execute("SELECT valid_approval FROM v_manual_evidence WHERE journal_id=300003").fetchone()[0] == 0
    assert con.execute("SELECT valid_approval FROM v_manual_evidence WHERE journal_id=300004").fetchone()[0] == 1


def test_exposure_overlap_is_not_added(con):
    frame = exceptions(con)
    overlapping = frame[frame.risk_key == "JE:300001"]
    assert len(overlapping) == 2
    assert exposure(overlapping)["estimated_exposure_cents"] == 800000
    assert exposure(frame)["estimated_exposure_cents"] < int(frame.exposure_cents.sum())


def test_role_conflict_requires_observed_activity(con):
    assert con.execute("SELECT count(*) FROM v_permission_conflicts").fetchone()[0] == 1
    assert con.execute("SELECT count(*) FROM v_exceptions WHERE rule_id='SOD' AND invoice_id=1540").fetchone()[0] == 0


def test_amount_mutation_is_detected_without_label(con):
    con.execute("UPDATE invoices SET amount_cents=amount_cents+1 WHERE invoice_id=101")
    assert con.execute("SELECT count(*) FROM v_exceptions WHERE invoice_id=101 AND rule_id='AMOUNT_MISMATCH'").fetchone()[0] == 1


def test_asof_excludes_future_cash_and_credits(con):
    frame = query(con, "aging", "2025-01-01")
    assert int(frame.amount_cents.sum()) == 0
    assert int(frame.balance_cents.sum()) == -24870  # Invalid premature application retained as credit balance
    assert set(frame.invoice_id) == {105}
    risk = query(con, "customer_risk", "2025-01-01")
    assert int(risk.late_settled_invoices.sum()) == 0


def test_no_negative_or_over_receipt_clean_applications(con):
    defects = con.execute("SELECT payment_id FROM payments p WHERE coalesce((SELECT sum(amount_cents) FROM allocations a WHERE a.payment_id=p.payment_id),0)>p.amount_cents").fetchall()
    assert [r[0] for r in defects] == [106]
    assert con.execute("SELECT count(*) FROM v_credit_support_issues").fetchone()[0] == 1
