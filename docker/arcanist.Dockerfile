FROM chatwoot/chatwoot:latest

ARG PNPM_VERSION="10.2.0"
ENV BUNDLE_PATH="/gems"
ENV BUNDLE_WITHOUT="test"
ENV NODE_ENV="development"
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV RAILS_ENV="development"
ENV PATH="$PNPM_HOME:$PATH"

RUN apk add --no-cache postgresql-dev \
  && ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && npm install -g pnpm@${PNPM_VERSION} \
  && bundle config set without test \
  && bundle install -j 4 -r 3

WORKDIR /app
