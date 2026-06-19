#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILES=(-f "$ROOT_DIR/docker-compose.arcanist.yml" -f "$ROOT_DIR/.arcanist/docker-compose.override.yml")
BASE_URL="${ARCANIST_BASE_URL:-http://127.0.0.1:3000}"
STATE_PATH="$(mktemp)"

source "$ROOT_DIR/.arcanist/compose-env.sh"

cleanup() {
  rm -f "$STATE_PATH"
}
trap cleanup EXIT

docker compose "${COMPOSE_FILES[@]}" config >/dev/null
docker compose "${COMPOSE_FILES[@]}" up -d >/dev/null

for _ in $(seq 1 120); do
  if curl -fsS "$BASE_URL/health" >/dev/null; then
    break
  fi
  sleep 2
done

curl -fsS "$BASE_URL/health" >/dev/null

ACCOUNT_ID="$(
  ARCANIST_BASE_URL="$BASE_URL" \
  ARCANIST_AUTH_STATE_PATH="$STATE_PATH" \
  "$ROOT_DIR/.arcanist/auth.sh"
)"

AUTH_VALUES="$(
  node -e '
    const fs = require("fs");
    const state = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const cookie = state.cookies.find(entry => entry.name === "cw_d_session_info");
    const auth = JSON.parse(decodeURIComponent(cookie.value));
    process.stdout.write([
      auth["access-token"],
      auth["token-type"],
      auth.client,
      auth.expiry,
      auth.uid,
    ].join("\n"));
  ' "$STATE_PATH"
)"

ACCESS_TOKEN="$(printf '%s\n' "$AUTH_VALUES" | sed -n '1p')"
TOKEN_TYPE="$(printf '%s\n' "$AUTH_VALUES" | sed -n '2p')"
CLIENT="$(printf '%s\n' "$AUTH_VALUES" | sed -n '3p')"
EXPIRY="$(printf '%s\n' "$AUTH_VALUES" | sed -n '4p')"
AUTH_UID="$(printf '%s\n' "$AUTH_VALUES" | sed -n '5p')"

curl -fsS \
  -H "access-token: $ACCESS_TOKEN" \
  -H "token-type: $TOKEN_TYPE" \
  -H "client: $CLIENT" \
  -H "expiry: $EXPIRY" \
  -H "uid: $AUTH_UID" \
  "$BASE_URL/api/v1/accounts/$ACCOUNT_ID" >/dev/null
