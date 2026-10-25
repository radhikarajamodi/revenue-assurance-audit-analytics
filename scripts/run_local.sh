#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e .
python -m revenue_audit build
python -m pytest -q
streamlit run app.py
