"""SQL-first audit procedures; financial computation remains in integer cents."""
from datetime import date
from decimal import Decimal
import pandas as pd
from .db import ROOT, sql


def money(cents):
    return f"${Decimal(int(cents)) / Decimal(100):,.2f}"


def matrix():
    return pd.read_csv(ROOT / "docs/risk_control_matrix.csv", keep_default_na=False)


def query(con, name, as_of, branch=0):
    date.fromisoformat(as_of)
    if branch not in range(5):
        raise ValueError("Branch must be 0 (all) or 1–4")
    return pd.read_sql_query(sql(name), con, params={"as_of": as_of, "branch": branch})


def exceptions(con, as_of="2025-12-31", branch=0):
    date.fromisoformat(as_of)
    frame = pd.read_sql_query(
        "SELECT * FROM v_exceptions WHERE event_date<=:as_of "
        "AND (:branch=0 OR branch_id=:branch) ORDER BY rule_id,risk_key",
        con, params={"as_of": as_of, "branch": branch},
    )
    for column in ("invoice_id", "journal_id", "customer_id", "order_id"):
        frame[column] = frame[column].astype("Int64")
    return frame.merge(matrix(), on="rule_id", how="left", validate="many_to_one")


def exposure(frame):
    """Conservative envelope: maximum per invoice, journal or receipt across rules."""
    if frame.empty:
        return {"flagged_value_cents": 0, "estimated_exposure_cents": 0,
                "quantified_difference_cents": 0, "unique_items": 0}
    items = frame.groupby("risk_key", sort=False)[
        ["flagged_value_cents", "exposure_cents", "discrepancy_cents"]].max()
    return {"flagged_value_cents": int(items.flagged_value_cents.sum()),
            "estimated_exposure_cents": int(items.exposure_cents.sum()),
            "quantified_difference_cents": int(items.discrepancy_cents.sum()),
            "unique_items": len(items)}


def controls(con, frame, customers):
    """Exception counts and tested populations, not effectiveness opinions."""
    result = matrix().copy()
    invoice_population = con.execute("SELECT count(*) FROM invoices").fetchone()[0]
    manual_population = con.execute("SELECT count(*) FROM journal_entries WHERE manual=1").fetchone()[0]
    allocation_population = con.execute("SELECT count(*) FROM allocations").fetchone()[0]
    credit_population = con.execute("SELECT count(DISTINCT invoice_id) FROM credit_memos").fetchone()[0]
    counts = frame.groupby("rule_id").size().to_dict()
    populations = {}
    for rule in result.rule_id:
        populations[rule] = (manual_population if rule in ("APPROVAL_FAILURE", "MANUAL_UNAUTHORIZED")
                             else allocation_population if rule.startswith("CASH_")
                             else credit_population if rule == "CREDIT_EXCESS"
                             else len(customers) if rule in ("LATE_PAYMENTS", "CONCENTRATION")
                             else invoice_population)
    counts["LATE_PAYMENTS"] = int((customers.late_settled_invoices >= 3).sum())
    total = int(customers.sales_cents.sum())
    counts["CONCENTRATION"] = int(((customers.sales_cents * 100 >= total * 10) & (customers.sales_cents > 0)).sum()) if total else 0
    result["exception_count"] = result.rule_id.map(counts).fillna(0).astype("int64")
    result["full_extract_population"] = result.rule_id.map(populations)
    result["result"] = result.exception_count.map(lambda x: "Investigate exceptions" if x else "No exception detected")
    result["scope_note"] = "Exception counts follow snapshot; population is full extract. No failure-rate inference."
    return result


def snapshot(con, as_of="2025-12-31", branch=0):
    tables = {name: query(con, name, as_of, branch) for name in
              ("reconciliation", "bridge", "aging", "customer_risk", "kpis", "revenue_reconciliation", "data_quality")}
    tables["exceptions"] = exceptions(con, as_of, branch)
    tables["controls"] = controls(con, tables["exceptions"], tables["customer_risk"])
    tables["scope"] = pd.DataFrame([{"as_of": as_of, "branch": branch,
        "classification": "SYNTHETIC", "exception_basis": "Retrospective full-extract evidence",
        "currency": "USD integer cents", "actual_loss": "Not assessed"}])
    rec = tables["reconciliation"].iloc[0]
    if int(tables["bridge"].bridge_cents.sum()) != int(rec.difference_cents):
        raise ValueError("Unexplained AR reconciliation bridge")
    if int(tables["aging"].balance_cents.sum()) != int(rec.ending_ar_cents):
        raise ValueError("Aging does not reconcile to subledger")
    return tables
