"""Database access. Every connection enforces SQLite referential integrity."""
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = ROOT / "data" / "revenue_audit.sqlite"


def connect(path=DEFAULT_DB, *, readonly=True):
    path = Path(path).resolve()
    if readonly:
        con = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
    else:
        con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys=ON")
    return con


def sql(name):
    return (ROOT / "sql" / f"{name}.sql").read_text()
