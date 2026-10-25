"""Run: streamlit run app.py. All displayed financial results come from SQLite."""
from datetime import date
import pandas as pd
import plotly.express as px
import streamlit as st
from revenue_audit.analytics import exposure, money, snapshot
from revenue_audit.db import DEFAULT_DB, ROOT, connect
from revenue_audit.reporting import excel_bytes

st.set_page_config(page_title="Revenue Assurance | Audit Analytics", page_icon="◈", layout="wide")
st.markdown("""<style>
.block-container {padding-top:4rem; max-width:1500px}
[data-testid="stMetric"] {background:white; border:1px solid #e1e7ee; border-radius:12px; padding:16px}
h1 {letter-spacing:-1px} .eyebrow {color:#0d9488;letter-spacing:3px;font-size:12px;font-weight:700}
</style>""", unsafe_allow_html=True)
st.markdown('<div class="eyebrow">NORTHSTAR PARTS • FICTIONAL DISTRIBUTOR</div>', unsafe_allow_html=True)
st.title("Revenue Assurance & Audit Analytics")
st.caption("SYNTHETIC DATA · Fiscal 2025 · Transaction evidence, accounting reconciliation and control testing")
if not DEFAULT_DB.exists():
    st.info("Generate the synthetic database first: python -m revenue_audit build")
    st.stop()

with st.sidebar:
    st.header("Audit scope")
    as_of = st.date_input("As-of date", date(2025, 12, 31), min_value=date(2025, 1, 1), max_value=date(2026, 3, 31))
    branch_name = st.selectbox("Branch", ["All branches", "North Bay", "Central Valley", "Coastal", "South Bay"])
    branch = ["All branches", "North Bay", "Central Valley", "Coastal", "South Bay"].index(branch_name)
    st.caption("Stocks use the as-of date; revenue is year to date. Exceptions use retrospective evidence from the full extract.")
    start = st.date_input("Exception period begins", date(2025, 1, 1), max_value=as_of)
    st.divider()
    st.caption("Amounts in tables and downloads are USD integer cents. Potential exposure is an investigation estimate. Actual loss is not assessed.")


@st.cache_data(show_spinner=False)
def load(as_of, branch, modified):
    con = connect()
    try:
        tables = snapshot(con, as_of, branch)
        params = {"as_of": as_of, "branch": branch}
        tables["monthly_sales"] = pd.read_sql_query(
            "SELECT substr(recognition_date,1,7) period,sum(amount_cents) sales_cents "
            "FROM invoices i JOIN orders o USING(order_id) WHERE recognition_date<=:as_of "
            "AND (:branch=0 OR o.branch_id=:branch) GROUP BY period ORDER BY period", con, params=params)
        return tables
    finally:
        con.close()

with st.spinner("Reconciling transaction evidence…"):
    tables = load(as_of.isoformat(), branch, DEFAULT_DB.stat().st_mtime_ns)
rec = tables["reconciliation"].iloc[0]
rev = tables["revenue_reconciliation"].iloc[0]
all_exc = tables["exceptions"]
with st.sidebar:
    types = st.multiselect("Exception type", sorted(all_exc.rule_id.unique()), placeholder="All exception types")
    severities = st.multiselect("Severity", ["High", "Medium"], placeholder="All severities")
filtered = all_exc[all_exc.event_date >= start.isoformat()].copy()
if types:
    filtered = filtered[filtered.rule_id.isin(types)]
if severities:
    filtered = filtered[filtered.severity.isin(severities)]
exp = exposure(filtered)

overview, workpapers, explorer, controls, aging, method = st.tabs([
    "Overview", "Accounting workpapers", "Exception explorer", "Controls & risks", "AR & collections", "Methodology"])
