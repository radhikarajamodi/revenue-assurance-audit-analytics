"""Pre-publication scan, limited to this project. No home-directory or token reads."""
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
SKIP = {".git", ".venv", ".tools", ".publishing", "__pycache__", ".pytest_cache", "build", "dist"}
PATTERNS = [re.compile(r"gh[pousr]_" + r"[A-Za-z0-9]{20,}"),
            re.compile(r"github_pat_" + r"[A-Za-z0-9_]{30,}"),
            re.compile(r"AKIA" + r"[A-Z0-9]{16}"),
            re.compile(r"-----BEGIN " + r"(?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
            re.compile(r"sk-" + r"[A-Za-z0-9]{35,}")]


def scan():
    failures = []
    files = 0
    for path in ROOT.rglob("*"):
        if any(part in SKIP or part.endswith(".egg-info") for part in path.relative_to(ROOT).parts):
            continue
        if not path.is_file():
            continue
        files += 1
        if path.name in {".env", "secrets.toml", "auth.json", "credentials"}:
            failures.append(str(path.relative_to(ROOT)))
        if path.suffix in {".sqlite", ".xlsx", ".png"}:
            continue
        text = path.read_text(errors="ignore")
        if any(pattern.search(text) for pattern in PATTERNS):
            failures.append(str(path.relative_to(ROOT)))
    path = ROOT / "data/revenue_audit.sqlite"
    if path.exists():
        con = sqlite3.connect(path.as_uri()+"?mode=ro", uri=True)
        try:
            classification = con.execute("SELECT value FROM metadata WHERE key='classification'").fetchone()[0]
            if not classification.startswith("SYNTHETIC"):
                failures.append("Database is not classified synthetic")
            for table in ("customers", "employees"):
                if con.execute(f"SELECT count(*) FROM {table} WHERE name NOT LIKE 'Synthetic %'").fetchone()[0]:
                    failures.append(f"Unexpected non-synthetic names in {table}")
        finally:
            con.close()
    if failures:
        raise SystemExit("Publication scan failed: " + ", ".join(failures))
    print(f"Content scan passed for {files} project files; all database person/customer names are synthetic.")
    print("Pattern scanning complements review; it is not a guarantee against every possible secret.")


if __name__ == "__main__":
    scan()
