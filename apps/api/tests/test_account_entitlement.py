from datetime import UTC, datetime, timedelta

import pytest
from pydantic import ValidationError

from letter_api.application.account_entitlement import (
    AccountIdentityService,
    BillingProviderUnavailable,
    EntitlementService,
    ServerDeletionService,
    is_premium_access,
)
from letter_api.application.account_entitlement_models import (
    AccountIdentityModel,
    RestoreEntitlementModel,
    SubscriptionEntitlementModel,
)
from letter_api.domain.account_entitlement import (
    AccountIdentity,
    BillingStore,
    DeletionState,
    EntitlementAvailability,
    EntitlementState,
    IdentityKind,
    IdentityProvider,
    ProviderEntitlement,
    ServerDeletionRequest,
    SubscriptionEntitlement,
)

NOW = datetime(2026, 7, 28, 9, 0, tzinfo=UTC)


class IdentityRepositoryFake:
    def __init__(self) -> None:
        self.items: dict[str, AccountIdentity] = {}

    def get(self, account_id: str) -> AccountIdentity | None:
        return self.items.get(account_id)

    def save(self, identity: AccountIdentity) -> AccountIdentity:
        self.items[identity.account_id] = identity
        return identity


class EntitlementRepositoryFake:
    def __init__(self) -> None:
        self.items: dict[tuple[str, str], SubscriptionEntitlement] = {}

    def get(self, account_id: str, product_id: str) -> SubscriptionEntitlement | None:
        return self.items.get((account_id, product_id))

    def save(self, entitlement: SubscriptionEntitlement) -> SubscriptionEntitlement:
        self.items[(entitlement.account_id, entitlement.product_id)] = entitlement
        return entitlement


class BillingProviderFake:
    def __init__(self, result: ProviderEntitlement | None = None) -> None:
        self.result = result
        self.calls: list[tuple[str, BillingStore, str]] = []
        self.unavailable = False

    def restore(
        self,
        *,
        account_id: str,
        store: BillingStore,
        product_id: str,
    ) -> ProviderEntitlement:
        self.calls.append((account_id, store, product_id))
        if self.unavailable:
            raise BillingProviderUnavailable
        assert self.result is not None
        return self.result


class ServerDeletionRepositoryFake:
    def __init__(self) -> None:
        self.requests: dict[str, ServerDeletionRequest] = {}
        self.deleted_accounts: list[str] = []

    def get_request(self, request_id: str) -> ServerDeletionRequest | None:
        return self.requests.get(request_id)

    def save_request(self, request: ServerDeletionRequest) -> ServerDeletionRequest:
        self.requests[request.request_id] = request
        return request

    def delete_operational_account(self, account_id: str) -> None:
        self.deleted_accounts.append(account_id)


def test_identity_service_handles_anonymous_and_authenticated_identities() -> None:
    repository = IdentityRepositoryFake()
    service = AccountIdentityService(repository)

    anonymous = AccountIdentity(
        account_id="anon-001",
        kind=IdentityKind.ANONYMOUS,
        provider=IdentityProvider.LOCAL,
        subject_id="device-subject-001",
        created_at=NOW,
        updated_at=NOW,
    )
    authenticated = AccountIdentity(
        account_id="acct-001",
        kind=IdentityKind.AUTHENTICATED,
        provider=IdentityProvider.SUPABASE,
        subject_id="auth-subject-001",
        created_at=NOW,
        updated_at=NOW,
    )

    assert service.register(anonymous) == anonymous
    assert service.register(authenticated) == authenticated
    assert service.get("anon-001") == anonymous
    assert service.get("acct-001") == authenticated


def test_identity_rejects_inconsistent_provider() -> None:
    with pytest.raises(ValueError, match="anonymous"):
        AccountIdentity(
            account_id="anon-001",
            kind=IdentityKind.ANONYMOUS,
            provider=IdentityProvider.SUPABASE,
            subject_id="device-subject-001",
            created_at=NOW,
            updated_at=NOW,
        )


