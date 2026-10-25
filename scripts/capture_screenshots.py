"""Optional browser verification/capture: pip install playwright; playwright install chromium."""
import argparse
import csv
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8501")
    parser.add_argument("--chrome", help="Optional existing Chromium/Chrome executable")
    args = parser.parse_args()
    target = ROOT / "screenshots"
    target.mkdir(exist_ok=True)
    temporary = ROOT / ".publishing"
    temporary.mkdir(exist_ok=True)
    errors = []
    pages = [("Overview", "overview.png"), ("Accounting workpapers", "reconciliation.png"),
             ("Exception explorer", "exceptions.png"), ("Controls & risks", "controls.png"),
             ("AR & collections", "aging.png"), ("Methodology", "methodology.png")]
    with sync_playwright() as p:
        options = {"headless": True}
        if args.chrome:
            options["executable_path"] = args.chrome
        browser = p.chromium.launch(**options)
        page = browser.new_page(viewport={"width": 1600, "height": 1100}, device_scale_factor=1)
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(args.url, wait_until="domcontentloaded")
        page.get_by_role("tab", name="Overview", exact=True).wait_for(timeout=60000)
        page.get_by_text("$1,912,899.34", exact=True).first.wait_for(timeout=60000)
        for tab, filename in pages:
            page.get_by_role("tab", name=tab, exact=True).click()
            page.wait_for_timeout(1000)
            assert page.get_by_test_id("stException").count() == 0
            page.screenshot(path=str(target / filename), full_page=True)
        page.get_by_role("tab", name="Exception explorer", exact=True).click()
        with page.expect_download(timeout=30000) as download:
            page.get_by_role("button", name="Download filtered exceptions · CSV", exact=True).click()
        csv_path = temporary / "browser_exceptions.csv"
        download.value.save_as(csv_path)
        with csv_path.open() as file:
            rows = list(csv.DictReader(file))
        assert len(rows) == 222
        page.get_by_role("tab", name="Accounting workpapers", exact=True).click()
        with page.expect_download(timeout=30000) as download:
            page.get_by_role("button", name="Download complete snapshot workpapers · Excel", exact=True).click()
        workbook = temporary / "browser_workpapers.xlsx"
        download.value.save_as(workbook)
        from openpyxl import load_workbook
        book = load_workbook(workbook, read_only=True)
        values = list(book["reconciliation"].values)
        assert dict(zip(values[0], values[1]))["ending_ar_cents"] == 191289934
        book.close()
        browser.close()
    assert not errors, errors
    report = {"classification": "SYNTHETIC", "scope": "All branches, as-of 2025-12-31",
              "tabs_rendered": [name for name, _ in pages], "screenshots": [name for _, name in pages],
              "browser_page_errors": errors, "csv_download_exception_rows": len(rows),
              "excel_download_ar_verified_cents": 191289934, "result": "PASS"}
    (ROOT / "reports/browser_validation.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
