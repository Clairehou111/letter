"""Typed, allowlisted operational analytics events.

This module deliberately uses only the standard library.  The closed event
shapes make it impossible for callers to attach arbitrary properties or health
values to an operational analytics event.
"""

import re
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Final, Literal


class AnalyticsValidationError(ValueError):
    """Raised when an event is outside the operational analytics contract."""


type Platform = Literal["android", "ios", "web"]
type StartupResult = Literal["completed", "failed"]
type RouteId = Literal["archive", "cycle", "home", "settings"]
type RouteFailureCode = Literal[
    "network_unavailable",
    "unexpected_response",
    "timeout",
]
type PurchaseOffer = Literal["annual", "introductory", "monthly", "six_month"]
type PurchaseOutcome = Literal["cancelled", "completed", "failed"]
type ConsentState = Literal["not_set", "granted", "opted_out"]

SCHEMA_VERSION: Final = 1
_APP_VERSION_PATTERN: Final = re.compile(
    r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?$"
)
_PLATFORMS: Final = frozenset({"android", "ios", "web"})
_STARTUP_RESULTS: Final = frozenset({"completed", "failed"})
_ROUTE_IDS: Final = frozenset({"archive", "cycle", "home", "settings"})
_ROUTE_FAILURE_CODES: Final = frozenset(
    {"network_unavailable", "unexpected_response", "timeout"}
)
_PURCHASE_OFFERS: Final = frozenset({"annual", "introductory", "monthly", "six_month"})
_PURCHASE_OUTCOMES: Final = frozenset({"cancelled", "completed", "failed"})
_CONSENT_STATES: Final = frozenset({"not_set", "granted", "opted_out"})


def _validate_schema_version(value: object) -> None:
    if type(value) is not int or value != SCHEMA_VERSION:
        raise AnalyticsValidationError("unsupported analytics schema version")


def _validate_app_version(value: object) -> str:
    if not isinstance(value, str) or _APP_VERSION_PATTERN.fullmatch(value) is None:
        raise AnalyticsValidationError("invalid operational app version")
    return value


def _validate_choice(
    value: object,
    allowed: frozenset[str],
    description: str,
) -> str:
    if not isinstance(value, str) or value not in allowed:
        raise AnalyticsValidationError(f"invalid operational {description}")
    return value


def _require_exact_keys(
    payload: Mapping[str, object],
    expected: frozenset[str],
) -> None:
    actual = frozenset(payload)
    if actual != expected:
        raise AnalyticsValidationError("analytics properties are not allowlisted")


@dataclass(frozen=True, slots=True)
class AppStartupEvent:
    """A synthetic app-startup result used for reliability measurement."""

    app_version: str
    platform: Platform
    startup_result: StartupResult
    schema_version: Literal[1] = SCHEMA_VERSION
    event_name: Literal["app_startup"] = "app_startup"

    def __post_init__(self) -> None:
        _validate_schema_version(self.schema_version)
        _validate_app_version(self.app_version)
        _validate_choice(self.platform, _PLATFORMS, "platform")
        _validate_choice(self.startup_result, _STARTUP_RESULTS, "startup result")

    def to_record(self) -> dict[str, str | int]:
        return {
            "event_name": self.event_name,
            "schema_version": self.schema_version,
            "app_version": self.app_version,
            "platform": self.platform,
            "startup_result": self.startup_result,
        }


@dataclass(frozen=True, slots=True)
class RouteLoadFailureEvent:
    """A route loading failure without route contents or user state."""

    app_version: str
    platform: Platform
    route_id: RouteId
    failure_code: RouteFailureCode
    schema_version: Literal[1] = SCHEMA_VERSION
    event_name: Literal["route_load_failed"] = "route_load_failed"

    def __post_init__(self) -> None:
        _validate_schema_version(self.schema_version)
        _validate_app_version(self.app_version)
        _validate_choice(self.platform, _PLATFORMS, "platform")
        _validate_choice(self.route_id, _ROUTE_IDS, "route")
        _validate_choice(self.failure_code, _ROUTE_FAILURE_CODES, "route failure")

    def to_record(self) -> dict[str, str | int]:
        return {
            "event_name": self.event_name,
            "schema_version": self.schema_version,
            "app_version": self.app_version,
            "platform": self.platform,
            "route_id": self.route_id,
            "failure_code": self.failure_code,
        }


