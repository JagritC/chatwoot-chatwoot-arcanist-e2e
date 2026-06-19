#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILES=(-f "$ROOT_DIR/docker-compose.arcanist.yml" -f "$ROOT_DIR/.arcanist/docker-compose.override.yml")
BASE_URL="${ARCANIST_BASE_URL:-http://127.0.0.1:3000}"
STATE_PATH="${ARCANIST_AUTH_STATE_PATH:?ARCANIST_AUTH_STATE_PATH must be set}"
AUTH_EMAIL="${ARCANIST_AUTH_EMAIL:-arcanist@example.com}"
AUTH_PASSWORD="${ARCANIST_AUTH_PASSWORD:-Password123@#}"

source "$ROOT_DIR/.arcanist/compose-env.sh"
export AUTH_EMAIL AUTH_PASSWORD

docker compose "${COMPOSE_FILES[@]}" up -d >/dev/null

docker compose "${COMPOSE_FILES[@]}" exec -T web sh -lc '
  git config --global --add safe.directory /app >/dev/null 2>&1 || true
  export ARCANIST_AUTH_EMAIL="$0"
  export ARCANIST_AUTH_PASSWORD="$1"
  bundle exec rails runner "
    email = ENV.fetch(\"ARCANIST_AUTH_EMAIL\")
    password = ENV.fetch(\"ARCANIST_AUTH_PASSWORD\")
    user = User.find_by(email: email)

    if user.nil?
      account = Account.create!(name: \"Arcanist Demo\")
      user = User.new(email: email, password: password, password_confirmation: password, name: \"Arcanist User\")
      user.confirm
      user.save!
      AccountUser.create!(account: account, user: user, role: :administrator)
    else
      user.password = password
      user.password_confirmation = password
      user.confirm unless user.confirmed?
      user.save! if user.changed?
      if user.account_users.empty?
        account = Account.create!(name: \"Arcanist Demo\")
        AccountUser.create!(account: account, user: user, role: :administrator)
      end
    end

    puts(user.account_users.first.account_id)
  "
' "$AUTH_EMAIL" "$AUTH_PASSWORD" >/tmp/arcanist-account-id.txt

ACCOUNT_ID="$(tr -d '\r\n' </tmp/arcanist-account-id.txt)"
export BASE_URL STATE_PATH ACCOUNT_ID

node <<'NODE'
const fs = require('fs');

async function main() {
  const baseUrl = process.env.BASE_URL;
  const email = process.env.AUTH_EMAIL;
  const password = process.env.AUTH_PASSWORD;
  const statePath = process.env.STATE_PATH;

  const response = await fetch(`${baseUrl}/auth/sign_in`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`sign_in failed: ${response.status} ${body}`);
  }

  const authHeaders = {
    'access-token': response.headers.get('access-token'),
    'token-type': response.headers.get('token-type'),
    client: response.headers.get('client'),
    expiry: response.headers.get('expiry'),
    uid: response.headers.get('uid'),
  };

  if (Object.values(authHeaders).some(value => !value)) {
    throw new Error(`sign_in missing auth headers: ${JSON.stringify(authHeaders)}`);
  }

  const url = new URL(baseUrl);
  const expires = Number(authHeaders.expiry);
  const cookieValue = encodeURIComponent(JSON.stringify(authHeaders));

  const storageState = {
    cookies: [
      {
        name: 'cw_d_session_info',
        value: cookieValue,
        domain: url.hostname,
        path: '/',
        expires,
        httpOnly: false,
        secure: url.protocol === 'https:',
        sameSite: 'Lax',
      },
    ],
    origins: [],
  };

  fs.writeFileSync(statePath, JSON.stringify(storageState, null, 2));
  process.stdout.write(`${process.env.ACCOUNT_ID}\n`);
}

main().catch(error => {
  console.error(error.message);
  process.exit(1);
});
NODE
