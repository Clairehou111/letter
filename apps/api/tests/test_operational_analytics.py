import pytest

from letter_api.application.operational_analytics import OperationalAnalyticsRecorder
from letter_api.domain.operational_analytics import (
    AnalyticsValidationError,
    AppStartupEvent,
    PurchaseFlowOutcomeEvent,
    RouteLoadFailureEvent,
    validate_operational_event,
)


def startup_payload() -> dict[str, object]:
    return {
        "event_name": "app_startup",
        "schema_version": 1,
        "app_version": "1.4.0",
        "platform": "ios",
        "startup_result": "completed",
    }


def test_validator_returns_each_allowlisted_typed_event() -> None:
    startup = validate_operational_event(startup_payload())
    route = validate_operational_event(
        {
            "event_name": "route_load_failed",
            "schema_version": 1,
            "app_version": "1.4.0",
            "platform": "web",
            "route_id": "archive",
            "failure_code": "timeout",
        }
    )
    purchase = validate_operational_event(
        {
            "event_name": "purchase_flow_outcome",
            "schema_version": 1,
            "app_version": "1.4.0",
            "platform": "android",
            "purchase_offer": "annual",
            "purchase_outcome": "completed",
        }
    )

    assert isinstance(startup, AppStartupEvent)
    assert isinstance(route, RouteLoadFailureEvent)
    assert isinstance(purchase, PurchaseFlowOutcomeEvent)
    assert startup.to_record() == startup_payload()


@pytest.mark.parametrize(
    "forbidden_key",
    [
        "cycle_start_date",
        "symptom_code",
        "care_mode",
        "care_outcome",
        "text",
        "transcript",
        "draft",
        "report",
        "prediction",
        "inferred_health_state",
        "properties",
    ],
)
def test_validator_rejects_health_and_free_form_properties(
    forbidden_key: str,
) -> None:
    payload = startup_payload()
    payload[forbidden_key] = "synthetic-value"

    with pytest.raises(AnalyticsValidationError):
        validate_operational_event(payload)


def test_validator_rejects_unallowlisted_event_name_and_values() -> None:
    unknown_event = startup_payload()
    unknown_event["event_name"] = "symptom_logged"
    with pytest.raises(AnalyticsValidationError):
        validate_operational_event(unknown_event)

    invalid_value = startup_payload()
    invalid_value["startup_result"] = "severe"
    with pytest.raises(AnalyticsValidationError):
        validate_operational_event(invalid_value)


def test_recorder_requires_consent_and_never_sends() -> None:
    recorder = OperationalAnalyticsRecorder()

    assert recorder.record_payload(startup_payload()) is False
    assert recorder.buffered_events() == ()

    recorder.set_consent("granted")
    assert recorder.record_payload(startup_payload()) is True
    assert len(recorder.buffered_events()) == 1


def test_opt_out_clears_buffer_and_blocks_future_events() -> None:
    recorder = OperationalAnalyticsRecorder()
    recorder.set_consent("granted")
    recorder.record_payload(startup_payload())

    recorder.set_consent("opted_out")

    assert recorder.buffered_events() == ()
    assert recorder.record_payload(startup_payload()) is False
    assert recorder.buffered_events() == ()


def test_deletion_clears_buffer_without_changing_consent() -> None:
    recorder = OperationalAnalyticsRecorder()
    recorder.set_consent("granted")
    recorder.record_payload(startup_payload())

    recorder.delete_all()

    assert recorder.consent == "granted"
    assert recorder.buffered_events() == ()


def test_buffer_is_bounded_and_oldest_event_is_discarded() -> None:
    recorder = OperationalAnalyticsRecorder(max_buffer_size=1)
    recorder.set_consent("granted")
    recorder.record_payload(startup_payload())
    recorder.record_payload({**startup_payload(), "startup_result": "failed"})

    assert len(recorder.buffered_events()) == 1
    assert recorder.buffered_events()[0].to_record()["startup_result"] == "failed"
