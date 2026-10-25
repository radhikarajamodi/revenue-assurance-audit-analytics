from streamlit.testing.v1 import AppTest
from revenue_audit.db import ROOT, DEFAULT_DB


def test_dashboard_default_and_branch_smoke():
    assert DEFAULT_DB.exists(), "Run python -m revenue_audit build before app tests"
    app = AppTest.from_file(str(ROOT / "app.py"), default_timeout=60).run()
    assert not app.exception
    assert len(app.metric) >= 7
    app.sidebar.selectbox[0].select("North Bay").run()
    assert not app.exception
    app.sidebar.multiselect[0].select("AMOUNT_MISMATCH").run()
    assert not app.exception
