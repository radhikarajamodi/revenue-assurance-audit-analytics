#!/bin/sh
# Dependency-free data generation on macOS. Normal pipeline: python -m revenue_audit build.
set -eu
cd "$(dirname "$0")/.."
mkdir -p data/ground_truth
rm -f data/revenue_audit.building.sqlite data/ground_truth/labels.building.sqlite
sqlite3 -bail data/revenue_audit.building.sqlite < sql/schema.sql
sqlite3 -bail data/revenue_audit.building.sqlite < sql/generate.sql
sqlite3 -bail data/revenue_audit.building.sqlite < sql/views.sql
sqlite3 -bail data/ground_truth/labels.building.sqlite < sql/ground_truth.sql
mv data/revenue_audit.building.sqlite data/revenue_audit.sqlite
mv data/ground_truth/labels.building.sqlite data/ground_truth/labels.sqlite
