-- ============================================================================
-- Migração 070 — IA Imobiliária Completa (Casa DF)
-- Cria: lead_scores, imovel_matches, simulacoes_multi_banco,
--       analises_juridicas, analises_financeiras, avaliacoes_imoveis,
--       assistente_sessions, assistente_messages, relatorios_inteligentes
--
-- Padrão: idempotente, sem DELETE destrutivo, tudo em transação.
-- ============================================================================


-- ── ENUMS ─────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE lead_score_classificacao AS ENUM ('frio','morno','quente','urgente','vip');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE match_compatibilidade AS ENUM ('baixa','media','alta','excelente');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE risco_aprovacao AS ENUM ('baixo','medio','alto','muito_alto');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE banco_simulacao AS ENUM ('caixa','itau','santander','bradesco','banco_brasil','brb');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Tabela: lead_scores ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lead_scores (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id               UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  colaborador_id        UUID,
  score                 NUMERIC(5,2) NOT NULL DEFAULT 0,          -- 0 a 100
  classificacao         lead_score_classificacao NOT NULL DEFAULT 'morno',
  fatores               JSONB DEFAULT '{}'::jsonb,               -- {renda: 0.2, bairro: 0.15, ...}
  detalhes              JSONB DEFAULT '{}'::jsonb,               -- {renda_anual: 120000, urgencia: "alta", ...}
  observacoes_ia        TEXT,
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lead_scores_lead ON lead_scores(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_scores_score ON lead_scores(score DESC);
CREATE INDEX IF NOT EXISTS idx_lead_scores_classificacao ON lead_scores(classificacao);

-- ── Tabela: imovel_matches ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS imovel_matches (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id               UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  imovel_id             UUID NOT NULL REFERENCES imoveis(id) ON DELETE CASCADE,
  score_compatibilidade NUMERIC(5,2) NOT NULL DEFAULT 0,         -- 0 a 100
  razoes                JSONB DEFAULT '[]'::jsonb,              -- array de strings com justificativas
  fatores_match         JSONB DEFAULT '{}'::jsonb,              -- {preco: 0.3, localizacao: 0.25, ...}
  posicao_ranking       INTEGER DEFAULT 1,
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_imovel_matches_lead ON imovel_matches(lead_id);
CREATE INDEX IF NOT EXISTS idx_imovel_matches_imovel ON imovel_matches(imovel_id);
CREATE INDEX IF NOT EXISTS idx_imovel_matches_score ON imovel_matches(score_compatibilidade DESC);

-- ── Tabela: simulacoes_multi_banco ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS simulacoes_multi_banco (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id               UUID REFERENCES leads(id) ON DELETE SET NULL,
  imovel_id             UUID REFERENCES imoveis(id) ON DELETE SET NULL,
  colaborador_id        UUID,

  valor_imovel          NUMERIC(14,2) NOT NULL,
  valor_entrada         NUMERIC(14,2) NOT NULL DEFAULT 0,
  prazo_meses           INTEGER NOT NULL,
  taxa_fixa             BOOLEAN NOT NULL DEFAULT FALSE,

  resultado_caixa       JSONB,
  resultado_itau        JSONB,
  resultado_santander   JSONB,
  resultado_bradesco    JSONB,
  resultado_banco_brasil JSONB,
  resultado_brb         JSONB,

  recomendacao          TEXT,
  comparacao_resumo     JSONB,

  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_simulacoes_mb_lead ON simulacoes_multi_banco(lead_id);
CREATE INDEX IF NOT EXISTS idx_simulacoes_mb_imovel ON simulacoes_multi_banco(imovel_id);
CREATE INDEX IF NOT EXISTS idx_simulacoes_mb_valor ON simulacoes_multi_banco(valor_imovel);

-- ── Tabela: analises_juridicas ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS analises_juridicas (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  documento_id          UUID REFERENCES documentos_leads(id) ON DELETE SET NULL,
  imovel_id             UUID REFERENCES imoveis(id) ON DELETE SET NULL,
  lead_id               UUID REFERENCES leads(id) ON DELETE SET NULL,

  tipo_documento        VARCHAR(60),           -- matricula, escritura, contrato, certidao, etc.
  riscos_identificados  JSONB DEFAULT '[]'::jsonb,  -- [{tipo, descricao, nivel: "baixo"|"medio"|"alto"|"critico"}]
  pendencias            JSONB DEFAULT '[]'::jsonb,  -- [{descricao, acao_requerida}]
  recomendacoes         JSONB DEFAULT '[]'::jsonb,  -- [{descricao, prioridade}]
  necessidade_revisao   BOOLEAN NOT NULL DEFAULT TRUE,
  analise_ia            TEXT,
  resumo_executivo      TEXT,
  colaborador_id        UUID,
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analises_juridicas_doc ON analises_juridicas(documento_id);
CREATE INDEX IF NOT EXISTS idx_analises_juridicas_imovel ON analises_juridicas(imovel_id);
CREATE INDEX IF NOT EXISTS idx_analises_juridicas_lead ON analises_juridicas(lead_id);
CREATE INDEX IF NOT EXISTS idx_analises_juridicas_revisao ON analises_juridicas(necessidade_revisao) WHERE necessidade_revisao = TRUE;

-- ── Tabela: analises_financeiras ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS analises_financeiras (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id               UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  imovel_id             UUID REFERENCES imoveis(id) ON DELETE SET NULL,

  renda_mensal          NUMERIC(12,2),
  renda_anual           NUMERIC(14,2),
  compromissos_mensais  NUMERIC(12,2) DEFAULT 0,

  capacidade_compra     NUMERIC(14,2),           -- valor máximo que o lead pode financiar
  comprometimento_renda NUMERIC(5,2),            -- % da renda comprometida com parcela
  entrada_necessaria    NUMERIC(14,2),
  prazo_ideal_meses     INTEGER,
  risco_aprovacao       risco_aprovacao NOT NULL DEFAULT 'medio',

  perfil_financeiro     JSONB DEFAULT '{}'::jsonb,  -- {estabilidade: "alta", historico: "limpo", ...}
  recomendacao_ia       TEXT,

  colaborador_id        UUID,
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analises_fin_lead ON analises_financeiras(lead_id);
CREATE INDEX IF NOT EXISTS idx_analises_fin_risco ON analises_financeiras(risco_aprovacao);

-- ── Tabela: avaliacoes_imoveis ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS avaliacoes_imoveis (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  imovel_id             UUID NOT NULL REFERENCES imoveis(id) ON DELETE CASCADE,

  valor_estimado        NUMERIC(14,2),
  valor_minimo          NUMERIC(14,2),
  valor_maximo          NUMERIC(14,2),
  metodo                VARCHAR(60) DEFAULT 'comparativos',  -- comparativos, custo, renda

  fatores_avaliacao     JSONB DEFAULT '{}'::jsonb,  -- {localizacao: 0.25, metragem: 0.2, ...}
  imoveis_comparaveis   JSONB DEFAULT '[]'::jsonb,  -- [{endereco, valor, diferenca, ...}]
  metodologia_descricao TEXT,
  margem_confianca      NUMERIC(5,2) DEFAULT 0,    -- 0 a 100

  colaborador_id        UUID,
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_avaliacoes_imovel ON avaliacoes_imoveis(imovel_id);
CREATE INDEX IF NOT EXISTS idx_avaliacoes_valor ON avaliacoes_imoveis(valor_estimado);

-- ── Tabela: assistente_sessions (sessões do chat com IA) ─────────────────────
CREATE TABLE IF NOT EXISTS assistente_sessions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id               UUID REFERENCES leads(id) ON DELETE SET NULL,
  colaborador_id        UUID REFERENCES colaboradores(id) ON DELETE SET NULL,
  is_publica            BOOLEAN NOT NULL DEFAULT FALSE,  -- sessão pública (site)

  contexto_ia           JSONB DEFAULT '{}'::jsonb,       -- preferências, histórico, perfil
  resumo_sessao         TEXT,
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assistente_sessions_lead ON assistente_sessions(lead_id);
CREATE INDEX IF NOT EXISTS idx_assistente_sessions_publica ON assistente_sessions(is_publica);

-- ── Tabela: assistente_messages (mensagens do chat) ──────────────────────────
CREATE TABLE IF NOT EXISTS assistente_messages (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id            UUID NOT NULL REFERENCES assistente_sessions(id) ON DELETE CASCADE,
  role                  VARCHAR(10) NOT NULL,          -- "user" | "assistant"
  content               TEXT NOT NULL,
  metadados             JSONB DEFAULT '{}'::jsonb,     -- {tipo, contexto, imovel_id, ...}
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assistente_messages_session ON assistente_messages(session_id, criado_em);

-- ── Tabela: relatorios_inteligentes ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS relatorios_inteligentes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo                  VARCHAR(60) NOT NULL,          -- funil, vendas, leads, financeiro, mercado
  periodo_inicio        DATE,
  periodo_fim           DATE,

  dados                 JSONB DEFAULT '{}'::jsonb,     -- dados consolidados do relatório
  insights_ia           JSONB DEFAULT '[]'::jsonb,     -- [{titulo, descricao, impacto}]
  recomendacoes_ia      JSONB DEFAULT '[]'::jsonb,
  relatorio_html        TEXT,                          -- versão HTML do relatório

  colaborador_id        UUID,
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_relatorios_tipo ON relatorios_inteligentes(tipo);
CREATE INDEX IF NOT EXISTS idx_relatorios_periodo ON relatorios_inteligentes(periodo_inicio, periodo_fim);

