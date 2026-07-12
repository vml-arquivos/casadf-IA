# syntax=docker/dockerfile:1.7

# ─── Stage 1: dependências e build ────────────────────────────────────────────
FROM node:20-slim AS builder

RUN corepack enable && corepack prepare pnpm@10.4.1 --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml .npmrc ./
COPY patches/ ./patches/

RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

COPY . .

# Limita o heap para não disputar toda a RAM da VPS com o daemon Docker.
ENV NODE_OPTIONS=--max-old-space-size=2048

RUN set -eu; \
    (while true; do echo "[casadf-build] build em andamento..."; sleep 20; done) & \
    HEARTBEAT_PID=$!; \
    pnpm run build; \
    BUILD_STATUS=$?; \
    kill "$HEARTBEAT_PID" 2>/dev/null || true; \
    wait "$HEARTBEAT_PID" 2>/dev/null || true; \
    exit "$BUILD_STATUS"

# O runtime recebe somente dependências de produção. O mesmo cache da instalação
# é montado em modo offline: não há nova dependência de rede nem outra instalação
# concorrendo com o Vite durante o Docker build.
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    CI=true npm_config_offline=true pnpm prune --prod

# ─── Stage 2: runtime leve ────────────────────────────────────────────────────
FROM node:20-slim AS runner

# Esta cópia no início cria dependência explícita do builder. Assim o BuildKit
# não executa o runtime em paralelo com o Vite, reduzindo o pico de RAM.
COPY --from=builder --chown=node:node /app/dist /app/dist

USER root
ENV DEBIAN_FRONTEND=noninteractive

# O projeto já inclui @sparticuz/chromium. Não instalamos o pacote chromium do
# Debian (mais de 160 dependências), que causava o crash do servidor no build.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget fonts-freefont-ttf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/data/casadf /var/log/casadf \
    && chown -R node:node /var/data/casadf /var/log/casadf

WORKDIR /app

COPY --from=builder --chown=node:node /app/package.json ./package.json
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/scripts ./scripts
COPY --from=builder --chown=node:node /app/db ./db
COPY --chown=node:node docker-entrypoint.sh /usr/local/bin/casadf-entrypoint

RUN chmod +x /usr/local/bin/casadf-entrypoint

USER node

ENV NODE_ENV=production
ENV PORT=4000
ENV DATA_DIR=/var/data/casadf
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:4000/api/health || exit 1

ENTRYPOINT ["/usr/local/bin/casadf-entrypoint"]
CMD ["node", "dist/index.js"]
