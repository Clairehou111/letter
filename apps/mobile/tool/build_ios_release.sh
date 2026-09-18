#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${LETTER_RELEASE_CONFIG:-$APP_DIR/config/release.local.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing release configuration: $CONFIG_FILE" >&2
  exit 1
fi

jq -e '
  (.LETTER_SUPABASE_URL | type == "string" and length > 0) and
  (.LETTER_SUPABASE_PUBLISHABLE_KEY | type == "string" and length > 0) and
  (.LETTER_REVENUECAT_APPLE_API_KEY | type == "string" and startswith("appl_"))
' "$CONFIG_FILE" >/dev/null

cd "$APP_DIR"
exec flutter build ipa \
  --release \
  --dart-define-from-file="$CONFIG_FILE" \
  "$@"
