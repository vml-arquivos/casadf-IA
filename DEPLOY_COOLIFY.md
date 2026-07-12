# Deploy no Coolify — Casa DF Gestão Imobiliária

## Visão Geral

Este guia cobre o deploy do **Casa DF** em uma VPS Google Cloud usando o **Coolify** como orquestrador, com **PostgreSQL interno** do Coolify (mesmo projeto Docker).

## Pré-requisitos

- VPS Google Cloud com Coolify instalado
- Acesso ao painel Coolify como admin
- Repositório `vml-arquivos/casadf-IA` no GitHub
- Chaves de API: Gemini (IA), JWT Secret (gerar novo), Chatwoot (opcional)

---

## Passo 1 — Criar o Projeto no Coolify

1. Acesse o painel do Coolify
2. Clique em **"Add New Resource"** → **"Application"**
3. Conecte ao repositório: `https://github.com/vml-arquivos/casadf-IA`
4. Branch: `main`
5. Build Pack: **Docker** (já existe Dockerfile na raiz)

## Passo 2 — Adicionar PostgreSQL Interno

1. No mesmo projeto do Coolify, clique em **"Add New Resource"** → **"Service"** → **"PostgreSQL"**
2. O Coolify criará automaticamente um container PostgreSQL vinculado ao projeto
3. **Importante**: A variável `DATABASE_URL` será injetada automaticamente pelo Coolify na aplicação (não precisa preencher manualmente)
4. A conexão é via **rede interna Docker** — sem SSL, sem exposição de porta externa

### Dados de conexão (gerados automaticamente)

O Coolify injeta automaticamente:
- `DATABASE_URL` — string de conexão completa
- `POSTGRES_HOST` — hostname interno (ex: `postgresql-xxxxx`)
- `POSTGRES_PORT` — 5432
- `POSTGRES_USER` — `postgres`
- `POSTGRES_PASSWORD` — senha gerada automaticamente

## Passo 3 — Configurar Variáveis de Ambiente

No Coolify, vá em **"Environment Variables"** do serviço da aplicação e adicione:

| Variável | Valor | Observação |
|---|---|---|
| `DATABASE_URL` | (automático pelo Coolify) | Injetado pelo PostgreSQL service |
| `DATABASE_SSL` | `false` | Rede interna Docker, sem SSL |
| `JWT_SECRET` | (gerar: `openssl rand -hex 32`) | **NOVO** — não reutilize da Destrava |
| `SITE_DOMAIN` | `casadf.com.br` | Seu domínio real |
| `FRONTEND_URL` | `https://casadf.com.br` | URL pública do site |
| `GEMINI_API_KEY` | (chave Gemini) | Reutilizar da Destrava |
| `OPENAI_API_KEY` | (chave OpenAI, opcional) | Fallback para IA |
| `INTEGRATION_SECRET` | (gerar novo) | Integração Nexus |
| `POOL_MAX` | `15` | Pool de conexões PG |

### Variáveis de Build (Build Variables)

Estas são necessárias no momento do build do frontend:

| Variável | Valor |
|---|---|
| `VITE_APP_TITLE` | `Casa DF` |
| `VITE_APP_ID` | (conforme provisionamento) |
| `VITE_OAUTH_PORTAL_URL` | (se necessário) |
| `VITE_FRONTEND_FORGE_API_KEY` | (se necessário) |
| `VITE_FRONTEND_FORGE_API_URL` | (se necessário) |

## Passo 4 — Volume Persistente

**CRITICAL**: Configure um volume persistente para dados:

1. No Coolify, vá em **"Storage"** do serviço
2. Adicione um volume:
   - **Container Path**: `/var/data/casadf`
   - **Volume Name**: `casadf-data` (ou qualquer nome)
3. Isso preserva: fotos de imóveis, logos, PDFs gerados, uploads

Sem o volume, todos os arquivos se perdem a cada deploy/restart.

## Passo 5 — Migrações do Banco de Dados

Após o primeiro deploy, execute as migrations no PostgreSQL interno:

### Opção A — Via psql no container PostgreSQL (Coolify)

1. No Coolify, abra o terminal do container PostgreSQL
2. Execute:

