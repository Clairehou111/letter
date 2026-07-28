from fastapi.testclient import TestClient

from letter_api.bootstrap import create_app
from letter_api.core.settings import Settings


def test_health_and_status_are_operational_only() -> None:
    client = TestClient(create_app(Settings(environment="test")))

    assert client.get("/health").json() == {"status": "ok"}
    assert client.get("/v1/status").json() == {
        "status": "ok",
        "service": "letter-api",
        "api_version": "0.1.0",
    }


def test_unknown_route_returns_not_found() -> None:
    client = TestClient(create_app(Settings(environment="test")))

    assert client.get("/v1/cycles").status_code == 404
