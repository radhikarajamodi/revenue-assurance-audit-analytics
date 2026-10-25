from contextlib import closing
import pytest
from revenue_audit.db import connect
from revenue_audit.generate import generate, generate_labels


@pytest.fixture(scope="session")
def database(tmp_path_factory):
    root = tmp_path_factory.mktemp("synthetic_audit")
    path = generate(root / "transactions.sqlite")
    labels = generate_labels(root / "labels.sqlite")
    return path, labels


@pytest.fixture
def con(database):
    with closing(connect(database[0], readonly=False)) as connection:
        yield connection
        connection.rollback()
