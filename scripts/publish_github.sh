#!/bin/sh
# Validate and update this existing checkout. No force pushes or repository creation.
set -eu
cd "$(dirname "$0")/.."
test -f pyproject.toml
test -f sql/schema.sql
project_root=$(pwd -P)
git_root=$(git rev-parse --show-toplevel)
if test "$project_root" != "$git_root"; then
  echo 'Run from a clone of this project, not a parent repository.' >&2
  exit 1
fi
project_origin=$(git remote get-url origin)
case "$project_origin" in
  https://github.com/radhikarajamodi/revenue-assurance-audit-analytics.git|https://github.com/radhikarajamodi/revenue-assurance-audit-analytics|git@github.com:radhikarajamodi/revenue-assurance-audit-analytics.git) ;;
  *) echo 'Origin does not match the authorized project repository.' >&2; exit 1 ;;
esac
python -m revenue_audit build
python -m revenue_audit.evaluate
python -m pytest -q
python scripts/scan_content.py
git add .
if git diff --cached --quiet; then
  echo 'No changes to publish.'
  exit 0
fi
git commit -m 'Update revenue assurance analytics and verified workpapers'
git push origin HEAD:main
