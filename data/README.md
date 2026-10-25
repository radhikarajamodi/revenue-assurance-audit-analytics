# Synthetic data only

`revenue_audit.sqlite` contains generated fictional source-system records and SQL detector views. There are no real customer, employee, payment or company records. Money is USD integer cents. See `metadata` for classification, seed and generator version.

`ground_truth/labels.sqlite` is a separate answer-key database for evaluation only. The application and detector never attach it. `sql/ground_truth.sql` documents the deliberate injections; do not treat labels as evidence supporting an audit conclusion.

Regenerate: `python -m revenue_audit build`. This atomically replaces the selected generated transaction database. The fixed seed is 606; generation version is 1. SQL arithmetic produces the deterministic distribution without requiring a database random-number generator. The present implementation supports one fixed scenario/seed, not arbitrary fiscal years or seeds.

The checked-in database supports immediate inspection with SQLite. Tests build isolated databases in pytest temporary directories and roll back mutations. Python regeneration must be run from this editable project checkout. Database binary hashes may differ by SQLite build even when logical table contents are identical.
