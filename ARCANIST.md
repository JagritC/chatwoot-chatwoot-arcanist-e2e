# Arcanist Guide

## Build, boot, and test

- App runtime: `docker compose -f docker-compose.arcanist.yml -f .arcanist/docker-compose.override.yml up -d`
- App URL: `http://127.0.0.1:3000/app/login`
- Stop runtime: `docker compose -f docker-compose.arcanist.yml -f .arcanist/docker-compose.override.yml down`
- Frontend dev port: `http://127.0.0.1:3036`
- Repo setup: `.arcanist/setup.sh`
- Arcanist smoke verify: `.arcanist/verify/runtime-smoke.sh`
- JS lint: `pnpm run eslint`
- JS tests: `pnpm run test:coverage`
- Ruby lint: `eval "$(rbenv init - bash)" && bundle exec rubocop --parallel`
- Ruby tests: `eval "$(rbenv init - bash)" && bundle exec rspec`

## Runtime notes

- The Arcanist runtime uses the repo's `docker-compose.arcanist.yml` plus `.arcanist/docker-compose.override.yml`.
- `web` runs `bundle exec rails db:prepare && bundle exec rails s -p 3000 -b 0.0.0.0`, so each sandbox starts from an empty DB and migrates on boot.
- `postgres`, `redis`, `mailhog`, `vite`, and `web` are all part of the boot path. The override adds healthchecks and shares the Ruby bundle cache between `web` and `vite`.
- Auth is local and non-secret: `.arcanist/auth.sh` creates or refreshes a confirmed non-2FA admin user at `arcanist@example.com`, signs in through `/auth/sign_in`, and writes Playwright storage state to `$ARCANIST_AUTH_STATE_PATH`.
- The runtime only needs the non-secret env already declared in `.arcanist.json`. Third-party integration secrets from `.env.example` remain optional unless a future task exercises those integrations.

## Gotchas

- `pnpm install` runs a Husky `prepare` hook that warns about Git safe-directory inside containers; `.arcanist/vite-start.sh` marks `/app` safe before starting Vite.
- The first cold boot is slower because `web` and `vite` hydrate gems and `node_modules` into Docker volumes; later boots reuse those volumes.
- Login proof should use a DB-backed route after auth, not only `/health`. The smoke verify checks `/api/v1/accounts/:id` with the generated auth state.
- If Ruby commands are run outside Docker, initialize rbenv first: `eval "$(rbenv init - bash)"`.

## Instruction Index

- `AGENTS.md` (`Chatwoot Development Guidelines`): repo-wide development workflow, verification requirements, commit conventions, enterprise overlay guidance, and PR-format rules.
- `CLAUDE.md` (`Chatwoot Development Guidelines`): same repo-wide guidance mirrored for alternate agents.
- `.github/PULL_REQUEST_TEMPLATE.md` (`Pull Request Template`): legacy PR structure; Arcanist uses `.arcanist/pr-template.md` instead so the draft PR matches the repo's required sections without literal checklist tokens.
