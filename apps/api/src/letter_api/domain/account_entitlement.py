"""Framework-independent account and subscription domain objects.

These objects intentionally contain operational identity and billing state only.
They must never grow fields for readable health data or private user content.
"""

from dataclasses import dataclass
from datetime import UTC, datetime
from enum import StrEnum


class IdentityKind(StrEnum):
    """Whether an account has an external authenticated subject."""

    ANONYMOUS = "anonymous"
    AUTHENTICATED = "authenticated"


class IdentityProvider(StrEnum):
    """Identity systems that may be connected by an adapter later."""

    LOCAL = "local"
    SUPABASE = "supabase"


class BillingStore(StrEnum):
    """Store whose purchase state is represented by the entitlement."""

    APPLE = "apple"
    GOOGLE = "google"


class EntitlementState(StrEnum):
    """Provider and local-cache states exposed to paywall decisions."""

    INACTIVE = "inactive"
    PENDING = "pending"
    ACTIVE = "active"
    RESTORED = "restored"
    GRACE = "grace"
    EXPIRED = "expired"
    CANCELLED = "cancelled"
    OFFLINE = "offline"


class EntitlementAvailability(StrEnum):
    """Whether the state was verified against a provider now."""

    ONLINE = "online"
    OFFLINE = "offline"


class DeletionState(StrEnum):
    """Lifecycle of an operational server-account deletion request."""

    REQUESTED = "requested"
    COMPLETED = "completed"
    FAILED = "failed"


def _require_identifier(value: str, field_name: str) -> None:
    if not value.strip():
        raise ValueError(f"{field_name} must not be blank")


def _require_utc(value: datetime, field_name: str) -> None:
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError(f"{field_name} must be timezone-aware")


@dataclass(frozen=True, slots=True)
class AccountIdentity:
    """Pseudonymous account identity with no profile or health attributes."""

    account_id: str
    kind: IdentityKind
    provider: IdentityProvider
    subject_id: str
    created_at: datetime
    updated_at: datetime

    def __post_init__(self) -> None:
        _require_identifier(self.account_id, "account_id")
        _require_identifier(self.subject_id, "subject_id")
        _require_utc(self.created_at, "created_at")
        _require_utc(self.updated_at, "updated_at")
        if (
            self.kind == IdentityKind.ANONYMOUS
            and self.provider != IdentityProvider.LOCAL
        ):
            raise ValueError("anonymous identities must use the local provider")
        if (
            self.kind == IdentityKind.AUTHENTICATED
            and self.provider == IdentityProvider.LOCAL
        ):
            raise ValueError("authenticated identities must use an external provider")


@dataclass(frozen=True, slots=True)
class ConsentReceipt:
    """A reference to an operational consent decision, not its content."""

    receipt_id: str
    policy_version: str
    accepted_at: datetime

    def __post_init__(self) -> None:
        _require_identifier(self.receipt_id, "receipt_id")
        _require_identifier(self.policy_version, "policy_version")
        _require_utc(self.accepted_at, "accepted_at")


@dataclass(frozen=True, slots=True)
class ProviderEntitlement:
    """The safe, provider-neutral result returned by a billing adapter."""

    account_id: str
    product_id: str
    store: BillingStore
    state: EntitlementState
    checked_at: datetime
    expires_at: datetime | None = None
    grace_expires_at: datetime | None = None
    provider_reference: str | None = None

    def __post_init__(self) -> None:
        _require_identifier(self.account_id, "account_id")
        _require_identifier(self.product_id, "product_id")
        _require_utc(self.checked_at, "checked_at")
        if self.expires_at is not None:
            _require_utc(self.expires_at, "expires_at")
        if self.grace_expires_at is not None:
            _require_utc(self.grace_expires_at, "grace_expires_at")
        if self.provider_reference is not None:
            _require_identifier(self.provider_reference, "provider_reference")
        if self.state == EntitlementState.OFFLINE:
            raise ValueError("provider entitlements cannot be offline")


