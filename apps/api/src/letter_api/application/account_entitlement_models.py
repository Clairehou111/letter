"""Pydantic boundary models for non-sensitive account operations."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from letter_api.domain.account_entitlement import (
    AccountIdentity,
    BillingStore,
    DeletionState,
    EntitlementAvailability,
    EntitlementState,
    IdentityKind,
    IdentityProvider,
    ServerDeletionReceipt,
    SubscriptionEntitlement,
)


class OperationalModel(BaseModel):
    """Reject unknown fields so health content cannot hide in API payloads."""

    model_config = ConfigDict(extra="forbid", frozen=True)


class AccountIdentityModel(OperationalModel):
    account_id: str = Field(min_length=1)
    kind: IdentityKind
    provider: IdentityProvider
    subject_id: str = Field(min_length=1)
    created_at: datetime
    updated_at: datetime

    def to_domain(self) -> AccountIdentity:
        return AccountIdentity(**self.model_dump())


class RestoreEntitlementModel(OperationalModel):
    account_id: str = Field(min_length=1)
    product_id: str = Field(min_length=1)
    store: BillingStore


class SubscriptionEntitlementModel(OperationalModel):
    account_id: str = Field(min_length=1)
    product_id: str = Field(min_length=1)
    store: BillingStore
    state: EntitlementState
    availability: EntitlementAvailability
    checked_at: datetime
    expires_at: datetime | None = None
    grace_expires_at: datetime | None = None
    provider_reference: str | None = None
    last_known_state: EntitlementState | None = None

    @classmethod
    def from_domain(
        cls,
        entitlement: SubscriptionEntitlement,
    ) -> "SubscriptionEntitlementModel":
        return cls(
            account_id=entitlement.account_id,
            product_id=entitlement.product_id,
            store=entitlement.store,
            state=entitlement.state,
            availability=entitlement.availability,
            checked_at=entitlement.checked_at,
            expires_at=entitlement.expires_at,
            grace_expires_at=entitlement.grace_expires_at,
            provider_reference=entitlement.provider_reference,
            last_known_state=entitlement.last_known_state,
        )

    def to_domain(self) -> SubscriptionEntitlement:
        return SubscriptionEntitlement(**self.model_dump())


class ServerDeletionRequestModel(OperationalModel):
    request_id: str = Field(min_length=1)
    account_id: str = Field(min_length=1)


class ServerDeletionReceiptModel(OperationalModel):
    request_id: str
    account_id: str
    state: DeletionState
    completed_at: datetime | None
    server_data_deleted: bool
    local_data_untouched: bool
    local_deletion_required: bool

    @classmethod
    def from_domain(
        cls,
        receipt: ServerDeletionReceipt,
    ) -> "ServerDeletionReceiptModel":
        return cls(
            request_id=receipt.request_id,
            account_id=receipt.account_id,
            state=receipt.state,
            completed_at=receipt.completed_at,
            server_data_deleted=receipt.server_data_deleted,
            local_data_untouched=receipt.local_data_untouched,
            local_deletion_required=receipt.local_deletion_required,
        )
