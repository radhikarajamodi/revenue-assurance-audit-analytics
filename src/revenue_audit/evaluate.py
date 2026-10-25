"""Fixture evaluation only. This module is never imported by the detector or app."""
from contextlib import closing
import json
import pandas as pd
from .db import ROOT, DEFAULT_DB, connect


def evaluate(db=DEFAULT_DB, labels=None):
    labels = labels or ROOT / "data/ground_truth/labels.sqlite"
    with closing(connect(db)) as con:
        detected = {tuple(row) for row in con.execute("SELECT rule_id,risk_key FROM v_exceptions")}
    with closing(connect(labels)) as con:
        expected = {tuple(row) for row in con.execute("SELECT rule_id,risk_key FROM labels")}
    rows = []
    for rule in sorted({x[0] for x in detected | expected}):
        actual = {x for x in detected if x[0] == rule}
        planted = {x for x in expected if x[0] == rule}
        rows.append({"rule_id": rule, "planted": len(planted), "detected": len(actual),
                     "true_positive": len(actual & planted), "false_positive": len(actual-planted),
                     "false_negative": len(planted-actual)})
    frame = pd.DataFrame(rows)
    frame.to_csv(ROOT / "reports/detection_evaluation.csv", index=False)
    return {"fixture_only": True, "planted_items": len(expected),
            "detected_items": len(detected), "false_positives": len(detected-expected),
            "false_negatives": len(expected-detected)}


if __name__ == "__main__":
    print(json.dumps(evaluate(), indent=2))
