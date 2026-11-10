
import pytest
from fastapi.testclient import TestClient

from app.main import INT64_MAX, INT64_MIN, app, reverse_number

client = TestClient(app)


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (12345, 54321),
        (123, 321),
        (-123, -321),
        (1200, 21),
        (100, 1),
        (0, 0),
        (7, 7),
    ],
)
def test_reverse_number(value, expected):
    assert reverse_number(value) == expected


def test_api_reverses_number():
    response = client.post("/reverse", json={"number": 12345})

    assert response.status_code == 200
    assert response.json() == {
        "input": 12345,
        "reversed": 54321
    }


def test_rejects_string_input():
    response = client.post("/reverse", json={"number": "abc"})

    assert response.status_code == 422


def test_rejects_decimal_input():
    response = client.post("/reverse", json={"number": 12.5})

    assert response.status_code == 422


@pytest.mark.parametrize(
    "value",
    [INT64_MAX + 1, INT64_MIN - 1]
)
def test_rejects_out_of_range_input(value):
    response = client.post("/reverse", json={"number": value})

    assert response.status_code == 422


def test_rejects_reversed_overflow():
    response = client.post(
        "/reverse",
        json={"number": 8999999999999999999}
    )

    assert response.status_code == 422


def test_health():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ui():
    response = client.get("/")

    assert response.status_code == 200
    assert "Number Reverser" in response.text
