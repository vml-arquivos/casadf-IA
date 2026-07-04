-- ============================================================================
-- Migração 068 — Módulo Imobiliário Completo (Casa DF)
-- Cria: imoveis, imovel_fotos, imovel_visitas (fichas de visita) e
--       contratos_imobiliarios (compra e venda / prestação de serviço / cessão de direitos)
--
-- Padrão do projeto: idempotente, sem DELETE destrutivo, tudo em transação.
-- Rode com: psql "$DATABASE_URL" -f db/migrations/068_imoveis_crm_completo.sql
-- ============================================================================

BEGIN;

-- ── ENUM: finalidade e status do imóvel ─────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE imovel_tipo AS ENUM ('casa','apartamento','terreno','sala_comercial','loja','galpao','rural','cobertura','kitnet','sobrado','outro');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE imovel_finalidade AS ENUM ('venda','locacao','venda_locacao');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE imovel_status AS ENUM ('disponivel','reservado','vendido','locado','inativo');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE contrato_imobiliario_tipo AS ENUM ('compra_venda','prestacao_servico','cessao_direitos');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE contrato_imobiliario_status AS ENUM ('rascunho','gerado','assinado','cancelado');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Tabela: imoveis ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS imoveis (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo             VARCHAR(20) UNIQUE,               -- código curto exibido na vitrine (ex: CDF-0001)
  slug               VARCHAR(220) UNIQUE,               -- para URL amigável /imoveis/:slug
  titulo             VARCHAR(180) NOT NULL,
  descricao          TEXT,
  tipo               imovel_tipo NOT NULL DEFAULT 'apartamento',
  finalidade         imovel_finalidade NOT NULL DEFAULT 'venda',
  status             imovel_status NOT NULL DEFAULT 'disponivel',

  -- Valores
  valor_venda        NUMERIC(14,2),
  valor_locacao      NUMERIC(14,2),
  valor_condominio   NUMERIC(12,2),
  valor_iptu         NUMERIC(12,2),
  aceita_permuta     BOOLEAN NOT NULL DEFAULT FALSE,
  aceita_financiamento BOOLEAN NOT NULL DEFAULT TRUE,

  -- Localização
  endereco           VARCHAR(220),
  numero             VARCHAR(20),
  complemento        VARCHAR(120),
  bairro             VARCHAR(120),
  cidade             VARCHAR(120) DEFAULT 'Brasília',
  uf                 VARCHAR(2) DEFAULT 'DF',
  cep                VARCHAR(9),
  latitude           NUMERIC(10,7),
  longitude          NUMERIC(10,7),

  -- Características
  area_privativa     NUMERIC(10,2),
  area_total         NUMERIC(10,2),
  quartos            SMALLINT DEFAULT 0,
  suites             SMALLINT DEFAULT 0,
  banheiros          SMALLINT DEFAULT 0,
  vagas_garagem      SMALLINT DEFAULT 0,
  andar              VARCHAR(20),
  ano_construcao     SMALLINT,
  mobiliado          BOOLEAN NOT NULL DEFAULT FALSE,
  comodidades        JSONB DEFAULT '[]'::jsonb,        -- ["piscina","academia","churrasqueira",...]

  -- Proprietário / captação (uso interno do CRM)
  proprietario_nome  VARCHAR(160),
  proprietario_telefone VARCHAR(30),
  proprietario_email VARCHAR(160),
  proprietario_cpf_cnpj VARCHAR(20),
  matricula_imovel   VARCHAR(60),
  observacoes_internas TEXT,

  -- Vitrine / SEO
  destaque           BOOLEAN NOT NULL DEFAULT FALSE,
  foto_capa_url      VARCHAR(400),
  meta_titulo        VARCHAR(180),
  meta_descricao     VARCHAR(300),

  -- Metadados
  responsavel_id     UUID,                              -- colaborador responsável (captador/corretor)
  criado_por         UUID,
  visualizacoes       INTEGER NOT NULL DEFAULT 0,
  criado_em          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_imoveis_status       ON imoveis(status);
CREATE INDEX IF NOT EXISTS idx_imoveis_finalidade   ON imoveis(finalidade);
CREATE INDEX IF NOT EXISTS idx_imoveis_tipo         ON imoveis(tipo);
CREATE INDEX IF NOT EXISTS idx_imoveis_bairro       ON imoveis(bairro);
CREATE INDEX IF NOT EXISTS idx_imoveis_cidade       ON imoveis(cidade);
CREATE INDEX IF NOT EXISTS idx_imoveis_destaque     ON imoveis(destaque) WHERE destaque = TRUE;
CREATE INDEX IF NOT EXISTS idx_imoveis_responsavel   ON imoveis(responsavel_id);

-- Sequência amigável para o código do imóvel (CDF-0001, CDF-0002, ...)
CREATE SEQUENCE IF NOT EXISTS imoveis_codigo_seq START 1;

-- ── Tabela: imovel_fotos ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS imovel_fotos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  imovel_id    UUID NOT NULL REFERENCES imoveis(id) ON DELETE CASCADE,
  url          VARCHAR(400) NOT NULL,
  legenda      VARCHAR(160),
  ordem        INTEGER NOT NULL DEFAULT 0,
  capa         BOOLEAN NOT NULL DEFAULT FALSE,
  criado_em    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_imovel_fotos_imovel ON imovel_fotos(imovel_id, ordem);

-- ── Tabela: imovel_visitas (ficha de visita / agendamento) ──────────────────
CREATE TABLE IF NOT EXISTS imovel_visitas (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  imovel_id          UUID NOT NULL REFERENCES imoveis(id) ON DELETE CASCADE,

  visitante_nome     VARCHAR(160) NOT NULL,
  visitante_telefone VARCHAR(30),
  visitante_email    VARCHAR(160),
  visitante_cpf      VARCHAR(20),

  corretor_id        UUID,                              -- colaborador que acompanhou
  corretor_nome      VARCHAR(160),

  data_visita        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  origem_lead        VARCHAR(60),                        -- site, whatsapp, indicação, portal...
  interesse_nivel     VARCHAR(20) DEFAULT 'medio',        -- baixo, medio, alto
  observacoes        TEXT,
  feedback_visitante TEXT,
  proximos_passos    TEXT,
  status             VARCHAR(20) NOT NULL DEFAULT 'agendada', -- agendada, realizada, cancelada, nao_compareceu

  assinatura_visitante_nome VARCHAR(160),
  assinatura_corretor_nome  VARCHAR(160),

  pdf_url            VARCHAR(400),
  criado_por         UUID,
  criado_em          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_imovel_visitas_imovel ON imovel_visitas(imovel_id);
CREATE INDEX IF NOT EXISTS idx_imovel_visitas_data   ON imovel_visitas(data_visita);
CREATE INDEX IF NOT EXISTS idx_imovel_visitas_status ON imovel_visitas(status);

-- ── Tabela: contratos_imobiliarios ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS contratos_imobiliarios (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero            VARCHAR(30) UNIQUE,
  tipo              contrato_imobiliario_tipo NOT NULL,
  status            contrato_imobiliario_status NOT NULL DEFAULT 'rascunho',

  imovel_id         UUID REFERENCES imoveis(id) ON DELETE SET NULL,

  -- Parte 1 (proprietário / cedente / contratante)
  parte1_nome       VARCHAR(160) NOT NULL,
  parte1_cpf_cnpj   VARCHAR(20),
  parte1_endereco   VARCHAR(220),
  parte1_email      VARCHAR(160),
  parte1_telefone   VARCHAR(30),
  parte1_estado_civil VARCHAR(40),

  -- Parte 2 (comprador / cessionário / contratado)
  parte2_nome       VARCHAR(160) NOT NULL,
  parte2_cpf_cnpj   VARCHAR(20),
  parte2_endereco   VARCHAR(220),
  parte2_email      VARCHAR(160),
  parte2_telefone   VARCHAR(30),
  parte2_estado_civil VARCHAR(40),

  -- Condições financeiras
  valor_total       NUMERIC(14,2),
  valor_entrada     NUMERIC(14,2),
  forma_pagamento   VARCHAR(60),
  numero_parcelas   SMALLINT,
  valor_parcela     NUMERIC(14,2),
  vencimento_dia    SMALLINT,
  percentual_comissao NUMERIC(5,2),

  -- Objeto do contrato (cessão de direitos / prestação de serviço)
  objeto_descricao  TEXT,
  clausulas_extra   TEXT,

  data_assinatura   DATE,
  cidade_foro       VARCHAR(120) DEFAULT 'Brasília',

  testemunha_1_nome VARCHAR(160),
  testemunha_1_cpf  VARCHAR(20),
  testemunha_2_nome VARCHAR(160),
  testemunha_2_cpf  VARCHAR(20),

  pdf_url           VARCHAR(400),
  criado_por        UUID,
  criado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contratos_imob_tipo    ON contratos_imobiliarios(tipo);
CREATE INDEX IF NOT EXISTS idx_contratos_imob_status  ON contratos_imobiliarios(status);
CREATE INDEX IF NOT EXISTS idx_contratos_imob_imovel  ON contratos_imobiliarios(imovel_id);

CREATE SEQUENCE IF NOT EXISTS contratos_imobiliarios_numero_seq START 1;

COMMIT;

-- ============================================================================
-- Verificação pós-migração (SELECT apenas — sem efeitos colaterais)
-- ============================================================================
-- SELECT table_name FROM information_schema.tables
--   WHERE table_name IN ('imoveis','imovel_fotos','imovel_visitas','contratos_imobiliarios');
