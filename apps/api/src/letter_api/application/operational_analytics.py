"""Consent-aware, provider-free operational analytics boundary."""

from collections.abc import Mapping

from letter_api.domain.operational_analytics import (
    ConsentState,
    OperationalAnalyticsEvent,
    validate_consent_state,
    validate_operational_event,
)


class OperationalAnalyticsRecorder:
    """Buffer validated events only after explicit consent.

    The recorder has no transport and does not persist data.  The bounded
    buffer is a hand-off point for a future, separately approved provider;
    opting out or deleting analytics clears it immediately.
    """

    def __init__(self, max_buffer_size: int = 100) -> None:
        if max_buffer_size < 1:
            raise ValueError("max buffer size must be positive")
        self._consent: ConsentState = "not_set"
        self._events: list[OperationalAnalyticsEvent] = []
        self._max_buffer_size = max_buffer_size

    @property
    def consent(self) -> ConsentState:
        return self._consent

    def set_consent(self, value: ConsentState) -> None:
        consent = validate_consent_state(value)
        self._consent = consent
        if consent == "opted_out":
            self.delete_all()

    def record(self, event: OperationalAnalyticsEvent) -> bool:
        """Buffer an already typed event only when consent is granted."""

        if self._consent != "granted":
            return False
        if len(self._events) >= self._max_buffer_size:
            self._events.pop(0)
        self._events.append(event)
        return True

    def record_payload(self, payload: Mapping[str, object]) -> bool:
        """Validate an external payload before applying consent behavior."""

        event = validate_operational_event(payload)
        return self.record(event)

    def buffered_events(self) -> tuple[OperationalAnalyticsEvent, ...]:
        return tuple(self._events)

    def delete_all(self) -> None:
        self._events.clear()
