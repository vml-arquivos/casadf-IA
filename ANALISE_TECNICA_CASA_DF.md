# Análise técnica do sistema Casa DF

Data da revisão: 12/07/2026

## Resultado executivo

O projeto foi ajustado para compilar e ser implantado pelo Dockerfile no Coolify. O núcleo da aplicação depende somente de duas variáveis obrigatórias em runtime: `DATABASE_URL` e `JWT_SECRET`. O pacote já inclui um `JWT_SECRET` temporário e três segredos temporários de integração; portanto, o único valor que precisa ser inserido manualmente no primeiro deploy é a `DATABASE_URL`.

As chaves emitidas por serviços externos — Gemini, OpenAI, Chatwoot, n8n, CPF.CNPJ e CPFHub — não podem ser fabricadas pelo sistema. Elas ficaram vazias e os respectivos recursos permanecem opcionais/desabilitados até a contratação ou criação das chaves reais.

## Arquitetura identificada

| Camada | Tecnologia | Observação |
|---|---|---|
| Frontend | React 18, Vite 7, TypeScript, Tailwind | SPA servida pelo próprio backend em produção |
| Backend | Node.js 20, Express 4, TypeScript/esbuild | Monólito com 173 rotas declaradas no arquivo principal |
| Banco | PostgreSQL | Pool `pg`, autenticação própria e 76 arquivos de migration SQL; uma variante legada é substituída automaticamente pela versão `SAFE` |
| Autenticação | JWT + bcrypt | Token de 24 horas; usuários na tabela `colaboradores` |
| Arquivos | Volume local persistente | Caminho padronizado em `/var/data/casadf` |
| PDFs | Puppeteer Core + Chromium | Chromium instalado na imagem Docker |
| IA | Gemini com fallback OpenAI | Opcional; modelos agora configuráveis por ambiente |
| Integrações | Chatwoot, n8n, OpenCNPJ, CPF.CNPJ, CPFHub, Nexus | Opcionais e isoladas por variáveis |

## Bloqueios encontrados e corrigidos

1. O Dockerfile copiava `.npmrc`, mas o arquivo não existia; o build Docker pararia no primeiro `COPY`.
2. `server/index.ts` usava a variável inexistente `pkg`; o backend não compilava.
3. O TypeScript tinha 16 erros em contratos, orçamentos, Central de IA e serviços de IA.
4. `server/services/gemini.ts` importava `node-fetch`, dependência ausente e desnecessária no Node 20.
5. O build local não copiava as logos lidas em runtime pelos geradores de PDF.
6. O container final não continha a pasta `db`; a migração inicial não poderia ser executada dentro dele.
7. PDFs e uploads eram gravados em vários caminhos não persistentes, inclusive caminhos herdados da Destrava.
8. A rota pública do assistente usava a string `public` como UUID e falharia no PostgreSQL.
9. O health check retornava HTTP 200 mesmo sem conexão com o banco; agora retorna HTTP 503 quando o banco falha.
10. A rota de SQL administrativo permitia SQL arbitrário; agora começa desabilitada e só abre com `ENABLE_ADMIN_SQL=true`.
11. Não havia validação clara de `DATABASE_URL` e `JWT_SECRET`; o backend agora falha rapidamente com mensagem objetiva.
12. Não existiam `.gitignore` e `.dockerignore`, criando risco de enviar segredos, dependências e uploads ao repositório/imagem.
13. O executor aplicava a migration 046 legada e depois sua substituta `SAFE`; agora ignora automaticamente a versão legada quando há uma variante `*_SAFE.sql`.

## Variáveis

### Obrigatórias

| Variável | Situação |
|---|---|
| `DATABASE_URL` | Único valor pendente; deve apontar para um PostgreSQL novo e exclusivo do Casa DF |
| `JWT_SECRET` | Gerado temporariamente em `.env.coolify` |

### Geradas temporariamente

- `JWT_SECRET`
- `INTEGRATION_SECRET`
- `NEXUS_INTEGRATION_SECRET`
- `NEXUS_DESTRAVA_INTEGRATION_SECRET`

Esses valores são válidos para homologação. Após a validação do sistema, gere novos valores com `openssl rand -hex 32`, substitua no Coolify e faça novo deploy. A troca de `JWT_SECRET` encerra todas as sessões existentes.

### Opcionais desabilitadas

- IA: `GEMINI_API_KEY`, `OPENAI_API_KEY`
- Atendimento: `CHATWOOT_URL`, `CHATWOOT_ACCOUNT_ID`, `CHATWOOT_API_TOKEN`, `CHATWOOT_WEBHOOK_SECRET`
- Automação: `N8N_WEBHOOK_URL`
- Dados pagos: `CPFCNPJ_TOKEN`/`CPFCNPJ_API_KEY`, `CPFHUB_API_KEY`
- Mapa: `VITE_FRONTEND_FORGE_API_KEY`, `VITE_FRONTEND_FORGE_API_URL`

## Validações executadas

| Validação | Resultado |
|---|---|
| Instalação pelo lockfile `pnpm@10.4.1` | Aprovada |
| `tsc --noEmit` | Aprovada, zero erros |
| Vitest | Aprovada, 26/26 testes |
| Vite produção | Aprovada, 3.307 módulos transformados |
| esbuild backend | Aprovada, `dist/index.js` gerado |
| Sintaxe do bundle Node | Aprovada com `node --check` |
| Assets de PDF em `dist/assets` | Aprovada |
| Validador de ambiente (caso válido e inválido) | Aprovado |
| Execução das migrations em banco real | Pendente da `DATABASE_URL` |
| Build da imagem Docker | Não executado neste ambiente por ausência de daemon Docker; Dockerfile revisado estaticamente |

## Pontos que não impedem o deploy, mas merecem próxima rodada

1. O bundle principal do frontend tem cerca de 2,85 MB (aprox. 728 KB gzip). Recomenda-se lazy loading das páginas para reduzir o primeiro carregamento.
2. A suíte automatizada cobre principalmente os endpoints de IA. Faltam testes de autenticação, migrations, uploads, PDFs e jornadas do CRM.
3. Existem muitos módulos e textos herdados da Destrava. Parte é funcionalmente necessária para contratos e crédito; uma rodada separada deve decidir o que será removido ou renomeado no Casa DF.
4. Antes de exposição pública em alto volume, adicionar rate limiting a login, captação de leads e assistente público.
5. O token JWT é armazenado no navegador. Uma evolução de segurança seria migrar para cookie `HttpOnly`, `Secure` e `SameSite`.
6. O backend ainda contém correções DDL idempotentes na inicialização. Depois que o banco estiver estabilizado, convém migrar toda alteração de schema exclusivamente por migrations versionadas.

## Condição para considerar a produção homologada

O código e o build estão aprovados. A homologação final depende de: criar o PostgreSQL, inserir a `DATABASE_URL`, executar as migrations, criar o primeiro administrador e concluir os testes de login, cadastro, upload e geração de PDF descritos no guia de deploy.
