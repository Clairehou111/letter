# Letter Mobile

Flutter application for Letter's iOS and Android clients.

## Commands

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
```

The current Today experience uses synthetic content. It must not send that
state to the operational API. Product health records will use an encrypted
local data layer selected by a later feature specification.

The generated API client is located at
`lib/api/generated/letter_api_client.dart`. Regenerate it from the repository
root after updating the FastAPI contract.
