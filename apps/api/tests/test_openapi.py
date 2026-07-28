from letter_api.bootstrap import create_app
from letter_api.core.settings import Settings


def test_openapi_contains_only_operational_contracts() -> None:
    schema = create_app(Settings(environment="test")).openapi()

    assert set(schema["paths"]) == {"/health", "/v1/status"}
    serialized = str(schema).lower()
    for prohibited_term in ("cycle", "symptom", "period_date", "health_record"):
        assert prohibited_term not in serialized
