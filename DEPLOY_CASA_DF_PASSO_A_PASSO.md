# Deploy do Casa DF no Coolify — passo a passo

Este é o fluxo recomendado para um banco PostgreSQL novo e exclusivo do Casa DF. Não use o mesmo banco da Destrava.

## 1. Preparar o código

1. Descompacte o pacote ajustado.
2. Envie a pasta para um repositório Git privado.
3. Confirme que `.env.coolify` não entrou no commit. Ele é ignorado pelo `.gitignore` e serve apenas para você copiar os valores.
4. Mantenha `Dockerfile`, `docker-entrypoint.sh`, `db/`, `scripts/`, `client/`, `server/`, `shared/`, `package.json` e `pnpm-lock.yaml` no repositório.

Antes de enviar, a validação local pode ser repetida com:

```bash
corepack enable
corepack prepare pnpm@10.4.1 --activate
pnpm install --frozen-lockfile
pnpm run preflight
```

## 2. Criar o projeto no Coolify

1. Entre no Coolify.
2. Clique em **Projects** → **Add**.
3. Nomeie o projeto como `Casa DF`.
4. Dentro do projeto, use o ambiente `Production`.

## 3. Criar o PostgreSQL

1. Em `Casa DF / Production`, clique em **New Resource**.
2. Selecione **Database** → **PostgreSQL**.
3. Use um nome como `casadf-postgres`.
4. PostgreSQL 16 ou 17 é adequado.
5. Gere uma senha forte e salve.
6. Inicie o banco.
7. Abra a página do banco e copie a **Internal Database URL/Connection String**. Ela deve ter o formato:

```text
postgresql://usuario:senha@hostname-interno:5432/banco
```

Essa é a `DATABASE_URL` que falta. Para banco interno no mesmo projeto, use `DATABASE_SSL=false`.

## 4. Criar a aplicação

1. No mesmo ambiente, clique em **New Resource** → **Application**.
2. Conecte o repositório privado do Casa DF.
3. Selecione a branch de produção, normalmente `main`.
4. Em **Build Pack**, escolha **Dockerfile**.
5. Dockerfile location: `/Dockerfile`.
6. Porta da aplicação: `4000`.
7. Health check path: `/api/health`.
8. Não altere o comando de start; o Dockerfile já usa o entrypoint correto.

## 5. Criar o volume persistente

Faça isso antes do primeiro uso do sistema:

1. Abra **Storages/Persistent Storage** da aplicação.
2. Adicione um volume persistente.
3. Mount path dentro do container: `/var/data/casadf`.
4. Salve.

Sem esse volume, fotos, documentos e PDFs serão apagados ao recriar o container.

## 6. Configurar as variáveis

1. Abra o arquivo `.env.coolify` do pacote.
2. Copie todas as linhas `NOME=valor` para **Environment Variables** da aplicação.
3. Substitua somente:

```text
DATABASE_URL=COLE_AQUI_A_DATABASE_URL
```

pela URL interna copiada no passo 3.

No primeiro deploy, mantenha:

```text
RUN_MIGRATIONS_ON_START=true
```

Isso faz o container validar a configuração e preparar o banco antes de abrir o servidor. Se qualquer migration falhar, o container para e mostra exatamente o arquivo responsável.

As variáveis `VITE_*` são lidas durante o build. No Coolify, marque como **Build Variable** qualquer `VITE_*` que receber valor real. `VITE_APP_TITLE` já tem fallback Casa DF; as demais podem ficar vazias.

Nunca coloque segredo real em variável iniciada por `VITE_`: esse conteúdo é incorporado ao JavaScript público do navegador.

## 7. Primeiro deploy e migrations

1. Clique em **Deploy**.
2. Acompanhe os logs.
3. O fluxo esperado é:

```text
✅ Variáveis obrigatórias válidas.
[casadf] Executando migrações antes de iniciar...
🎉 Migração completa concluída com sucesso!
Servidor rodando em http://0.0.0.0:4000
```

4. Após o primeiro deploy aprovado, altere:

```text
RUN_MIGRATIONS_ON_START=false
```

5. Salve e faça um novo deploy. As migrations continuarão disponíveis para execução manual no terminal do container:

```bash
node scripts/migrate-all.mjs
```

Para um banco já parcialmente migrado, use somente após análise:

```bash
node scripts/migrate-all.mjs --skip-base
```

## 8. Criar o primeiro administrador

Abra o terminal do container da aplicação e execute:

```bash
node scripts/create-user.mjs
```

Informe quando solicitado:

- Nome: `Fernando Eli Oliveira Marques`
- E-mail: o e-mail que será usado no login
- Senha: uma senha forte
- Cargo: `Administrador`

Alternativa não interativa:

```bash
NOME="Fernando Eli Oliveira Marques" EMAIL="seu-email@dominio.com" SENHA="SENHA_FORTE" CARGO="Administrador" node scripts/create-user.mjs
```

## 9. Configurar domínio e SSL

1. Na aplicação, abra **Domains**.
2. Cadastre `https://casadf.com.br` ou o domínio real escolhido.
3. No provedor DNS, crie um registro `A` apontando o domínio para o IP público da VPS.
4. Se usar `www`, crie `CNAME www` apontando para o domínio principal e adicione esse domínio no Coolify.
5. Aguarde a propagação e confirme que o Coolify emitiu o SSL.
6. Se o domínio for diferente, atualize `SITE_DOMAIN`, `FRONTEND_URL` e os metadados fixos de `client/index.html`.

## 10. Testes obrigatórios de homologação

### Saúde

Abra:

```text
https://SEU-DOMINIO/api/health
```

Resultado esperado:

```json
{
  "status": "ok",
  "db": "connected"
}
```

O endpoint retorna HTTP 503 se o banco estiver desconectado.

### Jornada interna

1. Acesse `/colaborador/login`.
2. Entre com o administrador criado.
3. Cadastre um usuário de teste.
4. Cadastre um lead e mova-o no funil.
5. Cadastre uma empresa e um cliente PF.
6. Cadastre um imóvel com foto.
7. Faça upload de um documento.
8. Gere um orçamento e baixe o PDF.
9. Gere um contrato e baixe o PDF.
10. Reinicie/reimplante o container e confirme que fotos e PDFs continuam acessíveis.

### Banco

No terminal do container:

```bash
node scripts/db-inspect.mjs
```

Confira também os logs do health check e a ausência de erros de tabela/coluna.

## 11. Ativar recursos opcionais

O sistema principal funciona sem estas integrações. Ative uma por vez e teste:

- Gemini: preencher `GEMINI_API_KEY` e definir `GEMINI_DOCUMENT_OCR_ENABLED=true`.
- OpenAI fallback: preencher `OPENAI_API_KEY`; `OPENAI_API_BASE` deve ficar vazio para o endpoint oficial.
- Chatwoot: preencher URL, account ID, API token e webhook secret.
- n8n: preencher `N8N_WEBHOOK_URL`.
- CPF.CNPJ: preencher token/API key, URL se necessária e mudar `CPFCNPJ_ENABLED=true`.
- CPFHub: preencher `CPFHUB_API_KEY`.
- Mapa: preencher as variáveis `VITE_FRONTEND_FORGE_*` como build variables e reconstruir a aplicação.

## 12. Trocar todos os segredos temporários

Depois da homologação, gere quatro novos valores, um por comando:

```bash
openssl rand -hex 32
```

Substitua `JWT_SECRET`, `INTEGRATION_SECRET`, `NEXUS_INTEGRATION_SECRET` e `NEXUS_DESTRAVA_INTEGRATION_SECRET` no Coolify. Depois faça novo deploy.

## 13. Backup mínimo recomendado

1. Ative backup diário do PostgreSQL e retenção de pelo menos 7 dias.
2. Faça backup diário do volume `/var/data/casadf`.
3. Antes de novas migrations, crie um backup manual do banco.
4. Guarde os segredos fora do repositório.

## Diagnóstico rápido

| Sintoma | Verificação |
|---|---|
| Container reinicia | Veja o início do log; a validação informa variável ausente ou migration que falhou |
| Health check 503 | Teste a `DATABASE_URL`, hostname interno e `DATABASE_SSL` |
| Login 500 | Confirme migrations e usuário na tabela `colaboradores` |
| Fotos/PDFs somem | Confirme o volume em `/var/data/casadf` |
| PDF não gera | Confirme `CHROMIUM_PATH=/usr/bin/chromium` e logs do Puppeteer |
| IA indisponível | Configure Gemini ou OpenAI; o restante do sistema continua operacional |
| Mapa não aparece | Configure as variáveis `VITE_*` como build variables e faça novo build |
| CORS bloqueado | Confirme `SITE_DOMAIN` sem protocolo e `FRONTEND_URL` com `https://` |