@dataclass(frozen=True, slots=True)
class PurchaseFlowOutcomeEvent:
    """A subscription purchase-flow outcome without account or health data."""

    app_version: str
    platform: Platform
    purchase_offer: PurchaseOffer
    purchase_outcome: PurchaseOutcome
    schema_version: Literal[1] = SCHEMA_VERSION
    event_name: Literal["purchase_flow_outcome"] = "purchase_flow_outcome"

    def __post_init__(self) -> None:
        _validate_schema_version(self.schema_version)
        _validate_app_version(self.app_version)
        _validate_choice(self.platform, _PLATFORMS, "platform")
        _validate_choice(self.purchase_offer, _PURCHASE_OFFERS, "purchase offer")
        _validate_choice(self.purchase_outcome, _PURCHASE_OUTCOMES, "purchase outcome")

    def to_record(self) -> dict[str, str | int]:
        return {
            "event_name": self.event_name,
            "schema_version": self.schema_version,
            "app_version": self.app_version,
            "platform": self.platform,
            "purchase_offer": self.purchase_offer,
            "purchase_outcome": self.purchase_outcome,
        }


type OperationalAnalyticsEvent = (
    AppStartupEvent | RouteLoadFailureEvent | PurchaseFlowOutcomeEvent
)

_EVENT_KEYS: Final = {
    "app_startup": frozenset(
        {
            "app_version",
            "event_name",
            "platform",
            "schema_version",
            "startup_result",
        }
    ),
    "route_load_failed": frozenset(
        {
            "app_version",
            "event_name",
            "failure_code",
            "platform",
            "route_id",
            "schema_version",
        }
    ),
    "purchase_flow_outcome": frozenset(
        {
            "app_version",
            "event_name",
            "platform",
            "purchase_offer",
            "purchase_outcome",
            "schema_version",
        }
    ),
}


def validate_operational_event(
    payload: Mapping[str, object],
) -> OperationalAnalyticsEvent:
    """Validate and convert an external mapping to a typed event.

    Exact key sets are checked before values.  This means free-form
    ``properties`` and health-related fields are rejected even when their
    values look harmless.
    """

    event_name = payload.get("event_name")
    if not isinstance(event_name, str) or event_name not in _EVENT_KEYS:
        raise AnalyticsValidationError("unsupported operational analytics event")
    _require_exact_keys(payload, _EVENT_KEYS[event_name])

    schema_version = payload["schema_version"]
    _validate_schema_version(schema_version)
    app_version = _validate_app_version(payload["app_version"])
    platform = _validate_choice(payload["platform"], _PLATFORMS, "platform")

    if event_name == "app_startup":
        return AppStartupEvent(
            app_version=app_version,
            platform=platform,  # type: ignore[arg-type]
            startup_result=_validate_choice(
                payload["startup_result"], _STARTUP_RESULTS, "startup result"
            ),  # type: ignore[arg-type]
        )
    if event_name == "route_load_failed":
        return RouteLoadFailureEvent(
            app_version=app_version,
            platform=platform,  # type: ignore[arg-type]
            route_id=_validate_choice(payload["route_id"], _ROUTE_IDS, "route"),  # type: ignore[arg-type]
            failure_code=_validate_choice(
                payload["failure_code"], _ROUTE_FAILURE_CODES, "route failure"
            ),  # type: ignore[arg-type]
        )
    return PurchaseFlowOutcomeEvent(
        app_version=app_version,
        platform=platform,  # type: ignore[arg-type]
        purchase_offer=_validate_choice(
            payload["purchase_offer"], _PURCHASE_OFFERS, "purchase offer"
        ),  # type: ignore[arg-type]
        purchase_outcome=_validate_choice(
            payload["purchase_outcome"], _PURCHASE_OUTCOMES, "purchase outcome"
        ),  # type: ignore[arg-type]
    )


def validate_consent_state(value: object) -> ConsentState:
    """Validate an explicit analytics privacy choice."""

    return _validate_choice(value, _CONSENT_STATES, "consent state")  # type: ignore[return-value]
