#!/bin/sh
# CASA DF — Entrypoint Docker
# Valida as variáveis e, quando autorizado explicitamente, prepara um banco novo.
set -e

node scripts/validate-env.mjs

if [ "${RUN_MIGRATIONS_ON_START:-false}" = "true" ]; then
  echo "[casadf] Executando migrações antes de iniciar..."
  node scripts/migrate-all.mjs
fi

exec "$@"
