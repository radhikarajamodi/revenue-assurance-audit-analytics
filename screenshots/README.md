# Actual application screenshots

Captured from the running Streamlit app in headless Chrome at 1600 × 1100, all branches, as of December 31, 2025. All company data is synthetic. These are browser screenshots, not mockups.

- `overview.png`: accounting KPIs, exception counts and potential exposure.
- `reconciliation.png`: monthly AR rollforward and independently explained GL difference.
- `exceptions.png`: transaction-level evidence and investigation guidance.
- `controls.png`: risk/control tests and proposed remediation owners.
- `aging.png`: receivables aging and customer collection-risk metrics.
- `methodology.png`: accounting assumptions, limitations and audit follow-up.

To recapture, start `streamlit run app.py`, install the optional `playwright` package and its Chromium browser, then run `python scripts/capture_screenshots.py`. An existing browser can be supplied with `--chrome /path/to/chrome`. Browser verification also checks the exception CSV and accounting Excel downloads. See `reports/browser_validation.json`.
