# Deploy Casa DF com PostgreSQL externo no Supabase

Este projeto usa `pg.Pool` no backend Node. Para banco externo no Supabase, use a string de conexão PostgreSQL do Supabase e mantenha SSL ativo.

## 1. Criar banco no Supabase

1. Crie um novo projeto Supabase exclusivo para o Casa DF.
2. Copie a connection string em **Project Settings → Database → Connection string**.
3. Use preferencialmente a conexão em modo **Session / porta 5432**. Evite o transaction pooler para este app, porque o backend já usa `pg.Pool`.

Exemplo:

```env
DATABASE_URL=postgresql://postgres.[PROJECT_REF]:SENHA@aws-0-REGIAO.pooler.supabase.com:5432/postgres
DATABASE_SSL=true
```

## 2. Variáveis obrigatórias no Coolify

Configure no serviço do Casa DF:

```env
NODE_ENV=production
PORT=4000
DATABASE_URL=postgresql://postgres.[PROJECT_REF]:SENHA@aws-0-REGIAO.pooler.supabase.com:5432/postgres
DATABASE_SSL=true
JWT_SECRET=gere-um-segredo-novo-com-openssl-rand-hex-32
SITE_DOMAIN=casadf.com.br
FRONTEND_URL=https://casadf.com.br
VITE_APP_TITLE=Casa DF
```

Para IA e automações:

```env
GEMINI_API_KEY=...
GEMINI_API_URL=...
N8N_WEBHOOK_URL=...
CHATWOOT_URL=...
CHATWOOT_ACCOUNT_ID=...
CHATWOOT_API_TOKEN=...
```

## 3. Variáveis de build do Vite

No Coolify, as variáveis `VITE_*` precisam estar disponíveis durante o build, não somente no runtime.

```env
VITE_APP_TITLE=Casa DF
VITE_APP_ID=...
VITE_OAUTH_PORTAL_URL=...
VITE_FRONTEND_FORGE_API_KEY=...
VITE_FRONTEND_FORGE_API_URL=...
```

## 4. Rodar migrations

Para banco novo/vazio:

```bash
pnpm run migrate:all
```

Ou diretamente:

```bash
DATABASE_URL="postgresql://..." DATABASE_SSL=true node scripts/migrate-all.mjs
```

O script roda `db/migrate.sql` e depois todas as migrations numeradas em `db/migrations/*.sql`, incluindo:

- `068_imoveis_crm_completo.sql`
- `069_contratos_avancados_imobiliarias.sql`

## 5. Criar usuário inicial

Depois de migrar:

```bash
NOME="Administrador Casa DF" EMAIL="admin@casadf.com.br" SENHA="Senha@123" CARGO="Administrador" node scripts/create-user.mjs
```

## 6. Volumes persistentes

Mapeie um volume persistente no Coolify para:

```text
/var/data/casadf
```

Esse diretório guarda fotos de imóveis, logos, uploads e PDFs. Sem volume persistente, arquivos podem sumir em redeploy.

## 7. Checklist antes de deploy

- [ ] Banco Supabase criado e vazio.
- [ ] `DATABASE_URL` configurada com SSL.
- [ ] `DATABASE_SSL=true` configurado.
- [ ] `JWT_SECRET` novo, não reutilizado da Destrava.
- [ ] `VITE_*` configuradas como variáveis de build.
- [ ] Volume persistente em `/var/data/casadf`.
- [ ] `pnpm run migrate:all` executado com sucesso.
- [ ] Usuário administrador criado.
- [ ] Páginas públicas `/`, `/imoveis`, `/blog`, `/noticias`, `/contato` testadas.
- [ ] Área interna `/colaborador/login` testada.
