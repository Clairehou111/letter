"""Application ports and use cases for operational account state."""

from collections.abc import Callable
from datetime import datetime
from typing import Protocol

from letter_api.domain.account_entitlement import (
    AccountIdentity,
    BillingStore,
    ConsentReceipt,
    DeletionState,
    ProviderEntitlement,
    ServerDeletionReceipt,
    ServerDeletionRequest,
    SubscriptionEntitlement,
    utc_now,
)

Clock = Callable[[], datetime]


class IdentityRepository(Protocol):
    """Persistence port for pseudonymous account identity."""

    def get(self, account_id: str) -> AccountIdentity | None: ...

    def save(self, identity: AccountIdentity) -> AccountIdentity: ...


class AuthenticationProvider(Protocol):
    """Adapter boundary for Supabase Auth or another identity provider."""

    def authenticate(
        self,
        *,
        account_id: str,
        subject_id: str,
        now: datetime,
    ) -> AccountIdentity: ...


class EntitlementRepository(Protocol):
    """Persistence port for the latest safe entitlement snapshot."""

    def get(
        self,
        account_id: str,
        product_id: str,
    ) -> SubscriptionEntitlement | None: ...

    def save(self, entitlement: SubscriptionEntitlement) -> SubscriptionEntitlement: ...


class BillingProvider(Protocol):
    """Adapter boundary for RevenueCat or another store-backed provider."""

    def restore(
        self,
        *,
        account_id: str,
        store: BillingStore,
        product_id: str,
    ) -> ProviderEntitlement: ...


class BillingProviderUnavailable(Exception):
    """Raised by an adapter when a restore cannot be verified now."""


class ServerDeletionRepository(Protocol):
    """Persistence port for operational server deletion requests."""

    def get_request(self, request_id: str) -> ServerDeletionRequest | None: ...

    def save_request(self, request: ServerDeletionRequest) -> ServerDeletionRequest: ...

    def delete_operational_account(self, account_id: str) -> None: ...


class AccountIdentityService:
    """Save only caller-provided pseudonymous identity information."""

    def __init__(self, repository: IdentityRepository) -> None:
        self._repository = repository

    def register(self, identity: AccountIdentity) -> AccountIdentity:
        return self._repository.save(identity)

    def get(self, account_id: str) -> AccountIdentity | None:
        return self._repository.get(account_id)


class EntitlementService:
    """Restore and locally reconcile paid access without touching local health data."""

    def __init__(
        self,
        repository: EntitlementRepository,
        provider: BillingProvider,
        clock: Clock = utc_now,
    ) -> None:
        self._repository = repository
        self._provider = provider
        self._clock = clock

    def restore(
        self,
        *,
        account_id: str,
        store: BillingStore,
        product_id: str,
    ) -> SubscriptionEntitlement:
        try:
            provider_result = self._provider.restore(
                account_id=account_id,
                store=store,
                product_id=product_id,
            )
        except BillingProviderUnavailable:
            existing = self._repository.get(account_id, product_id)
            if existing is None:
                raise
            offline = existing.as_offline(self._now())
            return self._repository.save(offline)

        if (
            provider_result.account_id != account_id
            or provider_result.product_id != product_id
            or provider_result.store != store
        ):
            raise ValueError("billing provider returned a mismatched entitlement")
        entitlement = SubscriptionEntitlement.from_provider(provider_result)
        return self._repository.save(entitlement)

    def reconcile(
        self,
        *,
        account_id: str,
        product_id: str,
    ) -> SubscriptionEntitlement | None:
        existing = self._repository.get(account_id, product_id)
        if existing is None:
            return None
        reconciled = existing.reconciled(self._now())
        if reconciled == existing:
            return existing
        return self._repository.save(reconciled)

    def _now(self) -> datetime:
        return self._clock()


class ServerDeletionService:
    """Delete server operational state while explicitly preserving device data."""

    def __init__(
        self,
        repository: ServerDeletionRepository,
        clock: Clock = utc_now,
    ) -> None:
        self._repository = repository
        self._clock = clock

    def request(
        self,
        *,
        request_id: str,
        account_id: str,
    ) -> ServerDeletionReceipt:
        existing = self._repository.get_request(request_id)
        if existing is not None and existing.account_id != account_id:
            raise ValueError("deletion request belongs to another account")
        if existing is not None and existing.state == DeletionState.COMPLETED:
            return ServerDeletionReceipt(
                request_id=existing.request_id,
                account_id=existing.account_id,
                state=DeletionState.COMPLETED,
                completed_at=existing.completed_at,
                server_data_deleted=True,
            )

        deletion_request = ServerDeletionRequest(
            request_id=request_id,
            account_id=account_id,
            requested_at=self._now(),
        )
        self._repository.save_request(deletion_request)
        self._repository.delete_operational_account(account_id)
        completed_at = self._now()
        self._repository.save_request(
            ServerDeletionRequest(
                request_id=request_id,
                account_id=account_id,
                requested_at=deletion_request.requested_at,
                state=DeletionState.COMPLETED,
                completed_at=completed_at,
            )
        )
        return ServerDeletionReceipt(
            request_id=request_id,
            account_id=account_id,
            state=DeletionState.COMPLETED,
            completed_at=completed_at,
            server_data_deleted=True,
        )

    def _now(self) -> datetime:
        return self._clock()


def consent_receipt_for(
    *,
    receipt_id: str,
    policy_version: str,
    accepted_at: datetime,
) -> ConsentReceipt:
    """Build the only consent value accepted by the operational layer."""

    return ConsentReceipt(
        receipt_id=receipt_id,
        policy_version=policy_version,
        accepted_at=accepted_at,
    )


def is_premium_access(entitlement: SubscriptionEntitlement | None) -> bool:
    """Centralize the reversible premium gate decision."""

    return entitlement is not None and entitlement.access_granted
