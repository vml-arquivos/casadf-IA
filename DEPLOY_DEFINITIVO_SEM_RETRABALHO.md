# Casa DF — deploy definitivo sem retrabalho

## Decisão imediata

Não faça redeploy do commit `7c74b0c2f97402ca58edb23ff106ff3590a43afc`.
Ele não contém o conjunto completo das correções e o Dockerfile nele ainda instala
o Chromium do Debian durante o build. Substitua o conteúdo da raiz do repositório
pelo conteúdo integral do pacote definitivo e só então faça um novo deploy.

## 1. Publicar o pacote completo no GitHub

1. Extraia o pacote definitivo.
2. Copie **todos** os arquivos extraídos para a raiz do repositório
   `vml-arquivos/casadf-IA`, substituindo os existentes.
3. Inclua os arquivos ocultos `.npmrc`, `.dockerignore` e `.gitignore`.
4. Não envie `.env.coolify`, `node_modules/` nem `dist/`.
5. Faça um único commit na branch `main` com o resumo de `COMMIT_SUMMARY.md`.
6. No GitHub, confirme que a raiz contém, no mínimo:
   `Dockerfile`, `docker-entrypoint.sh`, `.npmrc`, `package.json`,
   `pnpm-lock.yaml`, `client/`, `server/`, `shared/`, `scripts/` e `db/`.

## 2. Configuração exata da aplicação no Coolify

| Campo | Valor |
|---|---|
| Build Pack | `Dockerfile` |
| Base Directory | `/` |
| Dockerfile Location | `/Dockerfile` |
| Port Exposes | `4000` |
| Health Check Path | `/api/health` |
| Start Command | deixar vazio |

## 3. Storage exato

Use **Volume**, não Bind Mount:

| Campo | Valor |
|---|---|
| Type | `Volume` |
| Name | `casadf-data` |
| Source | não se aplica; deixe vazio se aparecer |
| Destination Path / Mount Path | `/var/data/casadf` |

O Coolify acrescenta um identificador ao nome real do volume. Isso é normal.
Não monte somente `/var/data/casadf/uploads`: o volume deve cobrir o diretório
pai completo informado acima.

## 4. Ajustes finais nas variáveis já cadastradas

1. Mantenha a `DATABASE_URL` já preenchida.
2. `JWT_SECRET` deve ter pelo menos 32 caracteres.
3. Apague `CHROMIUM_PATH` do Coolify ou salve seu valor vazio. Não use
   `/usr/bin/chromium`.
4. No primeiro deploy, use `RUN_MIGRATIONS_ON_START=true`.
5. Para banco interno no Coolify, use `DATABASE_SSL=false`.
6. Marque como **Build Variable** somente as variáveis `VITE_*` que tiverem
   valor. Não marque tokens, JWT, senha ou `DATABASE_URL` como Build Variable.
7. Deixe `ENABLE_ADMIN_SQL=false`.

## 5. Fazer o primeiro deploy

1. Salve as configurações.
2. Use **Redeploy → Rebuild without cache** somente depois que o novo commit
   completo estiver na `main`.
3. O log de inicialização esperado é:

```text
✅ Variáveis obrigatórias válidas.
[casadf] Executando migrações antes de iniciar...
🎉 Migração completa concluída com sucesso!
Servidor rodando em http://0.0.0.0:4000
```

4. Teste `https://SEU-DOMINIO/api/health`. O banco precisa aparecer conectado.
5. Depois do primeiro deploy aprovado, altere
   `RUN_MIGRATIONS_ON_START=false`, salve e faça um redeploy normal.

## 6. Criar o administrador

No terminal do container, execute:

```bash
node scripts/create-user.mjs
```

Não configure `NOME`, `EMAIL`, `SENHA` e `CARGO` como variáveis permanentes da
aplicação. Use-as apenas durante a criação do usuário, caso prefira o modo não
interativo descrito no guia completo.

## Validação já executada no pacote

- TypeScript: aprovado sem erros.
- Testes automatizados: 26 de 26 aprovados.
- Build Vite + servidor: aprovado.
- Assets de runtime: copiados para `dist/assets` durante o build.
- Runtime do Docker: migrações, banco, uploads persistentes e Chromium leve
  incluídos.