def test_restore_persists_provider_state_without_accepting_unknown_fields() -> None:
    repository = EntitlementRepositoryFake()
    provider = BillingProviderFake(
        ProviderEntitlement(
            account_id="anon-001",
            product_id="letter-annual",
            store=BillingStore.APPLE,
            state=EntitlementState.RESTORED,
            checked_at=NOW,
            provider_reference="transaction-001",
        )
    )
    service = EntitlementService(repository, provider, clock=lambda: NOW)

    restored = service.restore(
        account_id="anon-001",
        store=BillingStore.APPLE,
        product_id="letter-annual",
    )

    assert restored.state is EntitlementState.RESTORED
    assert restored.availability is EntitlementAvailability.ONLINE
    assert is_premium_access(restored)
    assert provider.calls == [("anon-001", BillingStore.APPLE, "letter-annual")]

    with pytest.raises(ValidationError):
        RestoreEntitlementModel.model_validate(
            {
                "account_id": "anon-001",
                "product_id": "letter-annual",
                "store": "apple",
                "cycle_date": "2026-07-28",
            }
        )


def test_pydantic_boundary_round_trips_domain_models() -> None:
    identity_model = AccountIdentityModel(
        account_id="anon-001",
        kind="anonymous",
        provider="local",
        subject_id="device-subject-001",
        created_at=NOW,
        updated_at=NOW,
    )
    assert identity_model.to_domain().kind is IdentityKind.ANONYMOUS

    entitlement = SubscriptionEntitlement(
        account_id="anon-001",
        product_id="letter-monthly",
        store=BillingStore.GOOGLE,
        state=EntitlementState.PENDING,
        availability=EntitlementAvailability.ONLINE,
        checked_at=NOW,
    )
    model = SubscriptionEntitlementModel.from_domain(entitlement)
    assert model.to_domain() == entitlement
    assert "symptom" not in model.model_dump_json().lower()


def test_reconcile_moves_expired_entitlement_through_grace_then_expired() -> None:
    repository = EntitlementRepositoryFake()
    provider = BillingProviderFake()
    repository.save(
        SubscriptionEntitlement(
            account_id="anon-001",
            product_id="letter-monthly",
            store=BillingStore.GOOGLE,
            state=EntitlementState.ACTIVE,
            availability=EntitlementAvailability.ONLINE,
            checked_at=NOW,
            expires_at=NOW + timedelta(hours=1),
            grace_expires_at=NOW + timedelta(hours=3),
        )
    )

    grace_service = EntitlementService(
        repository,
        provider,
        clock=lambda: NOW + timedelta(hours=2),
    )
    grace = grace_service.reconcile(
        account_id="anon-001",
        product_id="letter-monthly",
    )
    assert grace is not None
    assert grace.state is EntitlementState.GRACE
    assert is_premium_access(grace)

    expired_service = EntitlementService(
        repository,
        provider,
        clock=lambda: NOW + timedelta(hours=4),
    )
    expired = expired_service.reconcile(
        account_id="anon-001",
        product_id="letter-monthly",
    )
    assert expired is not None
    assert expired.state is EntitlementState.EXPIRED
    assert not is_premium_access(expired)


def test_unavailable_restore_returns_offline_state_without_deleting_cache() -> None:
    repository = EntitlementRepositoryFake()
    cached = SubscriptionEntitlement(
        account_id="anon-001",
        product_id="letter-annual",
        store=BillingStore.APPLE,
        state=EntitlementState.ACTIVE,
        availability=EntitlementAvailability.ONLINE,
        checked_at=NOW,
    )
    repository.save(cached)
    provider = BillingProviderFake()
    provider.unavailable = True
    service = EntitlementService(repository, provider, clock=lambda: NOW)

    offline = service.restore(
        account_id="anon-001",
        store=BillingStore.APPLE,
        product_id="letter-annual",
    )

    assert offline.state is EntitlementState.OFFLINE
    assert offline.last_known_state is EntitlementState.ACTIVE
    assert is_premium_access(offline)
    assert repository.get("anon-001", "letter-annual") == offline


def test_server_deletion_is_explicit_idempotent_and_does_not_delete_local_data() -> (
    None
):
    repository = ServerDeletionRepositoryFake()
    service = ServerDeletionService(repository, clock=lambda: NOW)

    first = service.request(request_id="delete-001", account_id="acct-001")
    second = service.request(request_id="delete-001", account_id="acct-001")

    assert first.server_data_deleted
    assert first.local_data_untouched
    assert first.local_deletion_required
    assert first.state is DeletionState.COMPLETED
    assert second == first
    assert repository.deleted_accounts == ["acct-001"]

    with pytest.raises(ValueError, match="another account"):
        service.request(request_id="delete-001", account_id="acct-002")
