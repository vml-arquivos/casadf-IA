# Casa DF — Setup Supabase pronto

Este projeto está preparado para usar **PostgreSQL externo no Supabase**. Como o projeto Supabase já foi criado, você **não precisa criar tabelas e colunas manualmente**. As tabelas serão criadas pelas migrations do repositório.

## Caminho recomendado: rodar migrations pelo projeto

1. Entre na pasta do projeto:

```bash
cd casa-df-system
```

2. Instale dependências:

```bash
pnpm install
```

3. Configure a conexão do Supabase no terminal:

```bash
export DATABASE_URL="postgresql://postgres.PROJECT_REF:SENHA@aws-0-REGIAO.pooler.supabase.com:5432/postgres"
export DATABASE_SSL="true"
```

No Windows PowerShell:

```powershell
$env:DATABASE_URL="postgresql://postgres.PROJECT_REF:SENHA@aws-0-REGIAO.pooler.supabase.com:5432/postgres"
$env:DATABASE_SSL="true"
```

4. Rode a criação completa do banco:

```bash
pnpm run migrate:all
```

Esse comando roda `db/migrate.sql` e depois todas as migrations em `db/migrations` na ordem correta.

5. Crie o primeiro administrador:

```bash
NOME="Administrador Casa DF" EMAIL="admin@casadf.com.br" SENHA="Senha@123" CARGO="Administrador" pnpm run create-user
```

No Windows PowerShell:

```powershell
$env:NOME="Administrador Casa DF"
$env:EMAIL="admin@casadf.com.br"
$env:SENHA="Senha@123"
$env:CARGO="Administrador"
pnpm run create-user
```

## Alternativa: SQL Editor do Supabase

Existe um SQL consolidado em:

```text
supabase/init_casa_df_full.sql
```

Você pode abrir esse arquivo, copiar o conteúdo e colar no **SQL Editor** do Supabase. Porém, para produção, o método recomendado é `pnpm run migrate:all`, porque ele mostra exatamente qual migration falhou, caso o Supabase interrompa por timeout ou limite do editor.

## Variáveis necessárias no deploy

Configure no Coolify/servidor:

```env
DATABASE_URL=postgresql://postgres.PROJECT_REF:SENHA@aws-0-REGIAO.pooler.supabase.com:5432/postgres
DATABASE_SSL=true
JWT_SECRET=gere-um-segredo-forte
NODE_ENV=production
PORT=4000
SITE_DOMAIN=casadf.com.br
FRONTEND_URL=https://casadf.com.br
VITE_APP_TITLE=Casa DF
VITE_APP_NAME=Casa DF
DATA_DIR=/var/data/casadf
```

Também configure as chaves opcionais conforme uso:

```env
OPENAI_API_KEY=
GEMINI_API_KEY=
GEMINI_API_URL=
N8N_WEBHOOK_URL=
CHATWOOT_URL=
CHATWOOT_API_TOKEN=
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
```

## Volume persistente obrigatório

Crie no Coolify um volume para:

```text
/var/data/casadf
```

Sem volume, uploads de fotos de imóveis, documentos, PDFs e logos podem desaparecer após redeploy.

## Checklist rápido

- [ ] Supabase criado.
- [ ] DATABASE_URL copiada do Supabase usando modo pooler/session ou connection string compatível.
- [ ] DATABASE_SSL=true configurado.
- [ ] `pnpm run migrate:all` executado com sucesso.
- [ ] Usuário admin criado.
- [ ] Variáveis de deploy configuradas.
- [ ] Volume persistente configurado.
- [ ] Build executado.
- [ ] Primeiro login testado.
