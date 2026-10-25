"""Generate deterministic synthetic source data and a physically separate answer key."""
import argparse
import os
from pathlib import Path
from .db import DEFAULT_DB, ROOT, connect, sql


def generate(path=DEFAULT_DB):
    """Build atomically; overwrite only the selected project's generated database."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".building.sqlite")
    temporary.unlink(missing_ok=True)
    con = connect(temporary, readonly=False)
    try:
        con.executescript(sql("schema"))
        con.executescript(sql("generate"))
        con.executescript(sql("views"))
        if con.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("Referential integrity failed")
        if con.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ValueError("SQLite integrity failed")
        con.commit()
    finally:
        con.close()
    os.replace(temporary, path)
    return path


def generate_labels(path=None):
    path = Path(path or ROOT / "data/ground_truth/labels.sqlite")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.unlink(missing_ok=True)
    with connect(path, readonly=False) as con:
        con.executescript(sql("ground_truth"))
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    args = parser.parse_args()
    generate(args.db)
    generate_labels()
    with connect(args.db) as con:
        print(f"SYNTHETIC invoices: {con.execute('SELECT count(*) FROM invoices').fetchone()[0]:,}")


if __name__ == "__main__":
    main()
