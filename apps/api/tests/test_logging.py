import logging

from fastapi.testclient import TestClient

from letter_api.bootstrap import create_app
from letter_api.core.settings import Settings


def test_access_log_uses_route_template_without_query_values(
    caplog: object,
) -> None:
    capture = caplog
    assert hasattr(capture, "at_level")
    client = TestClient(create_app(Settings(environment="test")))

    with capture.at_level(logging.INFO, logger="letter_api.access"):
        response = client.get("/v1/status?private_value=not-logged")

    assert response.status_code == 200
    records = capture.records
    record = next(item for item in records if item.message == "request_complete")
    assert record.route_template == "/v1/status"
    assert "private_value" not in record.getMessage()
    assert "not-logged" not in record.getMessage()
