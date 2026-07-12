# Casa DF — Gestão Imobiliária

> **Deploy revisado em 12/07/2026:** para uma nova instalação, use primeiro
> [`DEPLOY_CASA_DF_PASSO_A_PASSO.md`](DEPLOY_CASA_DF_PASSO_A_PASSO.md) e
> [`ANALISE_TECNICA_CASA_DF.md`](ANALISE_TECNICA_CASA_DF.md). Esses arquivos
> substituem instruções antigas de implantação que permanecem no histórico.

Este repositório contém a base para o sistema **Casa DF**, uma plataforma completa de gestão imobiliária, construída a partir da arquitetura do Destrava Crédito e adaptada para o mercado de imóveis.

## Principais recursos

- **Site vitrine responsivo** com navegação simplificada e páginas de listagem de imóveis (`/imoveis`), blog (`/blog`) e notícias (`/noticias`).
- **Captura de leads** via formulários e chatbots integrados.
- **CRM integrado** para gestão de contatos, clientes e oportunidades (herdado do Destrava).
- **Simulador de financiamento** adaptável para crédito imobiliário.
- **Gerador de contratos** ajustável para compra, venda ou locação de imóveis.
- **Dossiê documental** para gestão de documentos de imóveis, proprietários e transações.
- **Integração com IA nativa e externa (Gemini)** para extração de dados e geração de relatórios e análises.
- **Área do colaborador** com módulos para triagem de leads, acompanhamento bancário/financeiro, criação de contratos e muito mais.

## Como rodar

1. **Clone o repositório** e instale as dependências:

   ```bash
   pnpm install
   ```

2. **Configure o ambiente** copiando o arquivo `.env.example` para `.env` e ajustando as variáveis (URLs de serviços, chaves de API, e-mail etc.):

   ```bash
   cp .env.example .env
   # edite o arquivo .env conforme necessário
   ```

3. **Execute as migrations** (quando houver):

   ```bash
   pnpm run migrate:all
   ```

4. **Inicie o servidor de desenvolvimento**:

   ```bash
   pnpm run dev
   ```

   - O frontend estará acessível em `http://localhost:5173`.
   - O backend (API) rodará em `http://localhost:4000`.

## Estrutura do projeto

- `client/`: código do frontend em React/TypeScript, usando [Wouter](https://github.com/molefrog/wouter) para roteamento.
- `server/`: API Node/Express com serviços, rotas, controllers e integrações.
- `db/`: scripts e migrations do banco de dados (PostgreSQL).
- `assets/` e `client/public/`: arquivos estáticos, incluindo o logotipo (`casadf-logo.png`).

## Observações

- Este projeto é **uma base** para desenvolvimento de uma plataforma imobiliária. Diversas páginas e textos ainda fazem referência ao domínio de crédito e devem ser adaptados ou removidos conforme a necessidade.
- As páginas `Imóveis` e `Notícias` são **placeholders**. Você pode substituí-las por componentes conectados ao banco de dados ou CMS que listem imóveis reais e publiquem artigos/notícias.
- Para utilizar os recursos de IA, configure as variáveis `OPENAI_API_KEY`, `GEMINI_API_URL` e ajuste os prompts conforme as análises necessárias para o mercado imobiliário.

Sinta-se à vontade para personalizar o layout, criar novos módulos e ajustar a experiência conforme a identidade visual e as necessidades da **Casa DF**.

## Banco externo no Supabase

O projeto foi ajustado para usar PostgreSQL externo no Supabase via `DATABASE_URL` com SSL automático. Para produção, leia também `DEPLOY_SUPABASE.md`.

Resumo rápido:

```env
DATABASE_URL=postgresql://postgres.[PROJECT_REF]:SENHA@aws-0-REGIAO.pooler.supabase.com:5432/postgres
DATABASE_SSL=true
JWT_SECRET=gere-um-segredo-novo
VITE_APP_TITLE=Casa DF
```

Para banco novo/vazio, rode:

```bash
pnpm run migrate:all
```

## Supabase / banco externo

Para projeto Supabase novo e vazio, não crie tabelas manualmente. Use:

```bash
pnpm install
DATABASE_URL="postgresql://postgres.PROJECT_REF:SENHA@aws-0-REGIAO.pooler.supabase.com:5432/postgres" DATABASE_SSL=true pnpm run migrate:all
```

Também há um guia completo em `SUPABASE_SETUP_PRONTO.md` e um SQL consolidado em `supabase/init_casa_df_full.sql`.
