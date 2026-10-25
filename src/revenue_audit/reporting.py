"""Evidence exports. All financial columns are named *_cents; no monetary floats."""
from io import BytesIO
import hashlib
import json
from pathlib import Path
import pandas as pd
from openpyxl.styles import Font, PatternFill
from .analytics import exposure, money, snapshot
from .db import ROOT, DEFAULT_DB, connect


def excel_bytes(tables):
    target = BytesIO()
    with pd.ExcelWriter(target, engine="openpyxl") as writer:
        for name, frame in tables.items():
            frame.to_excel(writer, sheet_name=name[:31], index=False)
            sheet = writer.sheets[name[:31]]
            sheet.freeze_panes = "A2"
            sheet.auto_filter.ref = sheet.dimensions
            for cell in sheet[1]:
                cell.font = Font(color="FFFFFF", bold=True)
                cell.fill = PatternFill("solid", fgColor="142A43")
            for col in sheet.columns:
                title = str(col[0].value)
                sheet.column_dimensions[col[0].column_letter].width = min(55, max(16, len(title)+3))
                if title.endswith("_cents"):
                    for cell in col[1:]:
                        cell.number_format = '#,##0;[Red](#,##0)'
    return target.getvalue()


def build_reports(db=DEFAULT_DB, output=None, as_of="2025-12-31"):
    output = Path(output or ROOT / "reports")
    output.mkdir(parents=True, exist_ok=True)
    with connect(db) as con:
        tables = snapshot(con, as_of)
    for name, frame in tables.items():
        frame.to_csv(output / f"{name}.csv", index=False)
    (output / "audit_workpapers.xlsx").write_bytes(excel_bytes(tables))
    (output / "risk_control_matrix.xlsx").write_bytes(excel_bytes({"Risk and controls": tables["controls"]}))
    totals = exposure(tables["exceptions"])
    rec = {k: int(v) for k, v in tables["reconciliation"].iloc[0].items()}
    summary = {"classification": "SYNTHETIC", "as_of": as_of,
               "invoice_count": int(tables["kpis"].iloc[0].invoice_count),
               "exceptions_by_type": {str(k): int(v) for k, v in tables["exceptions"].groupby("rule_id").size().items()},
               "exposure": totals, "reconciliation": rec, "actual_loss": "Not assessed",
               "database_sha256": hashlib.sha256(Path(db).read_bytes()).hexdigest()}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    rows = "\n".join(f"| {k} | {v} |" for k, v in summary["exceptions_by_type"].items())
    findings = f"""# Executive findings — SYNTHETIC\n\nAs of {as_of}: {summary['invoice_count']:,} invoices. These are analytical exceptions in a fictional dataset, not audit findings or proven fraud.\n\n| Rule | Exceptions |\n|---|---:|\n{rows}\n\nEnding AR subledger: {money(rec['ending_ar_cents'])}; GL AR: {money(rec['gl_ar_cents'])}; difference: {money(rec['difference_cents'])}. The bridge in `bridge.csv` explains this difference in full. The reconciled bridge does not make the original records correct.\n\nConservative estimated potential exposure: {money(totals['estimated_exposure_cents'])}. Unique flagged transaction value: {money(totals['flagged_value_cents'])}. Quantified arithmetic differences: {money(totals['quantified_difference_cents'])}; these are extract discrepancies, not confirmed misstatements. Actual loss: **not assessed**. Never add rule exposure subtotals.\n\nImmediate: restrict manual posting and require independent approval before release (IT access owner / controller). Within 30 days: enforce shipment-linked billing, duplicate blocks, validated cash application and daily GL interface reconciliation (billing / AR managers). Within 60 days: review repeat late payers, concentration and credit limits (credit manager). See controls.csv for individual thresholds, owners and evidence.\n\nNext audit steps: validate extract completeness to independent control totals; inspect contracts, carrier evidence, bank statements and approvals; investigate false positives; propose supported correcting entries; retest remediation. No automatic correction is posted.\n"""
    (output / "executive_findings.md").write_text(findings)
    manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.iterdir())
                if p.is_file() and p.name != "manifest.json"}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return summary
