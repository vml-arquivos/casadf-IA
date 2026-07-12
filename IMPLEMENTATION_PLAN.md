# Plano de Implementação — Casa DF Gestão Imobiliária Inteligente

## Arquitetura Atual
- **Frontend**: React 18 + TypeScript + Vite + TailwindCSS 4 + Radix UI + shadcn/ui
- **Backend**: Node.js + Express (monolito em server/index.ts)
- **Banco**: PostgreSQL via pg.Pool (Supabase compatível)
- **IA**: Gemini 2.0 Flash (via @google/generative-ai) com fallback
- **Auth**: JWT custom
- **Uploads**: multer + filesystem
- **Roteamento**: wouter

## Módulos Existentes (PRESERVAR)
- Imóveis (CRUD, fotos, vitrine, filtros)
- Imobiliárias / Corretores
- Visitas
- Contratos Imobiliários
- Blog / Notícias
- CRM (leads, funil, pipeline, atividades, qualificações)
- Documentos
- IA Documental (recomendações, resumo, classificação, follow-up)
- Simulações
- Usuários / Colaboradores
- Área Administrativa
- Migrations

## Implementações Obrigatórias

### 1. Lead Score IA
- Endpoint: POST /api/ia/lead-score
- Tabela: lead_scores (id, lead_id, score, fatores, detalhes, criado_em)

### 2. Match Inteligente Imóvel x Cliente
- Endpoint: POST /api/ia/match-imovel
- Tabela: imovel_matches (id, lead_id, imovel_id, score_compatibilidade, razoes, criado_em)

### 3. Simulador Multi-Banco
- Endpoint: POST /api/simulador-multi-banco
- Tabela: simulacoes_multi_banco (id, lead_id, valor_imovel, entrada, prazo, comparacao_bancos, criado_em)
- Bancos: Caixa, Itaú, Santander, Bradesco, BB, BRB

### 4. Assistente Gemini Conversacional
- Endpoint: POST /api/ia/assistente
- Usa Gemini com contexto imobiliário

### 5. IA Jurídica
- Endpoint: POST /api/ia/analise-juridica
- Tabela: analises_juridicas (id, documento_id, imovel_id, riscos, pendencias, recomendacoes, necessidade_revisao, criado_em)

### 6. IA Financeira
- Endpoint: POST /api/ia/analise-financeira
- Tabela: analises_financeiras (id, lead_id, capacidade_compra, comprometimento, entrada_necessaria, prazo_ideal, risco_aprovacao, criado_em)

### 7. IA de Avaliação Imobiliária
- Endpoint: POST /api/ia/avaliacao-imovel
- Tabela: avaliacoes_imoveis (id, imovel_id, valor_estimado, fatores, imoveis_comparaveis, criado_em)

### 8. Central de IA (menu)
- Páginas frontend para todas as funcionalidades IA

## Migrations SQL
- 036_lead_score.sql
- 037_imovel_match.sql
- 038_simulacao_multi_banco.sql
- 039_analise_juridica.sql
- 040_analise_financeira.sql
- 041_avaliacao_imovel.sql
- 042_relatorios_inteligentes.sql

## Frontend — Novas Páginas
- /ia-central (Central de IA)
- /ia/lead-score
- /ia/match-imovel
- /ia/simulador-multi-banco
- /ia/assistente
- /ia/analise-juridica
- /ia/analise-financeira
- /ia/avaliacao-imovel
- /ia/relatorios

## Zero Regressão
- Não alterar APIs existentes
- Não remover módulos
- Manter compatibilidade total com Supabase
- SSL automático para banco externo
