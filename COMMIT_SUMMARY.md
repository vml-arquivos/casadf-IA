# Commit summary

## Título

```text
fix: finalize Casa DF production deployment
```

## Corpo

```text
- fix TypeScript and backend build failures
- validate required production environment variables
- add deterministic pnpm configuration and preflight checks
- package runtime assets, database migrations and entrypoint
- run first-deploy migrations only when explicitly enabled
- persist uploads under /var/data/casadf
- replace Debian Chromium install with @sparticuz/chromium
- serialize heavy Docker build stages and reuse pnpm cache offline
- add database-aware health check and disable admin SQL by default
- fix public AI property lookup identifier handling
- document exact Coolify configuration and persistent volume mount

Validated: TypeScript check, 26/26 tests and production build passed.
```

## Arquivos que precisam estar no mesmo commit

Este commit deve incluir **todo o conteúdo do pacote definitivo**, inclusive
`.npmrc`, `.dockerignore`, `.gitignore`, `Dockerfile`, `docker-entrypoint.sh`,
`package.json`, `scripts/`, `db/`, `server/`, `client/` e `shared/`.

Não inclua `.env.coolify`, `node_modules/` ou `dist/`.