with overview:
    st.subheader("Reconcile first. Investigate with evidence.")
    st.caption(f"{branch_name} · as of {as_of} · accounting KPIs follow branch/date; type and severity filters apply to exceptions.")
    a, b, c, d = st.columns(4)
    a.metric("GL net revenue · YTD", money(rev.gl_net_revenue_cents))
    b.metric("AR subledger", money(rec.ending_ar_cents))
    c.metric("GL AR", money(rec.gl_ar_cents))
    d.metric("GL less subledger", money(rec.difference_cents))
    a, b, c = st.columns(3)
    a.metric("Filtered exceptions", len(filtered))
    b.metric("Unique flagged items", exp["unique_items"])
    c.metric("Estimated potential exposure", money(exp["estimated_exposure_cents"]))
    st.caption("Exposure uses the maximum estimate per invoice, journal or receipt across selected tests. It is a conservative envelope, not additive rule totals or expected loss.")
    left, right = st.columns([3, 2])
    with left:
        st.plotly_chart(px.bar(tables["monthly_sales"], x="period", y="sales_cents", title="Recognized invoice value by month", color_discrete_sequence=["#0D9488"], labels={"sales_cents":"USD cents", "period":"Recognition month"}), use_container_width=True)
    with right:
        counts = filtered.groupby("rule_id").size().reset_index(name="exceptions")
        st.plotly_chart(px.bar(counts, x="exceptions", y="rule_id", orientation="h", title="Exceptions requiring investigation", color_discrete_sequence=["#C66B3D"]), use_container_width=True)
    if int(rec.difference_cents):
        st.warning("AR does not tie directly. The accounting workpaper attributes the full difference; investigation and supported corrections remain necessary.")
    else:
        st.success("AR ties at this scope. A tie does not establish that individual transactions are correct.")

