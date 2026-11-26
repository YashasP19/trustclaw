FROM node:22-slim AS base
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
RUN corepack enable
WORKDIR /app

FROM base AS deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# NEXT_PUBLIC_APP_URL is inlined into the client bundle, so it must be set at build time.
ARG NEXT_PUBLIC_APP_URL=http://localhost:3000
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL
# Env validation cannot be skipped for production builds, so pass placeholders.
# Real values are provided at runtime and are not baked into the image.
RUN DATABASE_URL=postgresql://build:build@localhost:5432/build \
    BETTER_AUTH_SECRET=build-placeholder \
    COMPOSIO_API_KEY=build-placeholder \
    CRON_SECRET=build-placeholder \
    pnpm prisma generate \
  && DATABASE_URL=postgresql://build:build@localhost:5432/build \
    BETTER_AUTH_SECRET=build-placeholder \
    COMPOSIO_API_KEY=build-placeholder \
    CRON_SECRET=build-placeholder \
    pnpm build:local

FROM base AS runner
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=builder --chown=node:node /app ./
USER node
EXPOSE 3000
# Apply the schema without --accept-data-loss so destructive changes fail loudly.
CMD ["sh", "-c", "node_modules/.bin/prisma db push && node_modules/.bin/next start"]
