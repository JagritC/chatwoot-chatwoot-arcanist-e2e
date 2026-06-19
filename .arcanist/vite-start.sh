#!/bin/sh
set -eu

cd /app

git config --global --add safe.directory /app >/dev/null 2>&1 || true
export HUSKY=0

pnpm install --force
bundle install

exec "$@"