```sql
-- Copie o conteúdo do arquivo:
-- db/migrations/070_ia_imobiliaria_completo.sql
-- e todas as migrations anteriores (001 a 069)

-- Para a migration 070 específica da IA:
\i /path/to/070_ia_imobiliaria_completo.sql
```

### Opção B — Script de migração automática

Crie um script ou use um health-check que rode as migrations na inicialização:

```bash
# Conectar ao PG do Coolify
psql "postgresql://postgres:SENHA@HOST:5432/postgres" -f /app/db/migrations/070_ia_imobiliaria_completo.sql
```

### Ordem das migrations

Execute na ordem numérica:
```
001 → 002 → ... → 068 → 070
```

A migration 070 cria 9 tabelas novas:
- `lead_scores`
- `imovel_matches`
- `simulacoes_multi_banco`
- `analises_juridicas`
- `analises_financeiras`
- `avaliacoes_imoveis`
- `assistente_sessions`
- `assistente_messages`
- `relatorios_inteligentes`

## Passo 6 — Deploy

1. No Coolify, clique em **"Deploy"** no serviço da aplicação
2. O Dockerfile será construído automaticamente:
   - Stage 1: Build do frontend (Vite) + backend (esbuild)
   - Stage 2: Runtime com Chromium + dependências
3. Após o deploy, verifique:
   - Health check: `GET /api/health` → `{ "status": "ok" }`
   - Frontend: acesso pelo domínio configurado

## Passo 7 — Configurar Domínio

1. No Coolify, vá em **"Domains"** do serviço
2. Adicione: `casadf.com.br` (ou seu domínio)
3. Configure o DNS (A record ou CNAME apontando para o IP da VPS)
4. SSL automático pelo Coolify (Let's Encrypt)

## Passo 8 — Configurar PostgreSQL no Frontend

O banco PostgreSQL do Coolify já estará acessível via `DATABASE_URL` injetada automaticamente. O código detecta:
- Hostname interno → **sem SSL** (adequado para Docker)
- Hostnames de provedores externos → **SSL automático**

## Troubleshooting

### Build falha no Coolify (timeout)

O Dockerfile já possui heartbeats para evitar timeout do Coolify em builds longos. Se ainda falhar:
- Aumente o **Build Timeout** no Coolify para `600` segundos
- Verifique se o VPS tem pelo menos **4GB RAM**

### Erro de conexão com PostgreSQL

- Verifique se o serviço PostgreSQL está **no mesmo projeto** do Coolify
- Verifique se `DATABASE_URL` está injetada corretamente
- `DATABASE_SSL` deve ser `false` para conexões internas

### Volume persistente não funcionando

- Verifique o **Mount Path**: deve ser exatamente `/var/data/casadf`
- Após adicionar o volume, **redeploy** o serviço

### Migrations falham

- Execute as migrations na ordem numérica correta
- A migration 070 é **idempotente** (usa `CREATE TABLE IF NOT EXISTS`)
- Verifique se as migrations anteriores (001-068) já foram executadas

---

## Estrutura de Arquivos Relevantes

```
casadf-IA/
├── Dockerfile                    # Build + Runtime (Coolify ready)
├── .env.example                  # Template de variáveis
├── DEPLOY_COOLIFY.md             # Este guia
├── server/
│   ├── db.ts                     # Pool PG com detecção SSL automática
│   ├── index.ts                  # Backend com 153+ rotas
│   └── services/
│       └── ia-imobiliaria.ts     # Serviço IA (Gemini + OpenAI)
└── db/migrations/
    └── 070_ia_imobiliaria_completo.sql  # Migrations IA
```

## Recursos Mínimos da VPS

| Recurso | Mínimo | Recomendado |
|---|---|---|
| CPU | 2 vCPUs | 4 vCPUs |
| RAM | 4 GB | 8 GB |
| SSD | 40 GB | 80 GB |
| OS | Ubuntu 24.04 | Ubuntu 24.04 |

Coolify suporta deployments multi-projeto. Se a Destrava já está rodando no mesmo Coolify, adicione o Casa DF como um **projeto separado** com seu próprio PostgreSQL interno.