@dataclass(frozen=True, slots=True)
class SubscriptionEntitlement:
    """Cached entitlement used by application paywall decisions."""

    account_id: str
    product_id: str
    store: BillingStore
    state: EntitlementState
    availability: EntitlementAvailability
    checked_at: datetime
    expires_at: datetime | None = None
    grace_expires_at: datetime | None = None
    provider_reference: str | None = None
    last_known_state: EntitlementState | None = None

    def __post_init__(self) -> None:
        _require_identifier(self.account_id, "account_id")
        _require_identifier(self.product_id, "product_id")
        _require_utc(self.checked_at, "checked_at")
        if self.expires_at is not None:
            _require_utc(self.expires_at, "expires_at")
        if self.grace_expires_at is not None:
            _require_utc(self.grace_expires_at, "grace_expires_at")
        if self.provider_reference is not None:
            _require_identifier(self.provider_reference, "provider_reference")
        if self.availability == EntitlementAvailability.OFFLINE:
            if self.state != EntitlementState.OFFLINE:
                raise ValueError("offline entitlements must use the offline state")
            if self.last_known_state is None:
                raise ValueError("offline entitlements require a last known state")
        elif self.state == EntitlementState.OFFLINE:
            raise ValueError("offline state requires offline availability")

    @property
    def access_granted(self) -> bool:
        """Whether a premium gate may be opened for this cached state."""

        if self.state in {
            EntitlementState.ACTIVE,
            EntitlementState.RESTORED,
            EntitlementState.GRACE,
        }:
            return True
        if self.state == EntitlementState.OFFLINE:
            return self.last_known_state in {
                EntitlementState.ACTIVE,
                EntitlementState.RESTORED,
                EntitlementState.GRACE,
            }
        return False

    @classmethod
    def from_provider(cls, result: ProviderEntitlement) -> "SubscriptionEntitlement":
        return cls(
            account_id=result.account_id,
            product_id=result.product_id,
            store=result.store,
            state=result.state,
            availability=EntitlementAvailability.ONLINE,
            checked_at=result.checked_at,
            expires_at=result.expires_at,
            grace_expires_at=result.grace_expires_at,
            provider_reference=result.provider_reference,
        )

    def as_offline(self, checked_at: datetime) -> "SubscriptionEntitlement":
        _require_utc(checked_at, "checked_at")
        return SubscriptionEntitlement(
            account_id=self.account_id,
            product_id=self.product_id,
            store=self.store,
            state=EntitlementState.OFFLINE,
            availability=EntitlementAvailability.OFFLINE,
            checked_at=checked_at,
            expires_at=self.expires_at,
            grace_expires_at=self.grace_expires_at,
            provider_reference=self.provider_reference,
            last_known_state=self.state
            if self.state != EntitlementState.OFFLINE
            else self.last_known_state,
        )

    def reconciled(self, now: datetime) -> "SubscriptionEntitlement":
        """Apply local expiry/grace timing without contacting a provider."""

        _require_utc(now, "now")
        if self.availability == EntitlementAvailability.OFFLINE:
            return self
        if self.state not in {
            EntitlementState.ACTIVE,
            EntitlementState.RESTORED,
            EntitlementState.GRACE,
        }:
            return self
        if self.expires_at is None or now < self.expires_at:
            return self
        next_state = (
            EntitlementState.GRACE
            if self.grace_expires_at is not None and now < self.grace_expires_at
            else EntitlementState.EXPIRED
        )
        return SubscriptionEntitlement(
            account_id=self.account_id,
            product_id=self.product_id,
            store=self.store,
            state=next_state,
            availability=self.availability,
            checked_at=now,
            expires_at=self.expires_at,
            grace_expires_at=self.grace_expires_at,
            provider_reference=self.provider_reference,
        )


@dataclass(frozen=True, slots=True)
class ServerDeletionRequest:
    """Explicit request to remove operational records on the server."""

    request_id: str
    account_id: str
    requested_at: datetime
    state: DeletionState = DeletionState.REQUESTED
    completed_at: datetime | None = None

    def __post_init__(self) -> None:
        _require_identifier(self.request_id, "request_id")
        _require_identifier(self.account_id, "account_id")
        _require_utc(self.requested_at, "requested_at")
        if self.completed_at is not None:
            _require_utc(self.completed_at, "completed_at")
        if self.state == DeletionState.COMPLETED and self.completed_at is None:
            raise ValueError("completed deletion requests require completed_at")
        if self.state == DeletionState.REQUESTED and self.completed_at is not None:
            raise ValueError("requested deletion requests cannot have completed_at")


@dataclass(frozen=True, slots=True)
class ServerDeletionReceipt:
    """Result that makes server and device deletion boundaries explicit."""

    request_id: str
    account_id: str
    state: DeletionState
    completed_at: datetime | None
    server_data_deleted: bool
    local_data_untouched: bool = True
    local_deletion_required: bool = True

    def __post_init__(self) -> None:
        _require_identifier(self.request_id, "request_id")
        _require_identifier(self.account_id, "account_id")
        if self.completed_at is not None:
            _require_utc(self.completed_at, "completed_at")
        if self.state == DeletionState.COMPLETED and not self.server_data_deleted:
            raise ValueError("completed deletion must confirm server data deletion")
        if not self.local_data_untouched:
            raise ValueError("server deletion cannot delete local device data")


def utc_now() -> datetime:
    """Provide an injectable clock default for application services."""

    return datetime.now(UTC)