with workpapers:
    st.subheader("AR rollforward and GL reconciliation")
    st.caption("Beginning AR is the prior month-end balance; activity runs from the start of the selected month through the as-of date. Initial 2025 AR is zero.")
    roll = pd.DataFrame({"Component": ["Beginning AR", "+ Credit sales", "− Applied collections", "− Credits", "= Ending subledger AR", "GL AR", "GL less subledger"],
        "USD": [money(rec[k]) for k in ["beginning_ar_cents", "credit_sales_cents", "collections_cents", "credits_cents", "ending_ar_cents", "gl_ar_cents", "difference_cents"]]})
    st.dataframe(roll, hide_index=True, use_container_width=True)
    st.write("Independent bridge of GL less subledger (cents)")
    st.dataframe(tables["bridge"], hide_index=True, use_container_width=True)
    st.success("Bridge total agrees to the AR difference; aging agrees to the subledger. Both are enforced in code.")
    st.subheader("Revenue reconciliation · year to date")
    st.dataframe(tables["revenue_reconciliation"], hide_index=True, use_container_width=True)
    st.caption("Revenue differences arise from invoice posting/amount discrepancies and manual revenue journals. Credits reduce net revenue through account 4090.")
    st.download_button("Download complete snapshot workpapers · Excel", excel_bytes(tables), file_name=f"synthetic_workpapers_{as_of}_branch{branch}.xlsx", mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

with explorer:
    st.subheader("Transaction exception workpaper")
    a, b, c = st.columns(3)
    a.metric("Unique flagged transaction value", money(exp["flagged_value_cents"]))
    b.metric("Quantified arithmetic differences", money(exp["quantified_difference_cents"]))
    c.metric("Actual loss", "Not assessed")
    st.caption("Quantified differences are demonstrable extract discrepancies, not confirmed accounting misstatements. All items remain open pending investigation.")
    columns = ["exception_id", "rule_id", "severity", "risk_key", "invoice_id", "journal_id", "event_date", "invoice_date", "recognition_date", "last_ship_date", "gl_posting_date", "flagged_value_cents", "exposure_cents", "discrepancy_cents", "evidence", "assertion", "recommended_investigation"]
    st.dataframe(filtered[columns], hide_index=True, use_container_width=True)
    st.download_button("Download filtered exceptions · CSV", filtered.to_csv(index=False).encode(), "filtered_exceptions.csv", "text/csv")
    st.download_button("Download filtered exceptions · Excel", excel_bytes({"exceptions": filtered, "scope": tables["scope"]}), "filtered_exceptions.xlsx")
    chosen = st.selectbox("Inspect invoice evidence", [None]+sorted({int(x) for x in filtered.invoice_id.dropna()}), format_func=lambda x: "Select an invoice" if x is None else str(x))
    if chosen is not None:
        con = connect()
        try:
            for title, statement in [
                ("Invoice / order / shipment / GL", "SELECT * FROM v_invoice_evidence WHERE invoice_id=?"),
                ("Invoice lines", "SELECT * FROM invoice_lines WHERE invoice_id=?"),
                ("Cash applications", "SELECT a.*,p.payment_date,p.customer_id AS remitter_customer,p.amount_cents AS receipt_cents FROM allocations a JOIN payments p USING(payment_id) WHERE a.invoice_id=?"),
                ("Credits", "SELECT * FROM credit_memos WHERE invoice_id=?")]:
                st.write(title)
                st.dataframe(pd.read_sql_query(statement, con, params=(chosen,)), hide_index=True, use_container_width=True)
        finally:
            con.close()

with controls:
    st.subheader("Risk, controls and testing results")
    st.caption("Full extract populations are disclosed; exception counts follow branch/as-of scope. No failure rates or control-effectiveness opinion are inferred. The last two tests are customer risk indicators.")
    st.dataframe(tables["controls"][["rule_id", "assertion", "severity", "exception_count", "full_extract_population", "result", "owner", "recommended_control"]], hide_index=True, use_container_width=True)
    st.write("Supporting data validation · full extract")
    st.dataframe(tables["data_quality"], hide_index=True, use_container_width=True)
    st.caption("Support checks are evidence diagnostics and are excluded from monetary exposure totals; an excess credit can appear in both support checks and exceptions.")
    st.download_button("Download risk and control matrix", excel_bytes({"Controls": tables["controls"]}), "risk_control_matrix.xlsx")

with aging:
    st.subheader("Receivables aging and collection risk")
    balances = tables["aging"]
    bucket = balances.groupby("aging_bucket", as_index=False).balance_cents.sum()
    st.plotly_chart(px.bar(bucket, x="aging_bucket", y="balance_cents", title="Net open AR by due-date aging", labels={"balance_cents":"USD cents"}, color_discrete_sequence=["#0D9488"], category_orders={"aging_bucket":["Credit balance","Current","1–30","31–60","61–90","90+"]}), use_container_width=True)
    st.caption("Partial applications reduce balances by their actual amounts. Credits use credit dates; credit balances are retained separately rather than netted into past-due buckets.")
    risk = tables["customer_risk"].copy()
    total = int(risk.sales_cents.sum())
    risk["sales_share"] = risk.sales_cents.map(lambda n: f"{int(n)*10000//total/100:.2f}%" if total else "0.00%")
    risk["concentration_review"] = (risk.sales_cents*100 >= total*10) & (risk.sales_cents>0)
    risk["repeat_late_review"] = risk.late_settled_invoices>=3
    st.dataframe(risk, hide_index=True, use_container_width=True)
    st.dataframe(balances[balances.balance_cents != 0], hide_index=True, use_container_width=True)
    st.download_button("Download AR aging", balances.to_csv(index=False).encode(), "ar_aging.csv", "text/csv")

with method:
    st.subheader("Judgment, limitations and next steps")
    st.markdown("""**Accounting basis.** Credit sales debit AR and credit revenue. Receipts debit cash and credit AR; unallocated advances credit customer deposits. Approved returns debit sales returns and credit AR. Shipment is assumed to evidence control transfer under the fictional shipping-point contracts. Actual ASC 606 conclusions depend on the contract and full facts.

**Priorities.** Review authorization failures and unsupported recognition first, then quantify matching and cash errors. Severity reflects the assertion and control failure; amounts help order investigation. No probability or fraud score is assigned.

**Recommendations.** Require shipment-linked billing and duplicate checks; restrict manual journal access; require independent approval before posting; validate payer, date and remaining receipt balance; reconcile interfaces daily. Assign control owners and retest after remediation.

**Limitations.** This is a deterministic educational extract. It omits inventory/COGS, taxes, FX, allowance estimation and complex contract terms. Permissions are a static extract. Exception evidence is retrospective, not a reconstruction of information available at each historical date. A clean test is not an audit opinion. No real losses or fraud conclusions are claimed.

**Next audit steps.** Validate extract completeness to independent ledgers; inspect contracts and carrier evidence; confirm selected customer balances; inspect bank receipts and approvals; investigate false positives; propose supported correcting entries and retest controls.
""")
    st.markdown((ROOT / "docs/process_flow.md").read_text())
