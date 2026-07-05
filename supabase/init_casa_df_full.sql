-- CASA DF — SCHEMA COMPLETO PARA SUPABASE
-- Execute este arquivo em banco Supabase NOVO/Vazio pelo SQL Editor ou via psql.
-- Preferencialmente use: pnpm run migrate:all, pois ele mostra em qual arquivo parou se houver erro.
-- Gerado a partir de db/migrate.sql + db/migrations/*.sql em ordem alfabética.



-- ============================================================
-- db/migrate.sql
-- ============================================================

-- ============================================================
-- DESTRAVA CRÉDITO — Migração Unificada para PostgreSQL Nativo
-- Ambiente: VPS / Coolify / postgres:17-alpine
-- Sem Supabase SDK, sem RLS, sem auth.uid()
-- Idempotente: seguro para reexecutar a qualquer momento
-- ============================================================

-- ─── Extensões ────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()

-- ─── 1. Tabela: colaboradores ─────────────────────────────────
-- Autenticação própria via JWT + bcrypt (sem Supabase Auth)
CREATE TABLE IF NOT EXISTS public.colaboradores (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  email       TEXT        UNIQUE NOT NULL,
  nome        TEXT        NOT NULL DEFAULT '',
  cargo       TEXT        NOT NULL DEFAULT 'Analista',
  senha_hash  TEXT,                          -- bcrypt hash da senha
  ativo       BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 2. Tabela: leads ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.leads (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nome             TEXT        NOT NULL DEFAULT '',
  email            TEXT,
  telefone         TEXT        NOT NULL DEFAULT '',
  empresa          TEXT,
  cpf_cnpj         TEXT,
  cargo            TEXT,
  tipo_pessoa      TEXT        DEFAULT 'pj' CHECK (tipo_pessoa IN ('pf','pj')),
  produto_interesse TEXT,
  valor_solicitado NUMERIC(15,2),
  prazo_meses      INTEGER,
  finalidade       TEXT,
  mensagem         TEXT,
  origem           TEXT        NOT NULL DEFAULT 'site',
  status           TEXT        NOT NULL DEFAULT 'novo'
                     CHECK (status IN ('novo','contatado','em_negociacao','convertido','perdido')),
  etapa_funil      TEXT        NOT NULL DEFAULT 'novo'
                     CHECK (etapa_funil IN ('novo','contato_feito','proposta_enviada','negociacao','ganho','perdido','inativo')),
  temperatura      TEXT        NOT NULL DEFAULT 'frio'
                     CHECK (temperatura IN ('frio','morno','quente')),
  score_ia         INTEGER     DEFAULT 0 CHECK (score_ia BETWEEN 0 AND 100),
  score_manual     INTEGER     CHECK (score_manual BETWEEN 0 AND 100),
  score_efetivo    INTEGER     GENERATED ALWAYS AS (COALESCE(score_manual, score_ia)) STORED,
  tags             TEXT[]      DEFAULT '{}',
  cidade           TEXT,
  estado           CHAR(2),
  canal_origem     TEXT        DEFAULT 'site',
  proximo_followup TIMESTAMPTZ,
  ultimo_contato_em TIMESTAMPTZ,
  resumo_ia        TEXT,
  observacoes_ia   TEXT,
  chatwoot_conv_id BIGINT,
  responsavel_id   UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  utm_source       TEXT,
  utm_medium       TEXT,
  utm_campaign     TEXT,
  pagina_origem    TEXT,
  n8n_notificado   BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 3. Tabela: simulacoes_colaborador ────────────────────────
CREATE TABLE IF NOT EXISTS public.simulacoes_colaborador (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  colaborador_id       UUID        NOT NULL REFERENCES public.colaboradores(id) ON DELETE CASCADE,
  cliente_nome         TEXT        NOT NULL DEFAULT '',
  cliente_empresa      TEXT,
  cliente_cpf_cnpj     TEXT,
  cliente_telefone     TEXT,
  valor_solicitado     NUMERIC(15,2),
  quantidade_parcelas  INTEGER,
  taxa_juros_mensal    NUMERIC(8,4),
  comissao_percentual  NUMERIC(6,4),
  total_comissao       NUMERIC(15,2),
  valor_parcela        NUMERIC(15,2),
  valor_total_pagar    NUMERIC(15,2),
  total_juros          NUMERIC(15,2),
  custo_efetivo_total  NUMERIC(8,4),
  imposto_percentual   NUMERIC(6,4),
  total_imposto        NUMERIC(15,2),
  banco                TEXT,
  linha_credito        TEXT,
  observacoes          TEXT,
  status               TEXT        NOT NULL DEFAULT 'rascunho'
                         CHECK (status IN ('rascunho','pendente','em_analise','aprovado','reprovado','cancelado')),
  criado_em            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 4. Tabela: crm_atividades ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_atividades (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id        UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  tipo           TEXT        NOT NULL DEFAULT 'nota'
                   CHECK (tipo IN ('nota','ligacao','whatsapp','email','reuniao','proposta','documento','status_change','ia_acao','followup','outro')),
  titulo         TEXT        NOT NULL DEFAULT '',
  descricao      TEXT,
  resultado      TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 5. Tabela: crm_documentos ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_documentos (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id       UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  nome          TEXT        NOT NULL,
  tipo          TEXT,
  status        TEXT        NOT NULL DEFAULT 'pendente'
                  CHECK (status IN ('pendente','solicitado','recebido','aprovado','rejeitado')),
  obrigatorio   BOOLEAN     DEFAULT FALSE,
  observacao    TEXT,
  url_arquivo   TEXT,
  recebido_em   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 6. Tabela: crm_qualificacoes_ia ──────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_qualificacoes_ia (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id               UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  score                 INTEGER     CHECK (score BETWEEN 0 AND 100),
  probabilidade_aprovacao NUMERIC(5,2),
  linha_recomendada     TEXT,
  motivo_recomendacao   TEXT,
  pontos_atencao        TEXT[],
  proximos_passos       TEXT[],
  resumo                TEXT,
  modelo_ia             TEXT,
  versao_modelo         TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 7. Tabela: crm_historico_funil ───────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_historico_funil (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id        UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  etapa_anterior TEXT,
  etapa_nova     TEXT        NOT NULL,
  motivo         TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 8. Tabela: crm_score_historico ───────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_score_historico (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id     UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  score       INTEGER     NOT NULL CHECK (score BETWEEN 0 AND 100),
  tipo        TEXT        NOT NULL DEFAULT 'ia' CHECK (tipo IN ('ia','manual','sistema')),
  motivo      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 9. Tabela: crm_recomendacoes_ia ──────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_recomendacoes_ia (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id           UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  linha_recomendada TEXT,
  probabilidade     NUMERIC(5,2),
  motivo            TEXT,
  pontos_atencao    TEXT[],
  proximos_passos   TEXT[],
  modelo_ia         TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 10. Tabela: crm_eventos_webhook ──────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_eventos_webhook (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id     UUID        REFERENCES public.leads(id) ON DELETE SET NULL,
  evento      TEXT        NOT NULL,
  payload     JSONB,
  status      TEXT        DEFAULT 'recebido',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Índices ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_leads_status         ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_etapa_funil    ON public.leads(etapa_funil);
CREATE INDEX IF NOT EXISTS idx_leads_origem         ON public.leads(origem);
CREATE INDEX IF NOT EXISTS idx_leads_responsavel    ON public.leads(responsavel_id);
CREATE INDEX IF NOT EXISTS idx_leads_created_at     ON public.leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_utm_source     ON public.leads(utm_source) WHERE utm_source IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_simulacoes_colab     ON public.simulacoes_colaborador(colaborador_id);
CREATE INDEX IF NOT EXISTS idx_crm_ativ_lead        ON public.crm_atividades(lead_id);
CREATE INDEX IF NOT EXISTS idx_crm_docs_lead        ON public.crm_documentos(lead_id);
CREATE INDEX IF NOT EXISTS idx_crm_qualif_lead      ON public.crm_qualificacoes_ia(lead_id);

-- ─── Triggers: updated_at automático ──────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_leads_updated_at') THEN
    CREATE TRIGGER trg_leads_updated_at
      BEFORE UPDATE ON public.leads
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_colaboradores_updated_at') THEN
    CREATE TRIGGER trg_colaboradores_updated_at
      BEFORE UPDATE ON public.colaboradores
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_simulacoes_updated_at') THEN
    CREATE TRIGGER trg_simulacoes_updated_at
      BEFORE UPDATE ON public.simulacoes_colaborador
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_crm_ativ_updated_at') THEN
    CREATE TRIGGER trg_crm_ativ_updated_at
      BEFORE UPDATE ON public.crm_atividades
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_crm_docs_updated_at') THEN
    CREATE TRIGGER trg_crm_docs_updated_at
      BEFORE UPDATE ON public.crm_documentos
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ─── View: vw_crm_pipeline ────────────────────────────────────
CREATE OR REPLACE VIEW public.vw_crm_pipeline AS
SELECT
  l.id,
  l.nome,
  l.telefone,
  l.email,
  l.empresa,
  l.tipo_pessoa,
  l.cpf_cnpj,
  l.cargo,
  l.cidade,
  l.estado,
  l.canal_origem,
  l.produto_interesse,
  l.valor_solicitado,
  l.prazo_meses,
  l.etapa_funil,
  l.temperatura,
  l.score_ia,
  l.score_manual,
  l.score_efetivo,
  l.tags,
  l.proximo_followup,
  l.ultimo_contato_em,
  l.resumo_ia,
  l.observacoes_ia,
  l.chatwoot_conv_id,
  l.responsavel_id,
  c.nome                                                        AS responsavel_nome,
  l.origem,
  l.status,
  l.created_at,
  l.updated_at,
  COALESCE(d.total_docs, 0)                                     AS total_docs,
  COALESCE(d.docs_recebidos, 0)                                 AS docs_recebidos,
  COALESCE(d.docs_pendentes_obrig, 0)                           AS docs_pendentes_obrig,
  a.titulo                                                      AS ultima_atividade,
  a.created_at                                                  AS ultima_atividade_em,
  EXTRACT(DAY FROM NOW() - COALESCE(l.ultimo_contato_em, l.created_at))::INTEGER AS dias_sem_contato
FROM public.leads l
LEFT JOIN public.colaboradores c ON c.id = l.responsavel_id
LEFT JOIN LATERAL (
  SELECT
    COUNT(*)                                                    AS total_docs,
    COUNT(*) FILTER (WHERE status IN ('recebido','aprovado'))   AS docs_recebidos,
    COUNT(*) FILTER (WHERE obrigatorio AND status = 'pendente') AS docs_pendentes_obrig
  FROM public.crm_documentos WHERE lead_id = l.id
) d ON TRUE
LEFT JOIN LATERAL (
  SELECT titulo, created_at
  FROM public.crm_atividades
  WHERE lead_id = l.id
  ORDER BY created_at DESC LIMIT 1
) a ON TRUE
WHERE l.etapa_funil NOT IN ('inativo');

-- ─── View: vw_leads_para_ia ───────────────────────────────────
CREATE OR REPLACE VIEW public.vw_leads_para_ia AS
SELECT
  l.id,
  l.nome,
  l.empresa,
  l.tipo_pessoa,
  l.produto_interesse,
  l.valor_solicitado,
  l.prazo_meses,
  l.origem,
  l.etapa_funil,
  l.temperatura,
  l.score_ia,
  l.score_efetivo,
  l.created_at,
  l.updated_at,
  (l.score_ia = 0 OR l.score_ia IS NULL)                        AS precisa_score,
  EXTRACT(DAY FROM NOW() - l.created_at)::INTEGER               AS dias_desde_criacao
FROM public.leads l
WHERE l.etapa_funil NOT IN ('ganho','perdido','inativo');

-- ─── Normaliza dados existentes ───────────────────────────────
-- Corrige etapa_funil com maiúsculo (bug do schema_fase1_1_delta)
UPDATE public.leads
SET etapa_funil = LOWER(etapa_funil)
WHERE etapa_funil IS DISTINCT FROM LOWER(etapa_funil);

-- Garante que leads sem etapa_funil recebam 'novo'
UPDATE public.leads
SET etapa_funil = 'novo'
WHERE etapa_funil IS NULL;

-- ─── Tabela: empresas ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.empresas (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  razao_social         TEXT         NOT NULL,
  nome_fantasia        TEXT,
  cnpj                 TEXT,
  inscricao_estadual   TEXT,
  email                TEXT,
  telefone             TEXT,
  whatsapp             TEXT,
  site                 TEXT,
  segmento             TEXT,
  porte                TEXT         DEFAULT 'mei'
                         CHECK (porte IN ('mei','me','epp','medio','grande')),
  faturamento_anual    NUMERIC(15,2),
  numero_funcionarios  INTEGER,
  -- Endereço
  cep                  TEXT,
  logradouro           TEXT,
  numero               TEXT,
  complemento          TEXT,
  bairro               TEXT,
  cidade               TEXT,
  estado               CHAR(2),
  -- Responsável / sócio
  responsavel_nome     TEXT,
  responsavel_cpf      TEXT,
  responsavel_cargo    TEXT,
  responsavel_telefone TEXT,
  responsavel_email    TEXT,
  -- Dados financeiros
  banco_principal      TEXT,
  agencia              TEXT,
  conta                TEXT,
  limite_credito_atual NUMERIC(15,2),
  score_serasa         INTEGER,
  score_spc            INTEGER,
  -- Relacionamento interno
  responsavel_id       UUID         REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  status               TEXT         NOT NULL DEFAULT 'ativo'
                         CHECK (status IN ('ativo','inativo','prospecto','cliente','ex_cliente')),
  origem               TEXT         DEFAULT 'manual',
  tags                 TEXT[]       DEFAULT '{}',
  observacoes          TEXT,
  -- Controle
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_empresas_razao_social ON public.empresas(razao_social);
CREATE INDEX IF NOT EXISTS idx_empresas_cnpj         ON public.empresas(cnpj) WHERE cnpj IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_status       ON public.empresas(status);
CREATE INDEX IF NOT EXISTS idx_empresas_responsavel  ON public.empresas(responsavel_id);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_empresas_updated_at') THEN
    CREATE TRIGGER trg_empresas_updated_at
      BEFORE UPDATE ON public.empresas
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ─── FIM DA MIGRAÇÃO ─────────────────────────────────────────────

-- ============================================================
-- db/migrations/001_triagem_leads_create.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 001 — Criação da tabela triagem_leads
-- Versão: 1.0 | Data: 2026-04-01
-- Contexto: A tabela triagem_leads é referenciada pelo servidor
--   (server/index.ts) e por migrate_simulacoes_empresa_v1.sql,
--   mas nunca foi criada formalmente em nenhum schema do repositório.
--   Esta migration cria a tabela de forma idempotente.
-- Idempotente: seguro para reexecutar.
-- ============================================================

-- ─── Tabela: triagem_leads ────────────────────────────────────
-- Fila de pré-qualificação para leads vindos do simulador público.
-- Leads ficam aqui até serem qualificados (manual ou por IA) e
-- convertidos em leads reais na tabela `leads`.
CREATE TABLE IF NOT EXISTS public.triagem_leads (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nome           TEXT        NOT NULL DEFAULT '',
  email          TEXT,
  telefone       TEXT        NOT NULL DEFAULT '',
  empresa        TEXT,
  cpf_cnpj       TEXT,
  tipo_pessoa    TEXT        NOT NULL DEFAULT 'pj'
                   CHECK (tipo_pessoa IN ('pf','pj')),
  produto        TEXT,
  valor          NUMERIC(15,2),
  prazo          INTEGER,
  parcela        NUMERIC(15,2),
  taxa           NUMERIC(8,4),
  cidade         TEXT,
  estado         CHAR(2),
  utm_source     TEXT,
  utm_medium     TEXT,
  utm_campaign   TEXT,
  status         TEXT        NOT NULL DEFAULT 'pendente'
                   CHECK (status IN ('pendente','possivel_cliente','curioso','sem_perfil','convertido','descartado')),
  classificacao  TEXT,
  observacoes    TEXT,
  observacoes_ia TEXT,
  score_ia       INTEGER     DEFAULT 0 CHECK (score_ia BETWEEN 0 AND 100),
  responsavel_id UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  empresa_id     UUID        REFERENCES public.empresas(id) ON DELETE SET NULL,
  lead_id        UUID        REFERENCES public.leads(id) ON DELETE SET NULL,
  convertido_em  TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Índices ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_triagem_status
  ON public.triagem_leads(status);

CREATE INDEX IF NOT EXISTS idx_triagem_created_at
  ON public.triagem_leads(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_triagem_telefone
  ON public.triagem_leads(telefone);

CREATE INDEX IF NOT EXISTS idx_triagem_empresa_id
  ON public.triagem_leads(empresa_id)
  WHERE empresa_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_triagem_responsavel
  ON public.triagem_leads(responsavel_id)
  WHERE responsavel_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_triagem_lead_id
  ON public.triagem_leads(lead_id)
  WHERE lead_id IS NOT NULL;

-- ─── Trigger: updated_at automático ──────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_triagem_updated_at') THEN
    CREATE TRIGGER trg_triagem_updated_at
      BEFORE UPDATE ON public.triagem_leads
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ─── Confirmação ──────────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'Migration 001 — triagem_leads criada/verificada em %', NOW();
END $$;


-- ============================================================
-- db/migrations/002_fix_etapa_funil_kanban.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 002 — Correção do etapa_funil (Kanban invisível)
-- Versão: 1.0 | Data: 2026-04-01
--
-- PROBLEMA IDENTIFICADO:
--   O schema_fase1_1_delta.sql criou o DEFAULT da coluna
--   etapa_funil como 'Novo' (maiúsculo), mas:
--   (a) o CRM.tsx filtra por 'novo' (minúsculo)
--   (b) a view vw_crm_pipeline exclui etapa_funil = 'inativo'
--   (c) o CHECK constraint do migrate.sql aceita apenas minúsculos
--   Resultado: leads com etapa_funil = 'Novo' ficam INVISÍVEIS
--   no Kanban porque não batem com nenhuma coluna do ETAPAS_FUNIL.
--
-- ADICIONALMENTE:
--   O CRM.tsx define 9 etapas no frontend:
--     novo, contato_feito, qualificado, proposta_enviada,
--     negociacao, documentacao, aprovacao, ganho, perdido
--   Mas o migrate.sql define apenas 7 etapas no CHECK:
--     novo, contato_feito, proposta_enviada, negociacao,
--     ganho, perdido, inativo
--   As etapas 'qualificado', 'documentacao', 'aprovacao'
--   existem no frontend mas não no CHECK do banco.
--   Esta migration alinha o CHECK constraint com o frontend.
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

BEGIN;

-- ─── 1. Normalizar etapa_funil existente para minúsculas ─────
UPDATE public.leads
SET etapa_funil = LOWER(etapa_funil)
WHERE etapa_funil IS DISTINCT FROM LOWER(etapa_funil);

-- ─── 2. Backfill de NULLs ────────────────────────────────────
UPDATE public.leads
SET etapa_funil = 'novo'
WHERE etapa_funil IS NULL;

-- ─── 3. Corrigir valores fora do conjunto válido ─────────────
-- Leads com etapa_funil não reconhecida voltam para 'novo'
UPDATE public.leads
SET etapa_funil = 'novo'
WHERE etapa_funil NOT IN (
  'novo','contato_feito','qualificado','proposta_enviada',
  'negociacao','documentacao','aprovacao','ganho','perdido','inativo'
);

-- ─── 4. Remover o CHECK constraint antigo (se existir) ───────
DO $$
DECLARE
  v_constraint TEXT;
BEGIN
  SELECT conname INTO v_constraint
  FROM pg_constraint
  WHERE conrelid = 'public.leads'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%etapa_funil%';
  IF v_constraint IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.leads DROP CONSTRAINT %I', v_constraint);
    RAISE NOTICE 'CHECK constraint % removido', v_constraint;
  END IF;
END $$;

-- ─── 5. Adicionar CHECK constraint atualizado ────────────────
ALTER TABLE public.leads
  ADD CONSTRAINT leads_etapa_funil_check
  CHECK (etapa_funil IN (
    'novo','contato_feito','qualificado','proposta_enviada',
    'negociacao','documentacao','aprovacao','ganho','perdido','inativo'
  ));

-- ─── 6. Garantir DEFAULT correto (minúsculo) ─────────────────
ALTER TABLE public.leads
  ALTER COLUMN etapa_funil SET DEFAULT 'novo';

-- ─── 7. Recriar view vw_crm_pipeline com etapas corretas ─────
-- Inclui todas as etapas do frontend; exclui apenas 'inativo'
CREATE OR REPLACE VIEW public.vw_crm_pipeline AS
SELECT
  l.id,
  l.nome,
  l.telefone,
  l.email,
  l.empresa,
  l.tipo_pessoa,
  l.cpf_cnpj,
  l.cargo,
  l.cidade,
  l.estado,
  l.canal_origem,
  l.produto_interesse,
  l.valor_solicitado,
  l.prazo_meses,
  l.etapa_funil,
  l.temperatura,
  l.score_ia,
  l.score_manual,
  l.score_efetivo,
  l.tags,
  l.proximo_followup,
  l.ultimo_contato_em,
  l.resumo_ia,
  l.observacoes_ia,
  l.chatwoot_conv_id,
  l.responsavel_id,
  c.nome                                                          AS responsavel_nome,
  l.origem,
  l.status,
  l.created_at,
  l.updated_at,
  COALESCE(d.total_docs, 0)                                       AS total_docs,
  COALESCE(d.docs_recebidos, 0)                                   AS docs_recebidos,
  COALESCE(d.docs_pendentes_obrig, 0)                             AS docs_pendentes_obrig,
  a.titulo                                                        AS ultima_atividade,
  a.created_at                                                    AS ultima_atividade_em,
  EXTRACT(DAY FROM NOW() - COALESCE(l.ultimo_contato_em, l.created_at))::INTEGER AS dias_sem_contato
FROM public.leads l
LEFT JOIN public.colaboradores c ON c.id = l.responsavel_id
LEFT JOIN LATERAL (
  SELECT
    COUNT(*)                                                      AS total_docs,
    COUNT(*) FILTER (WHERE status IN ('recebido','aprovado'))     AS docs_recebidos,
    COUNT(*) FILTER (WHERE obrigatorio AND status = 'pendente')   AS docs_pendentes_obrig
  FROM public.crm_documentos WHERE lead_id = l.id
) d ON TRUE
LEFT JOIN LATERAL (
  SELECT titulo, created_at
  FROM public.crm_atividades
  WHERE lead_id = l.id
  ORDER BY created_at DESC LIMIT 1
) a ON TRUE
WHERE l.etapa_funil NOT IN ('inativo');

-- ─── 8. Recriar view vw_crm_metricas ─────────────────────────
CREATE OR REPLACE VIEW public.vw_crm_metricas AS
SELECT
  etapa_funil,
  temperatura,
  COUNT(*)                    AS total_leads,
  SUM(valor_solicitado)       AS valor_total_pipeline,
  AVG(score_efetivo)::INTEGER AS score_medio,
  COUNT(*) FILTER (WHERE proximo_followup <= NOW()) AS followups_atrasados,
  COUNT(*) FILTER (WHERE dias_sem_contato > 7)      AS sem_contato_7d
FROM public.vw_crm_pipeline
GROUP BY etapa_funil, temperatura;

COMMIT;

-- ─── Verificação ──────────────────────────────────────────────
SELECT etapa_funil, COUNT(*) AS total
FROM public.leads
GROUP BY etapa_funil
ORDER BY etapa_funil;


-- ============================================================
-- db/migrations/003_fix_mover_funil_historico.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 003 — Correção do mover-funil: histórico e atividade
-- Versão: 1.0 | Data: 2026-04-01
--
-- PROBLEMA IDENTIFICADO:
--   O endpoint POST /api/crm/mover-funil (server/index.ts:1206)
--   faz apenas:
--     UPDATE leads SET etapa_funil = $1, updated_at = NOW()
--   Não registra:
--     - crm_historico_funil (rastreabilidade de movimentações)
--     - crm_atividades (linha do tempo do lead)
--   Isso torna o histórico do funil invisível para gestores.
--
-- SOLUÇÃO:
--   Criar trigger AFTER UPDATE na tabela leads que registra
--   automaticamente em crm_historico_funil e crm_atividades
--   quando etapa_funil muda. Isso corrige tanto o endpoint
--   atual quanto qualquer futura atualização direta.
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

-- ─── 1. Função trigger: registrar movimentação de funil ──────
CREATE OR REPLACE FUNCTION public.fn_registrar_movimentacao_funil()
RETURNS TRIGGER AS $$
BEGIN
  -- Só dispara se etapa_funil realmente mudou
  IF OLD.etapa_funil IS DISTINCT FROM NEW.etapa_funil THEN

    -- Registrar no histórico do funil
    INSERT INTO public.crm_historico_funil (
      lead_id, etapa_de, etapa_para, motivo, colaborador_id, origem_ia
    ) VALUES (
      NEW.id,
      OLD.etapa_funil,
      NEW.etapa_funil,
      'Movimentação via sistema',
      NEW.responsavel_id,
      FALSE
    );

    -- Registrar como atividade
    INSERT INTO public.crm_atividades (
      lead_id, colaborador_id, tipo, titulo, descricao, origem_ia, concluido
    ) VALUES (
      NEW.id,
      NEW.responsavel_id,
      'status_change',
      'Funil: ' || COALESCE(OLD.etapa_funil, '—') || ' → ' || NEW.etapa_funil,
      'Movimentação automática registrada pelo sistema',
      FALSE,
      TRUE
    );

    -- Atualizar ultimo_contato_em
    NEW.ultimo_contato_em = NOW();

  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─── 2. Criar trigger (idempotente) ──────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_leads_movimentacao_funil'
  ) THEN
    CREATE TRIGGER trg_leads_movimentacao_funil
      BEFORE UPDATE ON public.leads
      FOR EACH ROW
      EXECUTE FUNCTION public.fn_registrar_movimentacao_funil();
    RAISE NOTICE 'Trigger trg_leads_movimentacao_funil criado';
  ELSE
    -- Recriar para garantir versão atualizada da função
    DROP TRIGGER trg_leads_movimentacao_funil ON public.leads;
    CREATE TRIGGER trg_leads_movimentacao_funil
      BEFORE UPDATE ON public.leads
      FOR EACH ROW
      EXECUTE FUNCTION public.fn_registrar_movimentacao_funil();
    RAISE NOTICE 'Trigger trg_leads_movimentacao_funil recriado';
  END IF;
END $$;

-- ─── 3. Confirmação ──────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'Migration 003 — trigger de movimentação de funil aplicado em %', NOW();
END $$;


-- ============================================================
-- db/migrations/004_fix_usuarios_duplicados_cargos.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 004 — Correção de usuários duplicados e cargos
-- Versão: 1.0 | Data: 2026-04-01
--
-- PROBLEMA IDENTIFICADO:
--   1. CARGOS_VALIDOS no servidor usa Title Case ('Administrador')
--      mas HIERARQUIA_CARGOS usa lowercase ('administrador').
--      A função nivelCargo() faz .toLowerCase() mas a criação
--      de usuários pode gravar cargos com capitalização variada,
--      causando inconsistência nas permissões.
--
--   2. Não existe constraint UNIQUE no email de colaboradores
--      que seja case-insensitive. Dois usuários podem ter o
--      mesmo email com capitalização diferente.
--
--   3. Não existe índice único funcional em colaboradores.email
--      para prevenir duplicatas silenciosas.
--
-- SOLUÇÃO:
--   (a) Normalizar todos os cargos existentes para lowercase
--   (b) Criar índice único funcional em lower(email)
--   (c) Criar constraint CHECK nos cargos válidos
--   (d) Adicionar unique index no email normalizado
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

BEGIN;

-- ─── 1. Normalizar cargos existentes para lowercase ──────────
UPDATE public.colaboradores
SET cargo = LOWER(TRIM(cargo))
WHERE cargo IS DISTINCT FROM LOWER(TRIM(cargo));

-- ─── 2. Normalizar emails existentes para lowercase ──────────
UPDATE public.colaboradores
SET email = LOWER(TRIM(email))
WHERE email IS DISTINCT FROM LOWER(TRIM(email));

-- ─── 3. Índice único funcional no email (case-insensitive) ───
-- Previne duplicatas de email independente de capitalização
CREATE UNIQUE INDEX IF NOT EXISTS idx_colaboradores_email_unique
  ON public.colaboradores(LOWER(TRIM(email)));

-- ─── 4. CHECK constraint nos cargos válidos ──────────────────
DO $$
DECLARE
  v_constraint TEXT;
BEGIN
  -- Remove constraint antiga se existir
  SELECT conname INTO v_constraint
  FROM pg_constraint
  WHERE conrelid = 'public.colaboradores'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%cargo%';
  IF v_constraint IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.colaboradores DROP CONSTRAINT %I', v_constraint);
    RAISE NOTICE 'CHECK constraint de cargo % removido', v_constraint;
  END IF;
END $$;

ALTER TABLE public.colaboradores
  ADD CONSTRAINT colaboradores_cargo_check
  CHECK (cargo IN (
    'administrador',
    'diretor',
    'gerente comercial',
    'analista de crédito',
    'analista de credito',
    'consultor de crédito',
    'consultor de credito',
    'captador externo',
    'estagiário',
    'estagiario',
    'admin'
  ));

-- ─── 5. Garantir coluna ativo com DEFAULT TRUE ───────────────
ALTER TABLE public.colaboradores
  ALTER COLUMN ativo SET DEFAULT TRUE;

-- ─── 6. Índice de performance em cargo ───────────────────────
CREATE INDEX IF NOT EXISTS idx_colaboradores_cargo
  ON public.colaboradores(cargo);

COMMIT;

-- ─── Verificação ──────────────────────────────────────────────
SELECT cargo, COUNT(*) AS total, COUNT(*) FILTER (WHERE ativo) AS ativos
FROM public.colaboradores
GROUP BY cargo
ORDER BY cargo;


-- ============================================================
-- db/migrations/005_crm_camada_operacional.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 005 — Nova camada operacional do CRM
-- Versão: 1.0 | Data: 2026-04-01
--
-- O QUE ESTA MIGRATION FAZ:
--   1. Tabela crm_caixas: caixas de atendimento (ex: "WhatsApp
--      Comercial", "Email Suporte") com controle de IA por caixa
--   2. Tabela crm_delegacoes: histórico de delegações de leads
--      entre colaboradores (quem delegou, para quem, quando, motivo)
--   3. Colunas adicionais em leads: caixa_id, delegado_de,
--      delegado_em, prioridade
--   4. Tabela crm_notas_internas: notas privadas por lead,
--      visíveis apenas para o responsável e gestores
--   5. Tabela crm_followups: agenda de follow-ups por lead
--      com status e resultado
--   6. Views operacionais para dashboard de gestores
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

-- ─── 1. Tabela: crm_caixas ───────────────────────────────────
-- Representa canais/filas de atendimento (WhatsApp, Email, etc.)
-- com controle individual de IA ativa/pausada por caixa.
CREATE TABLE IF NOT EXISTS public.crm_caixas (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nome            TEXT        NOT NULL,
  descricao       TEXT,
  canal           TEXT        NOT NULL DEFAULT 'whatsapp'
                    CHECK (canal IN ('whatsapp','email','telefone','chat','formulario','outro')),
  ativo           BOOLEAN     NOT NULL DEFAULT TRUE,
  ia_ativa        BOOLEAN     NOT NULL DEFAULT FALSE,
  ia_agente_id    UUID        REFERENCES public.ia_agentes(id) ON DELETE SET NULL,
  responsavel_id  UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  cor             TEXT        DEFAULT '#3B82F6',
  icone           TEXT        DEFAULT 'inbox',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_caixas_ativo
  ON public.crm_caixas(ativo);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_crm_caixas_updated_at') THEN
    CREATE TRIGGER trg_crm_caixas_updated_at
      BEFORE UPDATE ON public.crm_caixas
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ─── 2. Coluna caixa_id em leads ─────────────────────────────
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS caixa_id UUID
    REFERENCES public.crm_caixas(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_leads_caixa_id
  ON public.leads(caixa_id)
  WHERE caixa_id IS NOT NULL;

-- ─── 3. Coluna prioridade em leads ───────────────────────────
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS prioridade TEXT DEFAULT 'normal'
    CHECK (prioridade IN ('baixa','normal','alta','urgente'));

-- ─── 4. Tabela: crm_delegacoes ───────────────────────────────
-- Rastreia cada delegação de lead entre colaboradores.
-- Permite auditoria completa de quem delegou o quê e quando.
CREATE TABLE IF NOT EXISTS public.crm_delegacoes (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id         UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  delegado_por    UUID        NOT NULL REFERENCES public.colaboradores(id) ON DELETE CASCADE,
  delegado_para   UUID        NOT NULL REFERENCES public.colaboradores(id) ON DELETE CASCADE,
  motivo          TEXT,
  aceito          BOOLEAN,
  aceito_em       TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_delegacoes_lead
  ON public.crm_delegacoes(lead_id);

CREATE INDEX IF NOT EXISTS idx_crm_delegacoes_para
  ON public.crm_delegacoes(delegado_para);

CREATE INDEX IF NOT EXISTS idx_crm_delegacoes_por
  ON public.crm_delegacoes(delegado_por);

-- ─── 5. Colunas de delegação em leads ────────────────────────
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS delegado_de UUID
    REFERENCES public.colaboradores(id) ON DELETE SET NULL;

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS delegado_em TIMESTAMPTZ;

-- ─── 6. Tabela: crm_notas_internas ───────────────────────────
-- Notas privadas por lead. Visíveis apenas para o autor,
-- o responsável atual e gestores (cargo <= gerente comercial).
CREATE TABLE IF NOT EXISTS public.crm_notas_internas (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id         UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  autor_id        UUID        NOT NULL REFERENCES public.colaboradores(id) ON DELETE CASCADE,
  conteudo        TEXT        NOT NULL,
  privada         BOOLEAN     NOT NULL DEFAULT TRUE,
  fixada          BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_notas_lead
  ON public.crm_notas_internas(lead_id);

CREATE INDEX IF NOT EXISTS idx_crm_notas_autor
  ON public.crm_notas_internas(autor_id);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_crm_notas_updated_at') THEN
    CREATE TRIGGER trg_crm_notas_updated_at
      BEFORE UPDATE ON public.crm_notas_internas
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ─── 7. Tabela: crm_followups ────────────────────────────────
-- Agenda de follow-ups por lead com resultado registrado.
-- Substitui o campo proximo_followup (TIMESTAMPTZ simples) por
-- uma tabela com histórico completo.
CREATE TABLE IF NOT EXISTS public.crm_followups (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id         UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id  UUID        NOT NULL REFERENCES public.colaboradores(id) ON DELETE CASCADE,
  agendado_para   TIMESTAMPTZ NOT NULL,
  tipo            TEXT        NOT NULL DEFAULT 'ligacao'
                    CHECK (tipo IN ('ligacao','whatsapp','email','reuniao','visita','outro')),
  descricao       TEXT,
  status          TEXT        NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente','realizado','cancelado','reagendado')),
  resultado       TEXT        CHECK (resultado IN ('positivo','neutro','negativo','sem_resposta',NULL)),
  observacoes     TEXT,
  reagendado_para TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_followups_lead
  ON public.crm_followups(lead_id);

CREATE INDEX IF NOT EXISTS idx_crm_followups_colaborador
  ON public.crm_followups(colaborador_id);

CREATE INDEX IF NOT EXISTS idx_crm_followups_agendado
  ON public.crm_followups(agendado_para)
  WHERE status = 'pendente';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_crm_followups_updated_at') THEN
    CREATE TRIGGER trg_crm_followups_updated_at
      BEFORE UPDATE ON public.crm_followups
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ─── 8. Trigger: atualizar proximo_followup em leads ─────────
-- Mantém o campo legado proximo_followup sincronizado com
-- o próximo follow-up pendente na nova tabela.
CREATE OR REPLACE FUNCTION public.fn_sync_proximo_followup()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.leads
  SET proximo_followup = (
    SELECT MIN(agendado_para)
    FROM public.crm_followups
    WHERE lead_id = COALESCE(NEW.lead_id, OLD.lead_id)
      AND status = 'pendente'
  )
  WHERE id = COALESCE(NEW.lead_id, OLD.lead_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_sync_followup_insert') THEN
    CREATE TRIGGER trg_sync_followup_insert
      AFTER INSERT OR UPDATE OR DELETE ON public.crm_followups
      FOR EACH ROW EXECUTE FUNCTION public.fn_sync_proximo_followup();
  END IF;
END $$;

-- ─── 9. Caixas padrão ────────────────────────────────────────
INSERT INTO public.crm_caixas (nome, descricao, canal, ativo, ia_ativa, cor, icone)
VALUES
  ('WhatsApp Comercial', 'Caixa principal de atendimento via WhatsApp', 'whatsapp', TRUE, FALSE, '#25D366', 'message-circle'),
  ('Formulário Site',    'Leads vindos do formulário do site',           'formulario', TRUE, FALSE, '#3B82F6', 'globe'),
  ('Email Comercial',    'Atendimento por e-mail',                       'email',     TRUE, FALSE, '#F59E0B', 'mail'),
  ('Telefone',           'Atendimento por telefone',                     'telefone',  TRUE, FALSE, '#8B5CF6', 'phone')
ON CONFLICT DO NOTHING;

-- ─── 10. Confirmação ─────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'Migration 005 — camada operacional CRM aplicada em %', NOW();
END $$;


-- ============================================================
-- db/migrations/006_crm_campos_leads_extras.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 006 — Campos extras em leads para operação CRM
-- Versão: 1.0 | Data: 2026-04-01
--
-- O QUE ESTA MIGRATION FAZ:
--   Adiciona campos operacionais que o servidor já referencia
--   (PATCH /api/leads/:id/ia) mas que podem não existir no banco:
--     - probabilidade_aprovacao
--     - probabilidade_conversao
--     - proxima_acao_ia
--     - linha_recomendada
--     - prazo_aprovacao_estimado
--     - analise_credito_ia
--
--   Também adiciona campos de controle de IA por lead:
--     - ia_ativa (se a IA deve responder neste lead)
--     - ia_pausada_ate (pausa temporária da IA)
--     - ia_motivo_pausa
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

BEGIN;

-- ─── Campos de IA já referenciados pelo servidor ─────────────
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS probabilidade_aprovacao  INTEGER
    CHECK (probabilidade_aprovacao BETWEEN 0 AND 100);

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS probabilidade_conversao  INTEGER
    CHECK (probabilidade_conversao BETWEEN 0 AND 100);

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS proxima_acao_ia          TEXT;

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS linha_recomendada        TEXT;

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS prazo_aprovacao_estimado TEXT;

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS analise_credito_ia       TEXT;

-- ─── Campos de controle de IA por lead ───────────────────────
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS ia_ativa         BOOLEAN     DEFAULT TRUE;

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS ia_pausada_ate   TIMESTAMPTZ;

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS ia_motivo_pausa  TEXT;

-- ─── Índice para leads com IA ativa ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_leads_ia_ativa
  ON public.leads(ia_ativa)
  WHERE ia_ativa = TRUE;

-- ─── Campos de controle de IA em triagem_leads ───────────────
ALTER TABLE public.triagem_leads
  ADD COLUMN IF NOT EXISTS ia_ativa         BOOLEAN     DEFAULT TRUE;

ALTER TABLE public.triagem_leads
  ADD COLUMN IF NOT EXISTS ia_pausada_ate   TIMESTAMPTZ;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'Migration 006 — campos extras de leads e IA aplicados em %', NOW();
END $$;


-- ============================================================
-- db/migrations/007_sync_chatwoot_n8n_ia_caixa.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 007 — Sincronização Chatwoot, n8n, CRM e IA por caixa
-- Versão: 1.0 | Data: 2026-04-01
--
-- O QUE ESTA MIGRATION FAZ:
--   1. Adiciona caixa_id em crm_conversas (vincula conversa à caixa)
--   2. Adiciona agente_responsavel_id em crm_conversas (quem
--      está atendendo esta conversa no momento)
--   3. Adiciona ia_ativa em crm_conversas (controle por conversa)
--   4. Adiciona ia_pausada_ate em crm_conversas
--   5. Adiciona coluna captador_id em triagem_leads (rastrear origem)
--   6. Cria view vw_conversas_ativas para dashboard em tempo real
--   7. Cria view vw_ia_status para monitoramento de IA por caixa
--   8. Adiciona índices de performance para o webhook handler
--
-- PROBLEMA IDENTIFICADO NO WEBHOOK:
--   O handler POST /api/webhook/chatwoot cria leads com
--   etapa_funil = 'novo' (correto) mas não vincula à caixa.
--   Isso impede o controle de IA por caixa.
--   A solução é adicionar caixa_id em crm_conversas e criar
--   uma função que determina a caixa pelo canal.
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

BEGIN;

-- ─── 1. Colunas em crm_conversas ─────────────────────────────
ALTER TABLE public.crm_conversas
  ADD COLUMN IF NOT EXISTS caixa_id             UUID
    REFERENCES public.crm_caixas(id) ON DELETE SET NULL;

ALTER TABLE public.crm_conversas
  ADD COLUMN IF NOT EXISTS agente_responsavel_id UUID
    REFERENCES public.colaboradores(id) ON DELETE SET NULL;

ALTER TABLE public.crm_conversas
  ADD COLUMN IF NOT EXISTS ia_ativa             BOOLEAN DEFAULT TRUE;

ALTER TABLE public.crm_conversas
  ADD COLUMN IF NOT EXISTS ia_pausada_ate       TIMESTAMPTZ;

ALTER TABLE public.crm_conversas
  ADD COLUMN IF NOT EXISTS ia_motivo_pausa      TEXT;

-- ─── 2. Índices em crm_conversas ─────────────────────────────
CREATE INDEX IF NOT EXISTS idx_crm_conversas_caixa
  ON public.crm_conversas(caixa_id)
  WHERE caixa_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_crm_conversas_agente
  ON public.crm_conversas(agente_responsavel_id)
  WHERE agente_responsavel_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_crm_conversas_ia_ativa
  ON public.crm_conversas(ia_ativa)
  WHERE ia_ativa = TRUE;

-- ─── 3. Coluna captador_id em triagem_leads ──────────────────
ALTER TABLE public.triagem_leads
  ADD COLUMN IF NOT EXISTS captador_id UUID
    REFERENCES public.colaboradores(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_triagem_captador
  ON public.triagem_leads(captador_id)
  WHERE captador_id IS NOT NULL;

-- ─── 4. Função: determinar caixa pelo canal ──────────────────
-- Usada pelo webhook handler para vincular conversas à caixa correta.
CREATE OR REPLACE FUNCTION public.fn_caixa_por_canal(p_canal TEXT)
RETURNS UUID AS $$
DECLARE
  v_caixa_id UUID;
BEGIN
  SELECT id INTO v_caixa_id
  FROM public.crm_caixas
  WHERE canal = p_canal
    AND ativo = TRUE
  ORDER BY created_at ASC
  LIMIT 1;
  RETURN v_caixa_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- ─── 5. Função: controlar IA por caixa ───────────────────────
-- Retorna TRUE se a IA deve responder nesta conversa.
-- Verifica: ia_ativa na conversa, ia_pausada_ate, ia_ativa na caixa.
CREATE OR REPLACE FUNCTION public.fn_ia_deve_responder(p_conversa_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_ia_ativa       BOOLEAN;
  v_ia_pausada_ate TIMESTAMPTZ;
  v_caixa_ia_ativa BOOLEAN;
BEGIN
  SELECT
    c.ia_ativa,
    c.ia_pausada_ate,
    COALESCE(cx.ia_ativa, FALSE)
  INTO v_ia_ativa, v_ia_pausada_ate, v_caixa_ia_ativa
  FROM public.crm_conversas c
  LEFT JOIN public.crm_caixas cx ON cx.id = c.caixa_id
  WHERE c.id = p_conversa_id;

  -- IA pausada temporariamente?
  IF v_ia_pausada_ate IS NOT NULL AND v_ia_pausada_ate > NOW() THEN
    RETURN FALSE;
  END IF;

  -- IA desativada na conversa?
  IF v_ia_ativa = FALSE THEN
    RETURN FALSE;
  END IF;

  -- IA desativada na caixa?
  IF v_caixa_ia_ativa = FALSE THEN
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

-- ─── 6. View: conversas ativas por agente ────────────────────
CREATE OR REPLACE VIEW public.vw_conversas_ativas AS
SELECT
  c.id,
  c.lead_id,
  l.nome                                          AS lead_nome,
  l.telefone                                      AS lead_telefone,
  c.canal,
  c.canal_id_externo,
  c.status,
  c.ia_ativa,
  c.ia_pausada_ate,
  c.caixa_id,
  cx.nome                                         AS caixa_nome,
  c.agente_responsavel_id,
  col.nome                                        AS agente_nome,
  c.ultima_interacao_em,
  EXTRACT(EPOCH FROM (NOW() - c.ultima_interacao_em))::INTEGER AS segundos_sem_resposta,
  c.created_at
FROM public.crm_conversas c
LEFT JOIN public.leads l          ON l.id = c.lead_id
LEFT JOIN public.crm_caixas cx    ON cx.id = c.caixa_id
LEFT JOIN public.colaboradores col ON col.id = c.agente_responsavel_id
WHERE c.status NOT IN ('resolvida', 'arquivada');

-- ─── 7. View: status de IA por caixa ─────────────────────────
CREATE OR REPLACE VIEW public.vw_ia_status_caixas AS
SELECT
  cx.id                                                         AS caixa_id,
  cx.nome                                                       AS caixa_nome,
  cx.canal,
  cx.ia_ativa                                                   AS ia_ativa_caixa,
  COUNT(c.id)                                                   AS total_conversas,
  COUNT(c.id) FILTER (WHERE c.ia_ativa = TRUE
    AND (c.ia_pausada_ate IS NULL OR c.ia_pausada_ate <= NOW())) AS conversas_com_ia,
  COUNT(c.id) FILTER (WHERE c.ia_ativa = FALSE
    OR (c.ia_pausada_ate IS NOT NULL AND c.ia_pausada_ate > NOW())) AS conversas_sem_ia
FROM public.crm_caixas cx
LEFT JOIN public.crm_conversas c ON c.caixa_id = cx.id
  AND c.status NOT IN ('resolvida', 'arquivada')
GROUP BY cx.id, cx.nome, cx.canal, cx.ia_ativa;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'Migration 007 — sincronização Chatwoot/n8n/IA por caixa aplicada em %', NOW();
END $$;


-- ============================================================
-- db/migrations/008_dashboards_visibilidade_perfil.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 008 — Dashboards e visibilidade por perfil
-- Versão: 1.0 | Data: 2026-04-01
--
-- O QUE ESTA MIGRATION FAZ:
--   Cria views de dashboard segmentadas por perfil de acesso:
--
--   1. vw_dashboard_gestor — visão completa para administrador,
--      diretor e gerente comercial: todos os leads, todos os
--      colaboradores, pipeline completo, métricas de conversão
--
--   2. vw_dashboard_consultor — visão restrita para consultor
--      de crédito e analista: apenas os próprios leads
--      (responsavel_id = colaborador logado)
--
--   3. vw_dashboard_captador — visão para captador externo:
--      apenas leads que ele captou (captador_id = colaborador)
--
--   4. vw_performance_colaboradores — ranking de performance
--      por colaborador (leads criados, convertidos, valor)
--
--   5. vw_funil_conversao — taxas de conversão entre etapas
--      do funil para análise de gargalos
--
--   6. vw_triagem_resumo — resumo da fila de triagem por status
--      e responsável
--
-- NOTA: A visibilidade por perfil é aplicada no servidor
--   (server/index.ts) via JWT. As views aqui são a base de dados
--   que o servidor consulta. O filtro por colaborador_id é
--   aplicado pelo servidor ao chamar as views.
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

-- ─── 1. View: dashboard do gestor ────────────────────────────
CREATE OR REPLACE VIEW public.vw_dashboard_gestor AS
SELECT
  -- Totais gerais
  COUNT(DISTINCT l.id)                                          AS total_leads,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'ganho')  AS leads_ganhos,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'perdido') AS leads_perdidos,
  COUNT(DISTINCT l.id) FILTER (WHERE l.created_at >= NOW() - INTERVAL '30 days') AS leads_ultimos_30d,
  COUNT(DISTINCT l.id) FILTER (WHERE l.created_at >= NOW() - INTERVAL '7 days')  AS leads_ultimos_7d,
  -- Pipeline
  COALESCE(SUM(l.valor_solicitado) FILTER (
    WHERE l.etapa_funil NOT IN ('perdido','inativo')
  ), 0)                                                         AS valor_pipeline_ativo,
  COALESCE(SUM(l.valor_solicitado) FILTER (
    WHERE l.etapa_funil = 'ganho'
  ), 0)                                                         AS valor_ganho_total,
  -- Triagem
  COUNT(DISTINCT t.id)                                          AS total_triagem,
  COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'pendente')    AS triagem_pendente,
  COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'convertido')  AS triagem_convertida,
  -- Conversas
  COUNT(DISTINCT c.id)                                          AS total_conversas,
  COUNT(DISTINCT c.id) FILTER (WHERE c.status NOT IN ('resolvida','arquivada')) AS conversas_ativas,
  -- Follow-ups
  COUNT(DISTINCT f.id) FILTER (
    WHERE f.status = 'pendente' AND f.agendado_para < NOW()
  )                                                             AS followups_atrasados,
  COUNT(DISTINCT f.id) FILTER (
    WHERE f.status = 'pendente'
    AND f.agendado_para BETWEEN NOW() AND NOW() + INTERVAL '24 hours'
  )                                                             AS followups_hoje
FROM public.leads l
CROSS JOIN (SELECT COUNT(*) AS cnt FROM public.triagem_leads) t_count
LEFT JOIN public.triagem_leads t ON TRUE
LEFT JOIN public.crm_conversas c ON c.lead_id = l.id
LEFT JOIN public.crm_followups f ON f.lead_id = l.id;

-- ─── 2. View: pipeline por etapa (para Kanban) ───────────────
CREATE OR REPLACE VIEW public.vw_pipeline_por_etapa AS
SELECT
  etapa_funil,
  COUNT(*)                                                      AS total_leads,
  COALESCE(SUM(valor_solicitado), 0)                            AS valor_total,
  COUNT(*) FILTER (WHERE temperatura = 'urgente')               AS urgentes,
  COUNT(*) FILTER (WHERE temperatura = 'quente')                AS quentes,
  COUNT(*) FILTER (WHERE proximo_followup < NOW())              AS followups_atrasados,
  AVG(score_efetivo)::INTEGER                                   AS score_medio,
  COUNT(*) FILTER (WHERE responsavel_id IS NULL)                AS sem_responsavel
FROM public.leads
WHERE etapa_funil NOT IN ('inativo')
GROUP BY etapa_funil
ORDER BY
  CASE etapa_funil
    WHEN 'novo'              THEN 1
    WHEN 'contato_feito'     THEN 2
    WHEN 'qualificado'       THEN 3
    WHEN 'proposta_enviada'  THEN 4
    WHEN 'negociacao'        THEN 5
    WHEN 'documentacao'      THEN 6
    WHEN 'aprovacao'         THEN 7
    WHEN 'ganho'             THEN 8
    WHEN 'perdido'           THEN 9
    ELSE 99
  END;

-- ─── 3. View: performance por colaborador ────────────────────
CREATE OR REPLACE VIEW public.vw_performance_colaboradores AS
SELECT
  col.id                                                        AS colaborador_id,
  col.nome,
  col.cargo,
  col.ativo,
  -- Leads sob responsabilidade
  COUNT(DISTINCT l.id)                                          AS total_leads,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'ganho')  AS leads_ganhos,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'perdido') AS leads_perdidos,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil NOT IN ('ganho','perdido','inativo')) AS leads_ativos,
  -- Valor
  COALESCE(SUM(l.valor_solicitado) FILTER (
    WHERE l.etapa_funil = 'ganho'
  ), 0)                                                         AS valor_ganho,
  COALESCE(SUM(l.valor_solicitado) FILTER (
    WHERE l.etapa_funil NOT IN ('perdido','inativo')
  ), 0)                                                         AS valor_pipeline,
  -- Taxa de conversão
  CASE
    WHEN COUNT(DISTINCT l.id) > 0
    THEN ROUND(
      COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'ganho')::NUMERIC
      / COUNT(DISTINCT l.id) * 100, 1
    )
    ELSE 0
  END                                                           AS taxa_conversao_pct,
  -- Follow-ups
  COUNT(DISTINCT f.id) FILTER (
    WHERE f.status = 'pendente' AND f.agendado_para < NOW()
  )                                                             AS followups_atrasados,
  -- Atividades recentes
  COUNT(DISTINCT a.id) FILTER (
    WHERE a.created_at >= NOW() - INTERVAL '7 days'
  )                                                             AS atividades_7d,
  -- Captações
  COUNT(DISTINCT lc.id)                                         AS leads_captados
FROM public.colaboradores col
LEFT JOIN public.leads l  ON l.responsavel_id = col.id
LEFT JOIN public.leads lc ON lc.captador_id = col.id
LEFT JOIN public.crm_followups f ON f.colaborador_id = col.id
LEFT JOIN public.crm_atividades a ON a.colaborador_id = col.id
GROUP BY col.id, col.nome, col.cargo, col.ativo;

-- ─── 4. View: funil de conversão ─────────────────────────────
CREATE OR REPLACE VIEW public.vw_funil_conversao AS
WITH etapas AS (
  SELECT unnest(ARRAY[
    'novo','contato_feito','qualificado','proposta_enviada',
    'negociacao','documentacao','aprovacao','ganho','perdido'
  ]) AS etapa,
  generate_series(1, 9) AS ordem
),
contagens AS (
  SELECT etapa_funil, COUNT(*) AS total
  FROM public.leads
  WHERE etapa_funil IS NOT NULL
  GROUP BY etapa_funil
)
SELECT
  e.etapa,
  e.ordem,
  COALESCE(c.total, 0)                                          AS total_leads,
  LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem)            AS total_etapa_anterior,
  CASE
    WHEN LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem) > 0
    THEN ROUND(
      COALESCE(c.total, 0)::NUMERIC
      / LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem) * 100, 1
    )
    ELSE NULL
  END                                                           AS taxa_retencao_pct
FROM etapas e
LEFT JOIN contagens c ON c.etapa_funil = e.etapa
ORDER BY e.ordem;

-- ─── 5. View: resumo da triagem ──────────────────────────────
CREATE OR REPLACE VIEW public.vw_triagem_resumo AS
SELECT
  t.status,
  COUNT(*)                                                      AS total,
  COUNT(*) FILTER (WHERE t.responsavel_id IS NOT NULL)          AS com_responsavel,
  COUNT(*) FILTER (WHERE t.responsavel_id IS NULL)              AS sem_responsavel,
  COUNT(*) FILTER (WHERE t.created_at >= NOW() - INTERVAL '24 hours') AS ultimas_24h,
  COUNT(*) FILTER (WHERE t.score_ia >= 70)                      AS score_alto,
  COUNT(*) FILTER (WHERE t.score_ia BETWEEN 40 AND 69)          AS score_medio,
  COUNT(*) FILTER (WHERE t.score_ia < 40 OR t.score_ia IS NULL) AS score_baixo
FROM public.triagem_leads t
GROUP BY t.status
ORDER BY
  CASE t.status
    WHEN 'pendente'          THEN 1
    WHEN 'possivel_cliente'  THEN 2
    WHEN 'curioso'           THEN 3
    WHEN 'sem_perfil'        THEN 4
    WHEN 'convertido'        THEN 5
    WHEN 'descartado'        THEN 6
    ELSE 99
  END;

-- ─── 6. View: leads por responsável (para consultor) ─────────
-- O servidor filtra por responsavel_id = colaborador logado
CREATE OR REPLACE VIEW public.vw_leads_por_responsavel AS
SELECT
  l.responsavel_id,
  col.nome                                                      AS responsavel_nome,
  col.cargo                                                     AS responsavel_cargo,
  l.id                                                          AS lead_id,
  l.nome                                                        AS lead_nome,
  l.telefone,
  l.empresa,
  l.etapa_funil,
  l.temperatura,
  l.score_efetivo,
  l.prioridade,
  l.valor_solicitado,
  l.proximo_followup,
  l.ultimo_contato_em,
  l.caixa_id,
  cx.nome                                                       AS caixa_nome,
  l.created_at,
  l.updated_at,
  EXTRACT(DAY FROM NOW() - COALESCE(l.ultimo_contato_em, l.created_at))::INTEGER AS dias_sem_contato
FROM public.leads l
LEFT JOIN public.colaboradores col ON col.id = l.responsavel_id
LEFT JOIN public.crm_caixas cx     ON cx.id = l.caixa_id
WHERE l.etapa_funil NOT IN ('inativo');

DO $$
BEGIN
  RAISE NOTICE 'Migration 008 — dashboards e visibilidade por perfil aplicados em %', NOW();
END $$;


-- ============================================================
-- db/migrations/009_padroniza_funil_enum.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 009 — Padronização do funil comercial
-- Objetivo: substituir a taxonomia legada por um enum controlado
-- sem perder dados e sem quebrar leituras existentes.
-- ============================================================

BEGIN;

-- ─── 1. Criar enum canônico do funil ──────────────────────────
DO $$ BEGIN
  CREATE TYPE etapa_funil_enum AS ENUM (
    'entrada',
    'triagem',
    'contato',
    'qualificacao',
    'documentos',
    'analise',
    'proposta',
    'negociacao',
    'ganho',
    'perdido',
    'reativacao',
    'carteira'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ─── 2. Garantir coluna existente e sem nulls ────────────────
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS etapa_funil TEXT;

UPDATE public.leads
SET etapa_funil = 'entrada'
WHERE etapa_funil IS NULL OR BTRIM(etapa_funil) = '';

-- ─── 3. Normalizar valores legados para a taxonomia nova ──────
UPDATE public.leads
SET etapa_funil = CASE LOWER(BTRIM(etapa_funil))
  WHEN 'novo' THEN 'entrada'
  WHEN 'entrada' THEN 'entrada'
  WHEN 'triagem' THEN 'triagem'
  WHEN 'contato_feito' THEN 'contato'
  WHEN 'contato' THEN 'contato'
  WHEN 'qualificado' THEN 'qualificacao'
  WHEN 'qualificacao' THEN 'qualificacao'
  WHEN 'documentacao' THEN 'documentos'
  WHEN 'documentos' THEN 'documentos'
  WHEN 'aprovacao' THEN 'analise'
  WHEN 'analise' THEN 'analise'
  WHEN 'proposta_enviada' THEN 'proposta'
  WHEN 'proposta' THEN 'proposta'
  WHEN 'negociacao' THEN 'negociacao'
  WHEN 'ganho' THEN 'ganho'
  WHEN 'perdido' THEN 'perdido'
  WHEN 'inativo' THEN 'reativacao'
  WHEN 'reativacao' THEN 'reativacao'
  WHEN 'carteira' THEN 'carteira'
  ELSE 'entrada'
END;

-- ─── 4. Remover check antigo sobre etapa_funil, se existir ────
DO $$
DECLARE
  v_constraint TEXT;
BEGIN
  FOR v_constraint IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.leads'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%etapa_funil%'
  LOOP
    EXECUTE format('ALTER TABLE public.leads DROP CONSTRAINT %I', v_constraint);
  END LOOP;
END $$;

-- ─── 5. Converter coluna para enum ────────────────────────────
ALTER TABLE public.leads
  ALTER COLUMN etapa_funil DROP DEFAULT;

ALTER TABLE public.leads
  ALTER COLUMN etapa_funil TYPE etapa_funil_enum
  USING (
    CASE LOWER(BTRIM(etapa_funil::TEXT))
      WHEN 'entrada' THEN 'entrada'::etapa_funil_enum
      WHEN 'triagem' THEN 'triagem'::etapa_funil_enum
      WHEN 'contato' THEN 'contato'::etapa_funil_enum
      WHEN 'qualificacao' THEN 'qualificacao'::etapa_funil_enum
      WHEN 'documentos' THEN 'documentos'::etapa_funil_enum
      WHEN 'analise' THEN 'analise'::etapa_funil_enum
      WHEN 'proposta' THEN 'proposta'::etapa_funil_enum
      WHEN 'negociacao' THEN 'negociacao'::etapa_funil_enum
      WHEN 'ganho' THEN 'ganho'::etapa_funil_enum
      WHEN 'perdido' THEN 'perdido'::etapa_funil_enum
      WHEN 'reativacao' THEN 'reativacao'::etapa_funil_enum
      WHEN 'carteira' THEN 'carteira'::etapa_funil_enum
      ELSE 'entrada'::etapa_funil_enum
    END
  );

ALTER TABLE public.leads
  ALTER COLUMN etapa_funil SET DEFAULT 'entrada'::etapa_funil_enum,
  ALTER COLUMN etapa_funil SET NOT NULL;

-- ─── 6. Recriar views operacionais dependentes do funil ───────
CREATE OR REPLACE VIEW public.vw_crm_pipeline AS
SELECT
  l.id,
  l.nome,
  l.telefone,
  l.email,
  l.empresa,
  l.tipo_pessoa,
  l.cpf_cnpj,
  l.cargo,
  l.cidade,
  l.estado,
  l.canal_origem,
  l.produto_interesse,
  l.valor_solicitado,
  l.prazo_meses,
  l.etapa_funil,
  l.temperatura,
  l.score_ia,
  l.score_manual,
  l.score_efetivo,
  l.tags,
  l.proximo_followup,
  l.ultimo_contato_em,
  l.resumo_ia,
  l.observacoes_ia,
  l.chatwoot_conv_id,
  l.responsavel_id,
  c.nome AS responsavel_nome,
  l.origem,
  l.status,
  l.created_at,
  l.updated_at,
  COALESCE(d.total_docs, 0) AS total_docs,
  COALESCE(d.docs_recebidos, 0) AS docs_recebidos,
  COALESCE(d.docs_pendentes_obrig, 0) AS docs_pendentes_obrig,
  a.titulo AS ultima_atividade,
  a.created_at AS ultima_atividade_em,
  EXTRACT(DAY FROM NOW() - COALESCE(l.ultimo_contato_em, l.created_at))::INTEGER AS dias_sem_contato
FROM public.leads l
LEFT JOIN public.colaboradores c ON c.id = l.responsavel_id
LEFT JOIN LATERAL (
  SELECT
    COUNT(*) AS total_docs,
    COUNT(*) FILTER (WHERE status IN ('recebido','aprovado')) AS docs_recebidos,
    COUNT(*) FILTER (WHERE obrigatorio AND status = 'pendente') AS docs_pendentes_obrig
  FROM public.crm_documentos
  WHERE lead_id = l.id
) d ON TRUE
LEFT JOIN LATERAL (
  SELECT titulo, created_at
  FROM public.crm_atividades
  WHERE lead_id = l.id
  ORDER BY created_at DESC
  LIMIT 1
) a ON TRUE;

CREATE OR REPLACE VIEW public.vw_crm_metricas AS
SELECT
  etapa_funil,
  temperatura,
  COUNT(*) AS total_leads,
  SUM(valor_solicitado) AS valor_total_pipeline,
  AVG(score_efetivo)::INTEGER AS score_medio,
  COUNT(*) FILTER (WHERE proximo_followup <= NOW()) AS followups_atrasados,
  COUNT(*) FILTER (WHERE dias_sem_contato > 7) AS sem_contato_7d
FROM public.vw_crm_pipeline
GROUP BY etapa_funil, temperatura;

CREATE OR REPLACE VIEW public.vw_pipeline_por_etapa AS
SELECT
  etapa_funil,
  COUNT(*) AS total_leads,
  COALESCE(SUM(valor_solicitado), 0) AS valor_total,
  COUNT(*) FILTER (WHERE temperatura = 'urgente') AS urgentes,
  COUNT(*) FILTER (WHERE temperatura = 'quente') AS quentes,
  COUNT(*) FILTER (WHERE proximo_followup < NOW()) AS followups_atrasados,
  AVG(score_efetivo)::INTEGER AS score_medio,
  COUNT(*) FILTER (WHERE responsavel_id IS NULL) AS sem_responsavel
FROM public.leads
GROUP BY etapa_funil
ORDER BY
  CASE etapa_funil
    WHEN 'entrada' THEN 1
    WHEN 'triagem' THEN 2
    WHEN 'contato' THEN 3
    WHEN 'qualificacao' THEN 4
    WHEN 'documentos' THEN 5
    WHEN 'analise' THEN 6
    WHEN 'proposta' THEN 7
    WHEN 'negociacao' THEN 8
    WHEN 'ganho' THEN 9
    WHEN 'perdido' THEN 10
    WHEN 'reativacao' THEN 11
    WHEN 'carteira' THEN 12
    ELSE 99
  END;

CREATE OR REPLACE VIEW public.vw_funil_conversao AS
WITH etapas AS (
  SELECT unnest(ARRAY[
    'entrada','triagem','contato','qualificacao','documentos','analise',
    'proposta','negociacao','ganho','perdido','reativacao','carteira'
  ]::TEXT[]) AS etapa,
  generate_series(1, 12) AS ordem
),
contagens AS (
  SELECT etapa_funil::TEXT AS etapa_funil, COUNT(*) AS total
  FROM public.leads
  WHERE etapa_funil IS NOT NULL
  GROUP BY etapa_funil
)
SELECT
  e.etapa,
  e.ordem,
  COALESCE(c.total, 0) AS total_leads,
  LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem) AS total_etapa_anterior,
  CASE
    WHEN LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem) > 0
    THEN ROUND(
      COALESCE(c.total, 0)::NUMERIC
      / LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem) * 100, 1
    )
    ELSE NULL
  END AS taxa_retencao_pct
FROM etapas e
LEFT JOIN contagens c ON c.etapa_funil = e.etapa
ORDER BY e.ordem;

COMMIT;


-- ============================================================
-- db/migrations/010_ownership_followup_base.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 010 — Ownership e controle básico de follow-up
-- Objetivo: garantir as colunas operacionais e preparar índices
-- sem remover compatibilidade com o schema já em produção.
-- ============================================================

BEGIN;

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS responsavel_id UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS proximo_followup TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ultimo_contato_em TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_leads_responsavel_id
  ON public.leads(responsavel_id);

CREATE INDEX IF NOT EXISTS idx_leads_proximo_followup
  ON public.leads(proximo_followup)
  WHERE proximo_followup IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_leads_ultimo_contato_em
  ON public.leads(ultimo_contato_em)
  WHERE ultimo_contato_em IS NOT NULL;

COMMIT;


-- ============================================================
-- db/migrations/011_tipo_registro_leads.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 011 — Tipo de registro em leads
-- Objetivo: classificar a origem funcional do registro sem alterar
-- os contratos atuais de API nem reescrever os fluxos existentes.
-- ============================================================

BEGIN;

ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS tipo_registro TEXT DEFAULT 'lead';

UPDATE public.leads
   SET tipo_registro = CASE
     WHEN origem IN ('simulador_publico', 'simulador-publico', 'site') THEN 'simulacao'
     WHEN origem = 'contato_site' THEN 'contato'
     WHEN etapa_funil = 'carteira' THEN 'carteira'
     ELSE COALESCE(tipo_registro, 'lead')
   END
 WHERE tipo_registro IS NULL
    OR tipo_registro NOT IN ('lead', 'simulacao', 'contato', 'cliente', 'carteira');

ALTER TABLE public.leads
  ALTER COLUMN tipo_registro SET DEFAULT 'lead';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conname = 'leads_tipo_registro_check'
  ) THEN
    ALTER TABLE public.leads
      ADD CONSTRAINT leads_tipo_registro_check
      CHECK (tipo_registro IN ('lead', 'simulacao', 'contato', 'cliente', 'carteira'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_leads_tipo_registro
  ON public.leads(tipo_registro);

COMMIT;


-- ============================================================
-- db/migrations/012_crm_logs_operacionais.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 012 — Logs operacionais do CRM
-- Objetivo: registrar eventos essenciais de alteração em leads
-- sem impactar os contratos existentes do monólito.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.crm_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES public.leads(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  acao TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_logs_lead_id
  ON public.crm_logs(lead_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crm_logs_usuario_id
  ON public.crm_logs(usuario_id, created_at DESC);

COMMIT;


-- ============================================================
-- db/migrations/013_colaboradores_perfil_operacional.sql
-- ============================================================

-- ============================================================
-- MIGRAÇÃO 013 — Perfis operacionais em colaboradores
-- Objetivo: adicionar uma camada compatível de perfil e flags de
-- visibilidade sem substituir a lógica legada baseada em cargo.
-- ============================================================

BEGIN;

ALTER TABLE public.colaboradores
  ADD COLUMN IF NOT EXISTS perfil TEXT,
  ADD COLUMN IF NOT EXISTS pode_atender_leads BOOLEAN,
  ADD COLUMN IF NOT EXISTS pode_ver_todos_leads BOOLEAN;

UPDATE public.colaboradores
   SET perfil = CASE
     WHEN LOWER(COALESCE(cargo, '')) IN ('administrador', 'admin', 'diretor') THEN 'admin'
     WHEN LOWER(COALESCE(cargo, '')) IN ('gerente comercial', 'gerente', 'gestor') THEN 'gestor'
     WHEN LOWER(COALESCE(cargo, '')) IN ('analista de crédito', 'analista de credito', 'analista') THEN 'analista'
     ELSE 'agente'
   END
 WHERE perfil IS NULL
    OR perfil NOT IN ('admin', 'gestor', 'agente', 'analista');

UPDATE public.colaboradores
   SET pode_atender_leads = CASE
     WHEN LOWER(COALESCE(cargo, '')) IN ('captador externo', 'estagiário', 'estagiario') THEN FALSE
     ELSE TRUE
   END
 WHERE pode_atender_leads IS NULL;

UPDATE public.colaboradores
   SET pode_ver_todos_leads = CASE
     WHEN LOWER(COALESCE(perfil, '')) IN ('admin', 'gestor') THEN TRUE
     ELSE FALSE
   END
 WHERE pode_ver_todos_leads IS NULL;

ALTER TABLE public.colaboradores
  ALTER COLUMN perfil SET DEFAULT 'agente',
  ALTER COLUMN pode_atender_leads SET DEFAULT TRUE,
  ALTER COLUMN pode_ver_todos_leads SET DEFAULT FALSE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conname = 'colaboradores_perfil_check'
  ) THEN
    ALTER TABLE public.colaboradores
      ADD CONSTRAINT colaboradores_perfil_check
      CHECK (perfil IN ('admin', 'gestor', 'agente', 'analista'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_colaboradores_perfil
  ON public.colaboradores(perfil);

CREATE INDEX IF NOT EXISTS idx_colaboradores_pode_ver_todos_leads
  ON public.colaboradores(pode_ver_todos_leads)
  WHERE pode_ver_todos_leads = TRUE;

COMMIT;


-- ============================================================
-- db/migrations/014_chatwoot_base_agente.sql
-- ============================================================

-- MIGRAÇÃO 014 — Base futura de integração Chatwoot por agente
-- Objetivo: preparar mapeamento operacional entre colaboradores e agentes do Chatwoot
-- e enriquecer crm_conversas com metadados de sincronismo sem alterar o fluxo atual.
-- Idempotente: seguro para reexecução.

BEGIN;

ALTER TABLE public.colaboradores
  ADD COLUMN IF NOT EXISTS chatwoot_agente_id INTEGER;

CREATE UNIQUE INDEX IF NOT EXISTS idx_colaboradores_chatwoot_agente_id
  ON public.colaboradores(chatwoot_agente_id)
  WHERE chatwoot_agente_id IS NOT NULL;

ALTER TABLE public.crm_conversas
  ADD COLUMN IF NOT EXISTS chatwoot_contact_id BIGINT,
  ADD COLUMN IF NOT EXISTS chatwoot_inbox_id BIGINT,
  ADD COLUMN IF NOT EXISTS chatwoot_assignee_id BIGINT,
  ADD COLUMN IF NOT EXISTS origem_atribuicao_agente TEXT,
  ADD COLUMN IF NOT EXISTS agente_ultima_atribuicao_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ultima_sincronizacao_chatwoot_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payload_ultimo_evento JSONB;

CREATE INDEX IF NOT EXISTS idx_crm_conversas_chatwoot_contact_id
  ON public.crm_conversas(chatwoot_contact_id)
  WHERE chatwoot_contact_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_crm_conversas_chatwoot_inbox_id
  ON public.crm_conversas(chatwoot_inbox_id)
  WHERE chatwoot_inbox_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_crm_conversas_chatwoot_assignee_id
  ON public.crm_conversas(chatwoot_assignee_id)
  WHERE chatwoot_assignee_id IS NOT NULL;

CREATE OR REPLACE VIEW public.vw_crm_chatwoot_operacional AS
SELECT
  c.id,
  c.lead_id,
  l.nome AS lead_nome,
  l.telefone AS lead_telefone,
  c.status,
  c.canal,
  c.canal_id_externo,
  c.caixa_id,
  cx.nome AS caixa_nome,
  c.chatwoot_contact_id,
  c.chatwoot_inbox_id,
  c.chatwoot_assignee_id,
  c.agente_responsavel_id,
  col.nome AS agente_nome,
  col.chatwoot_agente_id,
  c.origem_atribuicao_agente,
  c.agente_ultima_atribuicao_em,
  c.ultima_sincronizacao_chatwoot_em,
  c.ultima_interacao_em,
  c.created_at,
  c.updated_at
FROM public.crm_conversas c
LEFT JOIN public.leads l ON l.id = c.lead_id
LEFT JOIN public.crm_caixas cx ON cx.id = c.caixa_id
LEFT JOIN public.colaboradores col ON col.id = c.agente_responsavel_id;

COMMIT;


-- ============================================================
-- db/migrations/015_reconcilia_responsavel_chatwoot.sql
-- ============================================================

-- MIGRAÇÃO 015 — Reconciliação retroativa de ownership via Chatwoot
-- Atualiza leads.responsavel_id com base no agente mais recente por lead em crm_conversas.

BEGIN;

UPDATE leads l
SET responsavel_id = c.agente_responsavel_id,
    updated_at = NOW()
FROM (
  SELECT DISTINCT ON (lead_id)
    lead_id,
    agente_responsavel_id,
    updated_at,
    created_at
  FROM crm_conversas
  WHERE agente_responsavel_id IS NOT NULL
  ORDER BY lead_id, updated_at DESC NULLS LAST, created_at DESC NULLS LAST
) c
WHERE l.id = c.lead_id
  AND (
    l.responsavel_id IS NULL
    OR l.responsavel_id <> c.agente_responsavel_id
  );

COMMIT;


-- ============================================================
-- db/migrations/016_previsao_faturamento_e_contratos.sql
-- ============================================================

-- ============================================================
-- MIGRATION 016: Previsão de Faturamento + Gerador de Contratos
-- Data: 2026-04-29
-- Autor: Manus (via Master Prompt Claude)
-- ============================================================
-- ATENÇÃO: Esta migration NÃO é executada automaticamente.
-- O Desenvolvedor Chefe deve executar manualmente na VPS:
--   psql $DATABASE_URL < db/migrations/016_previsao_faturamento_e_contratos.sql
-- ============================================================

-- ── MÓDULO A: Histórico de Faturamento ──────────────────────
CREATE TABLE IF NOT EXISTS faturamento_historico (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id    UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  competencia   DATE NOT NULL, -- Sempre o primeiro dia do mês: '2025-01-01'
  valor         NUMERIC(15, 2) NOT NULL CHECK (valor >= 0),
  origem        TEXT NOT NULL DEFAULT 'manual' CHECK (origem IN ('manual', 'importado')),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(empresa_id, competencia)
);

CREATE INDEX IF NOT EXISTS idx_fat_historico_empresa ON faturamento_historico(empresa_id);
CREATE INDEX IF NOT EXISTS idx_fat_historico_competencia ON faturamento_historico(competencia DESC);

-- ── MÓDULO A: Previsões Geradas pela IA ─────────────────────
CREATE TABLE IF NOT EXISTS previsao_faturamento (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id              UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  gerada_em               TIMESTAMPTZ DEFAULT NOW(),
  modelo_usado            TEXT NOT NULL CHECK (modelo_usado IN ('prophet', 'arima')),
  horizonte_meses         INTEGER NOT NULL CHECK (horizonte_meses IN (12, 24)),
  capacidade_pgto_min     NUMERIC(15, 2) NOT NULL, -- 15% da média prevista
  capacidade_pgto_max     NUMERIC(15, 2) NOT NULL, -- 25% da média prevista
  payload_completo        JSONB NOT NULL, -- Array de {ds, yhat, yhat_lower, yhat_upper, is_historico}
  created_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_previsao_empresa ON previsao_faturamento(empresa_id);
CREATE INDEX IF NOT EXISTS idx_previsao_gerada ON previsao_faturamento(gerada_em DESC);

-- ── MÓDULO B: Parceiros Comerciais ──────────────────────────
CREATE TABLE IF NOT EXISTS parceiros_comerciais (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome       TEXT NOT NULL,
  cpf        TEXT NOT NULL,
  email      TEXT,
  telefone   TEXT,
  ativo      BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(cpf)
);

-- ── MÓDULO B: Contratos Gerados ─────────────────────────────
CREATE TABLE IF NOT EXISTS contratos_gerados (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id            UUID NOT NULL REFERENCES empresas(id) ON DELETE RESTRICT,
  parceiro_id           UUID REFERENCES parceiros_comerciais(id) ON DELETE SET NULL,
  lead_id               UUID REFERENCES leads(id) ON DELETE SET NULL,
  valor_referencia      NUMERIC(15, 2) NOT NULL,
  taxa_comissao         NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
  honorario_minimo_mes  NUMERIC(5, 2) NOT NULL DEFAULT 1.00,
  honorario_minimo_total NUMERIC(5, 2) NOT NULL DEFAULT 12.00,
  data_assinatura       DATE NOT NULL,
  foro_eleito           TEXT NOT NULL,
  status                TEXT NOT NULL DEFAULT 'gerado'
    CHECK (status IN ('gerado', 'assinado', 'cancelado')),
  pdf_path              TEXT, -- caminho relativo: /uploads/contratos/{uuid}.pdf
  hash_documento        TEXT UNIQUE, -- SHA-256 do PDF gerado
  payload_snapshot      JSONB NOT NULL, -- Snapshot de todos os dados no momento da geração
  criado_por            UUID REFERENCES colaboradores(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contratos_empresa ON contratos_gerados(empresa_id);
CREATE INDEX IF NOT EXISTS idx_contratos_status ON contratos_gerados(status);
CREATE INDEX IF NOT EXISTS idx_contratos_created ON contratos_gerados(created_at DESC);


-- ============================================================
-- db/migrations/017_contratos_novos_tipos.sql
-- ============================================================

-- ============================================================
-- MIGRATION 017: Contratos — Novos Tipos e Colunas
-- Data: 2026-04-30
-- Autor: Manus AI
-- ============================================================
-- ATENÇÃO: Esta migration NÃO é executada automaticamente.
-- Execute manualmente na VPS:
--   psql $DATABASE_URL < db/migrations/017_contratos_novos_tipos.sql
-- ============================================================
-- Esta migration é IDEMPOTENTE: usa ADD COLUMN IF NOT EXISTS,
-- DROP NOT NULL, DROP CONSTRAINT IF EXISTS e CREATE INDEX IF NOT EXISTS.
-- Pode ser executada em bancos que já possuam parte das colunas
-- (e.g., bancos que passaram pelo patch automático do startup).
-- ============================================================

-- ── 1. Tornar empresa_id opcional ────────────────────────────────────────────
-- Contratos de Limpa Nome PF, Limpa BACEN, Rating e Parceria Comercial
-- podem não ter empresa_id (ex.: contrato para lead/pessoa física ou parceiro).
ALTER TABLE contratos_gerados
  ALTER COLUMN empresa_id DROP NOT NULL;

-- ── 2. Adicionar coluna tipo_contrato ────────────────────────────────────────
-- Valores possíveis: assessoria | limpa_nome | limpa_bacen | rating | parceria_comercial
ALTER TABLE contratos_gerados
  ADD COLUMN IF NOT EXISTS tipo_contrato TEXT NOT NULL DEFAULT 'assessoria';

-- ── 3. Adicionar coluna cliente_tipo ─────────────────────────────────────────
-- Para contratos Limpa Nome: 'empresa' (PJ) ou 'lead' (PF)
ALTER TABLE contratos_gerados
  ADD COLUMN IF NOT EXISTS cliente_tipo TEXT;

-- ── 4. Adicionar coluna valor_contrato ───────────────────────────────────────
-- Valor cobrado ao cliente (Limpa Nome, Limpa BACEN, Rating).
-- Diferente de valor_referencia (usado apenas no contrato de Assessoria).
ALTER TABLE contratos_gerados
  ADD COLUMN IF NOT EXISTS valor_contrato NUMERIC(15, 2);

-- ── 5. Adicionar coluna condicao_pagamento ───────────────────────────────────
-- Texto livre com a condição de pagamento (ex.: "50% na assinatura + 50% na entrega")
ALTER TABLE contratos_gerados
  ADD COLUMN IF NOT EXISTS condicao_pagamento TEXT;

-- ── 6. Tornar valor_referencia opcional ──────────────────────────────────────
-- Contratos que não são de Assessoria não possuem valor_referencia.
-- O campo foi criado como NOT NULL na migration 016; tornamos opcional aqui.
ALTER TABLE contratos_gerados
  ALTER COLUMN valor_referencia DROP NOT NULL;

-- ── 7. Tornar taxa_comissao opcional ─────────────────────────────────────────
-- Apenas o contrato de Assessoria usa taxa_comissao.
-- Os demais tipos inserem 0 por compatibilidade.
ALTER TABLE contratos_gerados
  ALTER COLUMN taxa_comissao DROP NOT NULL;

-- ── 8. Tornar honorario_minimo_mes e honorario_minimo_total opcionais ─────────
ALTER TABLE contratos_gerados
  ALTER COLUMN honorario_minimo_mes DROP NOT NULL;

ALTER TABLE contratos_gerados
  ALTER COLUMN honorario_minimo_total DROP NOT NULL;

-- ── 9. Remover CHECK constraint de status (se existir) ───────────────────────
-- A migration 016 criou CHECK (status IN ('gerado','assinado','cancelado')).
-- Removemos para permitir extensão futura sem nova migration.
ALTER TABLE contratos_gerados
  DROP CONSTRAINT IF EXISTS contratos_gerados_status_check;

-- ── 10. Índices adicionais ────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_contratos_lead ON contratos_gerados(lead_id);
CREATE INDEX IF NOT EXISTS idx_contratos_tipo ON contratos_gerados(tipo_contrato);
CREATE INDEX IF NOT EXISTS idx_contratos_parceiro ON contratos_gerados(parceiro_id);

-- ── 11. Comentários descritivos ──────────────────────────────────────────────
COMMENT ON COLUMN contratos_gerados.tipo_contrato IS
  'Tipo do contrato: assessoria | limpa_nome | limpa_bacen | rating | parceria_comercial';

COMMENT ON COLUMN contratos_gerados.cliente_tipo IS
  'Para contratos Limpa Nome: empresa (PJ) ou lead (PF)';

COMMENT ON COLUMN contratos_gerados.valor_contrato IS
  'Valor cobrado ao cliente. Usado em Limpa Nome, Limpa BACEN e Rating.';

COMMENT ON COLUMN contratos_gerados.condicao_pagamento IS
  'Texto livre com a condição de pagamento acordada com o cliente.';

COMMENT ON COLUMN contratos_gerados.valor_referencia IS
  'Valor de referência para projeção de crédito. Usado apenas no contrato de Assessoria.';

-- ── FIM DA MIGRATION 017 ──────────────────────────────────────────────────────


-- ============================================================
-- db/migrations/018_contratos_prestadores_limpa_nome_bacen.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS public.prestadores_servico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_pessoa TEXT NOT NULL DEFAULT 'pj',
  razao_social TEXT,
  nome_fantasia TEXT,
  nome TEXT,
  cnpj TEXT,
  cpf TEXT,
  email TEXT,
  telefone TEXT,
  endereco TEXT,
  cidade TEXT,
  uf TEXT,
  cep TEXT,
  representante_nome TEXT,
  representante_cpf TEXT,
  representante_cargo TEXT,
  observacoes TEXT,
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.contratos_gerados
  ADD COLUMN IF NOT EXISTS contratada_id UUID
  REFERENCES public.prestadores_servico(id) ON DELETE SET NULL;

ALTER TABLE public.contratos_gerados
  ADD COLUMN IF NOT EXISTS contratada_snapshot JSONB;

ALTER TABLE public.contratos_gerados
  ADD COLUMN IF NOT EXISTS responsavel_contrato_id UUID
  REFERENCES public.colaboradores(id) ON DELETE SET NULL;

ALTER TABLE public.contratos_gerados
  ADD COLUMN IF NOT EXISTS responsavel_contrato_snapshot JSONB;

CREATE INDEX IF NOT EXISTS idx_prestadores_servico_ativo
  ON public.prestadores_servico(ativo);

CREATE INDEX IF NOT EXISTS idx_contratos_contratada
  ON public.contratos_gerados(contratada_id);

CREATE INDEX IF NOT EXISTS idx_contratos_responsavel_contrato
  ON public.contratos_gerados(responsavel_contrato_id);

INSERT INTO public.prestadores_servico (
  tipo_pessoa,
  razao_social,
  nome_fantasia,
  cnpj,
  endereco,
  cidade,
  uf,
  cep,
  representante_nome,
  representante_cargo,
  ativo
)
SELECT
  'pj',
  'DESTRAVA CREDITO LTDA',
  'Destrava Crédito',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  true
WHERE NOT EXISTS (
  SELECT 1
  FROM public.prestadores_servico
  WHERE razao_social = 'DESTRAVA CREDITO LTDA'
);


-- ============================================================
-- db/migrations/020_modulo_contratos_parceiros_usuarios_completo.sql
-- ============================================================

-- Migration 020: módulo completo de contratos, parceiros, responsáveis e usuários
-- Idempotente: não apaga dados, não renomeia tabelas e usa apenas ADD COLUMN/CREATE TABLE/CREATE INDEX se necessário.

BEGIN;

-- Parceiros/contratadas/prestadores: mantém a tabela histórica e adiciona campos de cadastro, identidade visual e PDF.
CREATE TABLE IF NOT EXISTS public.prestadores_servico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_pessoa TEXT NOT NULL DEFAULT 'pj',
  razao_social TEXT,
  nome_fantasia TEXT,
  nome TEXT,
  cnpj TEXT,
  cpf TEXT,
  email TEXT,
  telefone TEXT,
  endereco TEXT,
  cidade TEXT,
  uf TEXT,
  cep TEXT,
  representante_nome TEXT,
  representante_cpf TEXT,
  representante_cargo TEXT,
  observacoes TEXT,
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS rg TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS data_nascimento DATE;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS estado_civil TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS profissao TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS numero TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS complemento TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS bairro TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS cargo TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS cor_primaria TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS cor_secundaria TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS texto_cabecalho TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS texto_rodape TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS rodape_html TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS mostrar_logo_contrato BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS origem_cadastro TEXT;
ALTER TABLE public.prestadores_servico ADD COLUMN IF NOT EXISTS metadados JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_prestadores_servico_tipo_ativo ON public.prestadores_servico(tipo_pessoa, ativo);
CREATE INDEX IF NOT EXISTS idx_prestadores_servico_documentos ON public.prestadores_servico(cnpj, cpf);

-- Responsáveis pessoa física vinculados a pessoas jurídicas parceiras/contratadas.
CREATE TABLE IF NOT EXISTS public.pessoa_juridica_responsaveis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestador_id UUID REFERENCES public.prestadores_servico(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  cpf TEXT,
  rg TEXT,
  email TEXT,
  telefone TEXT,
  cargo TEXT,
  profissao TEXT,
  estado_civil TEXT,
  nacionalidade TEXT,
  endereco TEXT,
  numero TEXT,
  complemento TEXT,
  bairro TEXT,
  cidade TEXT,
  uf TEXT,
  cep TEXT,
  principal BOOLEAN NOT NULL DEFAULT false,
  ativo BOOLEAN NOT NULL DEFAULT true,
  observacoes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pj_responsaveis_prestador ON public.pessoa_juridica_responsaveis(prestador_id, ativo);
CREATE INDEX IF NOT EXISTS idx_pj_responsaveis_cpf ON public.pessoa_juridica_responsaveis(cpf);

-- Contratos gerados: novos vínculos/snapshots administrativos sem remover colunas antigas.
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS parceiro_snapshot JSONB;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS parceiro_responsavel_id UUID REFERENCES public.pessoa_juridica_responsaveis(id) ON DELETE SET NULL;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS parceiro_responsavel_snapshot JSONB;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS contratante_tipo TEXT;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS contratante_pf_id UUID;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS contratante_pj_id UUID;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS contratante_snapshot JSONB;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS contratante_responsavel_id UUID REFERENCES public.pessoa_juridica_responsaveis(id) ON DELETE SET NULL;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS contratante_responsavel_snapshot JSONB;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS responsavel_interno_id UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS responsavel_interno_snapshot JSONB;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS local_assinatura TEXT;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS observacoes TEXT;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS dados_editaveis JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS pdf_regenerado_em TIMESTAMPTZ;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS assinado_em TIMESTAMPTZ;
ALTER TABLE public.contratos_gerados ADD COLUMN IF NOT EXISTS assinado_pdf_path TEXT;

CREATE INDEX IF NOT EXISTS idx_contratos_gerados_contratante_pf ON public.contratos_gerados(contratante_pf_id);
CREATE INDEX IF NOT EXISTS idx_contratos_gerados_contratante_pj ON public.contratos_gerados(contratante_pj_id);
CREATE INDEX IF NOT EXISTS idx_contratos_gerados_status_tipo ON public.contratos_gerados(status, tipo_contrato);

-- Colaboradores: dados pessoais, perfil e recuperação/redefinição de senha.
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS cpf TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS rg TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS data_nascimento DATE;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS estado_civil TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS profissao TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS endereco TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS numero TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS complemento TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS bairro TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS cidade TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS uf TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS cep TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS assinatura_url TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS precisa_redefinir_senha BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS ultimo_reset_senha_em TIMESTAMPTZ;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS reset_senha_solicitado_em TIMESTAMPTZ;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS reset_senha_token_hash TEXT;
ALTER TABLE public.colaboradores ADD COLUMN IF NOT EXISTS reset_senha_expira_em TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS idx_colaboradores_email_lower_unique ON public.colaboradores(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_colaboradores_reset_senha ON public.colaboradores(reset_senha_solicitado_em) WHERE reset_senha_solicitado_em IS NOT NULL;

COMMIT;


-- ============================================================
-- db/migrations/021_chatwoot_crm_atividades_webhook.sql
-- ============================================================

-- ─── Migration 021: Chatwoot → CRM atividades e deduplicação por email ──────
-- Expande o CHECK constraint de crm_atividades.tipo para incluir tipos de WhatsApp
-- Garante que leads.email existe para deduplicação
-- Garante que crm_atividades.origem_ia existe

BEGIN;

-- 1. Garantir campo email em leads (já existe no schema base, mas por segurança)
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. Garantir campo origem_ia em crm_atividades
ALTER TABLE public.crm_atividades
  ADD COLUMN IF NOT EXISTS origem_ia BOOLEAN DEFAULT FALSE;

-- 3. Garantir campo concluido em crm_atividades
ALTER TABLE public.crm_atividades
  ADD COLUMN IF NOT EXISTS concluido BOOLEAN DEFAULT TRUE;

-- 4. Expandir o CHECK constraint de crm_atividades.tipo para incluir tipos de WhatsApp
--    (whatsapp_mensagem, whatsapp_inicio, whatsapp_encerrado)
DO $$
BEGIN
  -- Remover constraint existente se existir
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'crm_atividades'
      AND constraint_name = 'crm_atividades_tipo_check'
      AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.crm_atividades DROP CONSTRAINT crm_atividades_tipo_check;
  END IF;

  -- Adicionar constraint expandida
  ALTER TABLE public.crm_atividades
    ADD CONSTRAINT crm_atividades_tipo_check
    CHECK (tipo IN (
      'nota','ligacao','whatsapp','email','reuniao','proposta','documento',
      'status_change','ia_acao','followup','outro',
      'whatsapp_mensagem','whatsapp_inicio','whatsapp_encerrado'
    ));
END;
$$;

-- 5. Índice para deduplicação por email em leads
CREATE INDEX IF NOT EXISTS idx_leads_email_lower
  ON public.leads (LOWER(email))
  WHERE email IS NOT NULL AND email <> '';

-- 6. Índice para crm_atividades por tipo (para consultas de WhatsApp)
CREATE INDEX IF NOT EXISTS idx_crm_atividades_tipo_whatsapp
  ON public.crm_atividades (lead_id, created_at DESC)
  WHERE tipo IN ('whatsapp_mensagem','whatsapp_inicio','whatsapp_encerrado','whatsapp');

COMMIT;


-- ============================================================
-- db/migrations/022_acompanhamento_bancario.sql
-- ============================================================

-- 022_acompanhamento_bancario.sql
-- Módulo de Acompanhamento Bancário Semanal para preparação de crédito.
-- Executar manualmente no PostgreSQL antes/ao subir a feature.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS acompanhamentos_bancarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  empresa_id UUID NULL REFERENCES empresas(id) ON DELETE SET NULL,
  lead_id UUID NULL REFERENCES leads(id) ON DELETE SET NULL,

  nome_empresa TEXT NOT NULL,
  cnpj TEXT,
  tipo_cliente TEXT NOT NULL DEFAULT 'pj',

  banco_observado TEXT,
  agencia TEXT,
  conta TEXT,

  objetivo_credito TEXT,
  valor_credito_pretendido NUMERIC(14,2),
  linha_credito_pretendida TEXT,

  status TEXT NOT NULL DEFAULT 'em_acompanhamento',
  etapa TEXT NOT NULL DEFAULT 'inicio',

  data_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
  data_fim_prevista DATE,
  prorrogado BOOLEAN NOT NULL DEFAULT false,
  data_prorrogacao DATE,
  data_fim_prorrogada DATE,

  responsavel_id UUID NULL REFERENCES colaboradores(id) ON DELETE SET NULL,

  rating_bacen_inicial TEXT,
  rating_interno_inicial TEXT,
  rating_bacen_atual TEXT,
  rating_interno_atual TEXT,

  faturamento_anual NUMERIC(14,2),
  media_mensal NUMERIC(14,2),
  margem_30 NUMERIC(14,2),

  proxima_atualizacao DATE,
  ultima_atualizacao_em TIMESTAMP,

  cliente_notificado_em TIMESTAMP,
  ultimo_lembrete_interno_em TIMESTAMP,

  observacoes_iniciais TEXT,
  observacoes_finais TEXT,

  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS acompanhamento_bancario_atualizacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES acompanhamentos_bancarios(id) ON DELETE CASCADE,

  numero_semana INTEGER NOT NULL,
  periodo TEXT,
  data_referencia_inicio DATE,
  data_referencia_fim DATE,
  data_atualizacao DATE NOT NULL DEFAULT CURRENT_DATE,

  entrada_maquina NUMERIC(14,2) NOT NULL DEFAULT 0,
  entrada_pix NUMERIC(14,2) NOT NULL DEFAULT 0,
  entrada_boleto NUMERIC(14,2) NOT NULL DEFAULT 0,
  entrada_ted NUMERIC(14,2) NOT NULL DEFAULT 0,
  entrada_dinheiro NUMERIC(14,2) NOT NULL DEFAULT 0,
  outras_entradas NUMERIC(14,2) NOT NULL DEFAULT 0,

  total_entradas NUMERIC(14,2) GENERATED ALWAYS AS (
    entrada_maquina + entrada_pix + entrada_boleto + entrada_ted + entrada_dinheiro + outras_entradas
  ) STORED,

  total_saidas NUMERIC(14,2) NOT NULL DEFAULT 0,
  saldo_semanal NUMERIC(14,2) GENERATED ALWAYS AS (
    entrada_maquina + entrada_pix + entrada_boleto + entrada_ted + entrada_dinheiro + outras_entradas - total_saidas
  ) STORED,

  saldo_medio NUMERIC(14,2) NOT NULL DEFAULT 0,
  saldo_final NUMERIC(14,2) NOT NULL DEFAULT 0,
  quantidade_transacoes INTEGER NOT NULL DEFAULT 0,

  rating_bacen TEXT,
  rating_interno TEXT,

  restricao_scr TEXT,
  restricao_cenprot TEXT,
  restricao_serasa TEXT,
  cnd_regular TEXT,
  pld_aml TEXT,
  operacao_suspeita_coaf TEXT,

  restricao_nova BOOLEAN NOT NULL DEFAULT false,
  devolucao_ou_estorno BOOLEAN NOT NULL DEFAULT false,
  ocorrencia_negativa BOOLEAN NOT NULL DEFAULT false,

  status TEXT NOT NULL DEFAULT 'registrada',
  analise_semana TEXT,
  orientacao_cliente TEXT,
  proxima_acao TEXT,

  criado_por UUID NULL REFERENCES colaboradores(id) ON DELETE SET NULL,

  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),

  UNIQUE (acompanhamento_id, numero_semana)
);

CREATE TABLE IF NOT EXISTS acompanhamento_bancario_alertas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES acompanhamentos_bancarios(id) ON DELETE CASCADE,

  tipo TEXT NOT NULL,
  titulo TEXT NOT NULL,
  mensagem TEXT,
  data_alerta DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pendente',
  responsavel_id UUID NULL REFERENCES colaboradores(id) ON DELETE SET NULL,

  created_at TIMESTAMP NOT NULL DEFAULT now(),
  resolvido_em TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_acomp_banc_empresa ON acompanhamentos_bancarios(empresa_id);
CREATE INDEX IF NOT EXISTS idx_acomp_banc_status ON acompanhamentos_bancarios(status);
CREATE INDEX IF NOT EXISTS idx_acomp_banc_proxima ON acompanhamentos_bancarios(proxima_atualizacao);
CREATE INDEX IF NOT EXISTS idx_acomp_banc_resp ON acompanhamentos_bancarios(responsavel_id);
CREATE INDEX IF NOT EXISTS idx_acomp_banc_updates_acomp ON acompanhamento_bancario_atualizacoes(acompanhamento_id);
CREATE INDEX IF NOT EXISTS idx_acomp_banc_alertas_status ON acompanhamento_bancario_alertas(status, data_alerta);

CREATE OR REPLACE FUNCTION atualizar_updated_at_acompanhamento_bancario()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_acomp_banc_updated ON acompanhamentos_bancarios;
CREATE TRIGGER trg_acomp_banc_updated
BEFORE UPDATE ON acompanhamentos_bancarios
FOR EACH ROW
EXECUTE FUNCTION atualizar_updated_at_acompanhamento_bancario();

DROP TRIGGER IF EXISTS trg_acomp_banc_atualizacoes_updated ON acompanhamento_bancario_atualizacoes;
CREATE TRIGGER trg_acomp_banc_atualizacoes_updated
BEFORE UPDATE ON acompanhamento_bancario_atualizacoes
FOR EACH ROW
EXECUTE FUNCTION atualizar_updated_at_acompanhamento_bancario();


-- ============================================================
-- db/migrations/023_permissao_gestor_credito_acompanhamento.sql
-- ============================================================

-- 023_permissao_gestor_credito_acompanhamento.sql
-- Permissão de acesso ao módulo Acompanhamento Bancário para Gestor de Crédito ou superior.

ALTER TABLE colaboradores
ADD COLUMN IF NOT EXISTS acesso_acompanhamento_bancario BOOLEAN NOT NULL DEFAULT false;

UPDATE colaboradores
SET role = 'gestor_credito'
WHERE LOWER(COALESCE(role, '')) IN ('gerente', 'gerente_credito', 'gestor de credito', 'gestor de crédito');

UPDATE colaboradores
SET acesso_acompanhamento_bancario = true
WHERE LOWER(COALESCE(role, '')) IN ('admin', 'super_admin', 'superadmin', 'gestor_credito');

UPDATE colaboradores
SET acesso_acompanhamento_bancario = false
WHERE LOWER(COALESCE(role, '')) NOT IN ('admin', 'super_admin', 'superadmin', 'gestor_credito');

CREATE INDEX IF NOT EXISTS idx_colaboradores_acesso_acompanhamento_bancario
ON colaboradores (acesso_acompanhamento_bancario);

CREATE INDEX IF NOT EXISTS idx_colaboradores_role
ON colaboradores (role);


-- ============================================================
-- db/migrations/024_acompanhamento_financeiro_semanal.sql
-- ============================================================

-- ============================================================
-- MIGRATION 024: Módulo de Acompanhamento Financeiro Semanal
-- Data: 2026-05-15
-- Descrição: Cria as tabelas para controle de coerência financeira
--            semanal com base no faturamento anual declarado.
-- ============================================================
-- ATENÇÃO: Esta migration NÃO é executada automaticamente.
-- O Desenvolvedor Chefe deve executar manualmente na VPS:
--   psql $DATABASE_URL < db/migrations/024_acompanhamento_financeiro_semanal.sql
-- ============================================================

-- ── TABELA 1: Configuração de Acompanhamento Financeiro ──────
-- Armazena o faturamento anual declarado e o percentual
-- operacional configurável por empresa.
CREATE TABLE IF NOT EXISTS acompanhamento_financeiro_config (
  id                          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id                  UUID         NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  faturamento_anual_declarado NUMERIC(15,2) NOT NULL CHECK (faturamento_anual_declarado >= 0),
  percentual_operacional      NUMERIC(5,2) NOT NULL DEFAULT 30.00
                                CHECK (percentual_operacional > 0 AND percentual_operacional <= 100),
  limite_anual                NUMERIC(15,2) GENERATED ALWAYS AS
                                (ROUND(faturamento_anual_declarado * percentual_operacional / 100, 2))
                                STORED,
  ativo                       BOOLEAN      NOT NULL DEFAULT TRUE,
  criado_por                  UUID         REFERENCES colaboradores(id) ON DELETE SET NULL,
  created_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE(empresa_id)
);

CREATE INDEX IF NOT EXISTS idx_af_config_empresa ON acompanhamento_financeiro_config(empresa_id);
CREATE INDEX IF NOT EXISTS idx_af_config_ativo   ON acompanhamento_financeiro_config(ativo);

-- ── TABELA 2: Acompanhamento Semanal ─────────────────────────
-- Registra os dados de cada semana analisada por empresa.
CREATE TABLE IF NOT EXISTS acompanhamento_financeiro_semanal (
  id                      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id              UUID         NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  config_id               UUID         REFERENCES acompanhamento_financeiro_config(id) ON DELETE SET NULL,
  ano                     INTEGER      NOT NULL CHECK (ano >= 2020 AND ano <= 2100),
  mes                     INTEGER      NOT NULL CHECK (mes >= 1 AND mes <= 12),
  numero_semana           INTEGER      NOT NULL CHECK (numero_semana >= 1 AND numero_semana <= 6),
  semana_inicio           DATE         NOT NULL,
  semana_fim              DATE         NOT NULL,
  saldo_inicial           NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (saldo_inicial >= 0),
  total_entradas          NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (total_entradas >= 0),
  total_saidas            NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (total_saidas >= 0),
  saldo_final             NUMERIC(15,2) NOT NULL DEFAULT 0,
  saldo_medio             NUMERIC(15,2) NOT NULL DEFAULT 0,
  limite_semanal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  limite_mensal_referencia  NUMERIC(15,2) NOT NULL DEFAULT 0,
  limite_anual_referencia   NUMERIC(15,2) NOT NULL DEFAULT 0,
  acumulado_mensal        NUMERIC(15,2) NOT NULL DEFAULT 0,
  acumulado_anual         NUMERIC(15,2) NOT NULL DEFAULT 0,
  percentual_uso_semana   NUMERIC(7,2)  NOT NULL DEFAULT 0,
  percentual_uso_mes      NUMERIC(7,2)  NOT NULL DEFAULT 0,
  percentual_uso_ano      NUMERIC(7,2)  NOT NULL DEFAULT 0,
  status                  TEXT         NOT NULL DEFAULT 'aguardando_atualizacao'
                            CHECK (status IN (
                              'dentro_da_referencia',
                              'atencao_leve',
                              'atencao_media',
                              'incompativel',
                              'critico',
                              'sem_documentacao',
                              'aguardando_atualizacao',
                              'regularizado'
                            )),
  diagnostico             TEXT,
  observacoes             TEXT,
  criado_por              UUID         REFERENCES colaboradores(id) ON DELETE SET NULL,
  created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_semana_datas CHECK (semana_fim >= semana_inicio),
  UNIQUE(empresa_id, ano, mes, numero_semana)
);

CREATE INDEX IF NOT EXISTS idx_af_semanal_empresa  ON acompanhamento_financeiro_semanal(empresa_id);
CREATE INDEX IF NOT EXISTS idx_af_semanal_periodo  ON acompanhamento_financeiro_semanal(ano, mes);
CREATE INDEX IF NOT EXISTS idx_af_semanal_status   ON acompanhamento_financeiro_semanal(status);
CREATE INDEX IF NOT EXISTS idx_af_semanal_criado   ON acompanhamento_financeiro_semanal(created_at DESC);

-- ── TABELA 3: Movimentações da Semana ────────────────────────
-- Registra cada movimentação (entrada ou saída) de uma semana.
CREATE TABLE IF NOT EXISTS acompanhamento_financeiro_movimentacoes (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID         NOT NULL REFERENCES acompanhamento_financeiro_semanal(id) ON DELETE CASCADE,
  empresa_id        UUID         NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  data_movimento    DATE         NOT NULL,
  tipo              TEXT         NOT NULL CHECK (tipo IN ('entrada', 'saida')),
  categoria         TEXT,
  descricao         TEXT,
  valor             NUMERIC(15,2) NOT NULL CHECK (valor > 0),
  comprovante_url   TEXT,
  criado_por        UUID         REFERENCES colaboradores(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_af_mov_acomp    ON acompanhamento_financeiro_movimentacoes(acompanhamento_id);
CREATE INDEX IF NOT EXISTS idx_af_mov_empresa  ON acompanhamento_financeiro_movimentacoes(empresa_id);
CREATE INDEX IF NOT EXISTS idx_af_mov_data     ON acompanhamento_financeiro_movimentacoes(data_movimento);
CREATE INDEX IF NOT EXISTS idx_af_mov_tipo     ON acompanhamento_financeiro_movimentacoes(tipo);

-- ── TABELA 4: Saldos Diários ──────────────────────────────────
-- Registra o saldo ao final de cada dia da semana analisada.
CREATE TABLE IF NOT EXISTS acompanhamento_financeiro_saldos_diarios (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID         NOT NULL REFERENCES acompanhamento_financeiro_semanal(id) ON DELETE CASCADE,
  empresa_id        UUID         NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  data_referencia   DATE         NOT NULL,
  saldo_dia         NUMERIC(15,2) NOT NULL DEFAULT 0,
  criado_por        UUID         REFERENCES colaboradores(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE(acompanhamento_id, data_referencia)
);

CREATE INDEX IF NOT EXISTS idx_af_saldos_acomp  ON acompanhamento_financeiro_saldos_diarios(acompanhamento_id);
CREATE INDEX IF NOT EXISTS idx_af_saldos_data   ON acompanhamento_financeiro_saldos_diarios(data_referencia);

-- ── TRIGGERS: updated_at automático ──────────────────────────
CREATE OR REPLACE FUNCTION atualizar_updated_at_af()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_af_config_updated ON acompanhamento_financeiro_config;
CREATE TRIGGER trg_af_config_updated
  BEFORE UPDATE ON acompanhamento_financeiro_config
  FOR EACH ROW EXECUTE FUNCTION atualizar_updated_at_af();

DROP TRIGGER IF EXISTS trg_af_semanal_updated ON acompanhamento_financeiro_semanal;
CREATE TRIGGER trg_af_semanal_updated
  BEFORE UPDATE ON acompanhamento_financeiro_semanal
  FOR EACH ROW EXECUTE FUNCTION atualizar_updated_at_af();

DROP TRIGGER IF EXISTS trg_af_mov_updated ON acompanhamento_financeiro_movimentacoes;
CREATE TRIGGER trg_af_mov_updated
  BEFORE UPDATE ON acompanhamento_financeiro_movimentacoes
  FOR EACH ROW EXECUTE FUNCTION atualizar_updated_at_af();

DROP TRIGGER IF EXISTS trg_af_saldos_updated ON acompanhamento_financeiro_saldos_diarios;
CREATE TRIGGER trg_af_saldos_updated
  BEFORE UPDATE ON acompanhamento_financeiro_saldos_diarios
  FOR EACH ROW EXECUTE FUNCTION atualizar_updated_at_af();

-- ── PERMISSÃO: Coluna de acesso ao módulo financeiro ─────────
-- Adiciona coluna de permissão específica para o módulo,
-- seguindo o padrão de acesso_acompanhamento_bancario.
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS acesso_acompanhamento_financeiro BOOLEAN DEFAULT FALSE;

-- Administradores e gestores de crédito recebem acesso automático
UPDATE colaboradores
SET acesso_acompanhamento_financeiro = TRUE
WHERE
  LOWER(TRIM(cargo)) IN ('administrador', 'admin', 'diretor', 'gestor_credito', 'gestor de credito')
  OR LOWER(TRIM(perfil)) IN ('administrador', 'admin', 'diretor', 'gestor_credito', 'gestor de credito');

-- ── FIM DA MIGRATION 024 ──────────────────────────────────────


-- ============================================================
-- db/migrations/024_compensacao_acompanhamento_bancario.sql
-- ============================================================

-- 024_compensacao_acompanhamento_bancario.sql
ALTER TABLE acompanhamento_bancario_atualizacoes
ADD COLUMN IF NOT EXISTS media_mensal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS limite_mensal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS media_semanal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS quantidade_semanas_mes INTEGER NOT NULL DEFAULT 4,
ADD COLUMN IF NOT EXISTS compensacao_semana_anterior NUMERIC(15,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS entrada_com_compensacao NUMERIC(15,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS diferenca_referencia_semanal NUMERIC(15,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS compensacao_necessaria_proxima NUMERIC(15,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS percentual_limite_semanal NUMERIC(8,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS percentual_limite_mensal NUMERIC(8,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS percentual_limite_anual NUMERIC(8,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS alerta_aderencia BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS motivo_alerta_aderencia TEXT,
ADD COLUMN IF NOT EXISTS diagnostico_compensacao TEXT,
ADD COLUMN IF NOT EXISTS status_compensacao TEXT;

CREATE TABLE IF NOT EXISTS acompanhamento_compensacoes_historico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES acompanhamentos_bancarios(id) ON DELETE CASCADE,
  numero_semana INTEGER NOT NULL,
  data_referencia_inicio DATE,
  data_referencia_fim DATE,
  entrada_realizada NUMERIC(15,2) NOT NULL DEFAULT 0,
  media_mensal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  limite_mensal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  media_semanal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  quantidade_semanas_mes INTEGER NOT NULL DEFAULT 4,
  compensacao_anterior NUMERIC(15,2) NOT NULL DEFAULT 0,
  entrada_com_compensacao NUMERIC(15,2) NOT NULL DEFAULT 0,
  diferenca_referencia_semanal NUMERIC(15,2) NOT NULL DEFAULT 0,
  compensacao_necessaria NUMERIC(15,2) NOT NULL DEFAULT 0,
  percentual_limite_semanal NUMERIC(8,2) NOT NULL DEFAULT 0,
  percentual_limite_mensal NUMERIC(8,2) NOT NULL DEFAULT 0,
  percentual_limite_anual NUMERIC(8,2) NOT NULL DEFAULT 0,
  alerta_aderencia BOOLEAN NOT NULL DEFAULT false,
  motivo_alerta TEXT,
  criado_por UUID NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_acomp_hist_acomp ON acompanhamento_compensacoes_historico(acompanhamento_id);
CREATE INDEX IF NOT EXISTS idx_acomp_hist_semana ON acompanhamento_compensacoes_historico(numero_semana);
CREATE INDEX IF NOT EXISTS idx_acomp_hist_alerta ON acompanhamento_compensacoes_historico(alerta_aderencia);
CREATE INDEX IF NOT EXISTS idx_acomp_hist_created ON acompanhamento_compensacoes_historico(created_at);


-- ============================================================
-- db/migrations/025_compensacao_aderencia_bancario.sql
-- ============================================================

-- ============================================================
-- MIGRATION 025: Compensação e Aderência Financeira
-- Módulo: Acompanhamento Bancário
-- Compatibilidade: idempotente (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
-- Não remove dados existentes. Não altera colunas existentes.
-- ============================================================

-- ── 1. Adicionar campos de referência e compensação à tabela de atualizações ──
ALTER TABLE acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref       NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao     NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base     NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao    NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base     NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao   NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS semanas_no_mes              INTEGER DEFAULT 4,
  ADD COLUMN IF NOT EXISTS acumulado_mensal            NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_anual             NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana         NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana      NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal   NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS semanas_restantes_mes       INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica          NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima       NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal      NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal       NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual        NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia            TEXT DEFAULT 'dentro_da_faixa',
  ADD COLUMN IF NOT EXISTS alerta_aderencia            BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS motivo_alerta_aderencia     TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico         TEXT;

-- ── 2. Criar tabela de histórico de compensações (se não existir) ──────────────
CREATE TABLE IF NOT EXISTS acompanhamento_compensacoes_historico (
  id                          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id           UUID         NOT NULL REFERENCES acompanhamentos_bancarios(id) ON DELETE CASCADE,
  numero_semana               INTEGER      NOT NULL,
  data_referencia_inicio      DATE,
  data_referencia_fim         DATE,
  entrada_realizada           NUMERIC(15,2) DEFAULT 0,
  faturamento_anual_ref       NUMERIC(15,2) DEFAULT 0,
  teto_anual_movimentacao     NUMERIC(15,2) DEFAULT 0,
  faturamento_mensal_base     NUMERIC(15,2) DEFAULT 0,
  teto_mensal_movimentacao    NUMERIC(15,2) DEFAULT 0,
  referencia_semanal_base     NUMERIC(15,2) DEFAULT 0,
  teto_semanal_movimentacao   NUMERIC(15,2) DEFAULT 0,
  acumulado_mensal            NUMERIC(15,2) DEFAULT 0,
  valor_abaixo_semana         NUMERIC(15,2) DEFAULT 0,
  valor_excedente_semana      NUMERIC(15,2) DEFAULT 0,
  saldo_faltante_ref_mensal   NUMERIC(15,2) DEFAULT 0,
  saldo_disponivel_teto_mensal NUMERIC(15,2) DEFAULT 0,
  meta_base_dinamica          NUMERIC(15,2) DEFAULT 0,
  teto_dinamico_proxima       NUMERIC(15,2) DEFAULT 0,
  percentual_uso_semanal      NUMERIC(8,2) DEFAULT 0,
  percentual_uso_mensal       NUMERIC(8,2) DEFAULT 0,
  percentual_uso_anual        NUMERIC(8,2) DEFAULT 0,
  status_aderencia            TEXT DEFAULT 'dentro_da_faixa',
  alerta_aderencia            BOOLEAN DEFAULT false,
  motivo_alerta               TEXT,
  diagnostico_tecnico         TEXT,
  criado_por                  UUID,
  created_at                  TIMESTAMPTZ  DEFAULT NOW(),
  UNIQUE(acompanhamento_id, numero_semana)
);

-- ── 3. Índices para a tabela de histórico ──────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_comp_hist_acomp     ON acompanhamento_compensacoes_historico(acompanhamento_id);
CREATE INDEX IF NOT EXISTS idx_comp_hist_semana    ON acompanhamento_compensacoes_historico(numero_semana);
CREATE INDEX IF NOT EXISTS idx_comp_hist_alerta    ON acompanhamento_compensacoes_historico(alerta_aderencia);
CREATE INDEX IF NOT EXISTS idx_comp_hist_created   ON acompanhamento_compensacoes_historico(created_at DESC);

-- ── 4. Garantir que acompanhamentos_bancarios tenha campo percentual_operacional ─
ALTER TABLE acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS percentual_operacional NUMERIC(5,2) DEFAULT 30;

-- ── FIM DA MIGRATION 025 ──────────────────────────────────────────────────────


-- ============================================================
-- db/migrations/026_acompanhamento_bancario_dinamico.sql
-- ============================================================

-- 026_acompanhamento_bancario_dinamico.sql
-- Módulo de Acompanhamento Bancário Dinâmico.
-- Seguro para rodar mais de uma vez: usa IF NOT EXISTS e não remove dados.

ALTER TABLE acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS saldo_faltante_mes NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_dinamica_proxima_semana NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_mes NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS alerta_rating BOOLEAN NOT NULL DEFAULT false;

-- Garante colunas base caso a migration 024 ainda não tenha sido aplicada no ambiente.
ALTER TABLE acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS media_mensal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS limite_mensal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS media_semanal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quantidade_semanas_mes INTEGER NOT NULL DEFAULT 4,
  ADD COLUMN IF NOT EXISTS compensacao_semana_anterior NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS entrada_com_compensacao NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS diferenca_referencia_semanal NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS compensacao_necessaria_proxima NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_limite_semanal NUMERIC(8,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_limite_mensal NUMERIC(8,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_limite_anual NUMERIC(8,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS alerta_aderencia BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS motivo_alerta_aderencia TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_compensacao TEXT,
  ADD COLUMN IF NOT EXISTS status_compensacao TEXT;

CREATE TABLE IF NOT EXISTS acompanhamento_compensacoes_historico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES acompanhamentos_bancarios(id) ON DELETE CASCADE,
  atualizacao_id UUID REFERENCES acompanhamento_bancario_atualizacoes(id) ON DELETE SET NULL,
  numero_semana INTEGER NOT NULL,
  data_referencia_inicio DATE,
  data_referencia_fim DATE,
  entrada_realizada NUMERIC(15,2) NOT NULL DEFAULT 0,
  saida_realizada NUMERIC(15,2) NOT NULL DEFAULT 0,
  saldo_semanal NUMERIC(15,2) NOT NULL DEFAULT 0,
  media_mensal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  limite_mensal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  media_semanal_referencia NUMERIC(15,2) NOT NULL DEFAULT 0,
  quantidade_semanas_mes INTEGER NOT NULL DEFAULT 4,
  compensacao_anterior NUMERIC(15,2) NOT NULL DEFAULT 0,
  entrada_com_compensacao NUMERIC(15,2) NOT NULL DEFAULT 0,
  diferenca_referencia_semanal NUMERIC(15,2) NOT NULL DEFAULT 0,
  compensacao_necessaria NUMERIC(15,2) NOT NULL DEFAULT 0,
  saldo_faltante_mes NUMERIC(15,2) NOT NULL DEFAULT 0,
  meta_dinamica_proxima_semana NUMERIC(15,2) NOT NULL DEFAULT 0,
  valor_excedente_mes NUMERIC(15,2) NOT NULL DEFAULT 0,
  percentual_limite_semanal NUMERIC(8,2) NOT NULL DEFAULT 0,
  percentual_limite_mensal NUMERIC(8,2) NOT NULL DEFAULT 0,
  percentual_limite_anual NUMERIC(8,2) NOT NULL DEFAULT 0,
  alerta_aderencia BOOLEAN NOT NULL DEFAULT false,
  alerta_rating BOOLEAN NOT NULL DEFAULT false,
  motivo_alerta TEXT,
  status_compensacao TEXT,
  criado_por UUID NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE acompanhamento_compensacoes_historico
  ADD COLUMN IF NOT EXISTS atualizacao_id UUID REFERENCES acompanhamento_bancario_atualizacoes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS saida_realizada NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_semanal NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_mes NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_dinamica_proxima_semana NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_mes NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS alerta_rating BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS status_compensacao TEXT;

CREATE INDEX IF NOT EXISTS idx_acomp_hist_acomp ON acompanhamento_compensacoes_historico(acompanhamento_id);
CREATE INDEX IF NOT EXISTS idx_acomp_hist_semana ON acompanhamento_compensacoes_historico(acompanhamento_id, numero_semana);
CREATE INDEX IF NOT EXISTS idx_acomp_hist_alerta ON acompanhamento_compensacoes_historico(alerta_aderencia, alerta_rating);
CREATE INDEX IF NOT EXISTS idx_acomp_hist_created ON acompanhamento_compensacoes_historico(created_at DESC);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = current_schema()
      AND indexname = 'ux_acomp_comp_hist_acomp_semana'
  ) THEN
    CREATE UNIQUE INDEX ux_acomp_comp_hist_acomp_semana
      ON acompanhamento_compensacoes_historico(acompanhamento_id, numero_semana);
  END IF;
END $$;


-- ============================================================
-- db/migrations/027_contratos_assessoria_taxa_desistencia_custeio.sql
-- ============================================================

-- ============================================================
-- MIGRATION 027: Contrato de Assessoria — taxa de desistência e custeio mensal
-- Data: 2026-05-18
-- ============================================================
-- Idempotente. Alinha o banco ao novo ContratoAssessoria.tsx.
-- ============================================================

ALTER TABLE contratos_gerados
  ADD COLUMN IF NOT EXISTS taxa_desistencia NUMERIC(5, 2) DEFAULT 5.00;

ALTER TABLE contratos_gerados
  ADD COLUMN IF NOT EXISTS custeio_mensal NUMERIC(15, 2) DEFAULT 250.00;

COMMENT ON COLUMN contratos_gerados.taxa_desistencia IS
  'Percentual aplicado sobre o valor de referência em caso de desistência / honorário mínimo do contrato de assessoria.';

COMMENT ON COLUMN contratos_gerados.custeio_mensal IS
  'Valor mensal de custeio quando o Rating Bancário interno ficar abaixo de C no contrato de assessoria.';


-- ============================================================
-- db/migrations/028_contratos_numero_protocolo.sql
-- ============================================================

-- 028_contratos_numero_protocolo.sql
-- Identificação operacional dos contratos gerados:
-- - número do contrato
-- - protocolo do contrato
-- - código do tipo do contrato
-- - sequencial global

BEGIN;

CREATE SEQUENCE IF NOT EXISTS public.contratos_gerados_sequencial_global_seq
  START WITH 1
  INCREMENT BY 1;

ALTER TABLE public.contratos_gerados
  ADD COLUMN IF NOT EXISTS numero_contrato TEXT;

ALTER TABLE public.contratos_gerados
  ADD COLUMN IF NOT EXISTS protocolo_contrato TEXT;

ALTER TABLE public.contratos_gerados
  ADD COLUMN IF NOT EXISTS codigo_tipo_contrato TEXT;

ALTER TABLE public.contratos_gerados
  ADD COLUMN IF NOT EXISTS sequencial_contrato INTEGER;

COMMENT ON COLUMN public.contratos_gerados.numero_contrato IS
  'Número operacional legível do contrato. Exemplo: ASS-2026-000001.';

COMMENT ON COLUMN public.contratos_gerados.protocolo_contrato IS
  'Protocolo único para rastreio do contrato. Exemplo: DC-ASS-20260519-DOC0148-000001.';

COMMENT ON COLUMN public.contratos_gerados.codigo_tipo_contrato IS
  'Código do tipo do contrato: ASS, LNR, SCR, RAT, PAR.';

COMMENT ON COLUMN public.contratos_gerados.sequencial_contrato IS
  'Sequencial global usado na composição do número e protocolo do contrato.';

-- Código operacional por tipo de contrato.
UPDATE public.contratos_gerados
   SET codigo_tipo_contrato = CASE tipo_contrato
     WHEN 'assessoria' THEN 'ASS'
     WHEN 'limpa_nome' THEN 'LNR'
     WHEN 'limpa_bacen' THEN 'SCR'
     WHEN 'rating' THEN 'RAT'
     WHEN 'parceria_comercial' THEN 'PAR'
     ELSE 'CTR'
   END
 WHERE codigo_tipo_contrato IS NULL
    OR btrim(codigo_tipo_contrato) = '';

-- Preenche sequencial para contratos antigos que ainda não possuem identificação.
UPDATE public.contratos_gerados
   SET sequencial_contrato = nextval('public.contratos_gerados_sequencial_global_seq')::integer
 WHERE sequencial_contrato IS NULL;

-- Gera número e protocolo para contratos já existentes.
WITH base AS (
  SELECT
    id,
    COALESCE(codigo_tipo_contrato, 'CTR') AS codigo_tipo_contrato,
    COALESCE(sequencial_contrato, 0) AS sequencial_contrato,
    COALESCE(created_at, NOW()) AS criado_em,
    LPAD(
      RIGHT(
        REGEXP_REPLACE(
          COALESCE(
            payload_snapshot -> 'contratante' ->> 'cnpj',
            payload_snapshot -> 'contratante' ->> 'cpf',
            payload_snapshot -> 'contratante' ->> 'cpf_representante',
            payload_snapshot -> 'representante' ->> 'cpf',
            payload_snapshot -> 'parceiro' ->> 'cpf',
            payload_snapshot -> 'parceiro' ->> 'cnpj',
            '0000'
          ),
          '\D',
          '',
          'g'
        ),
        4
      ),
      4,
      '0'
    ) AS doc_codigo
  FROM public.contratos_gerados
)
UPDATE public.contratos_gerados cg
   SET numero_contrato = COALESCE(
         NULLIF(cg.numero_contrato, ''),
         base.codigo_tipo_contrato || '-' ||
         TO_CHAR(base.criado_em, 'YYYY') || '-' ||
         LPAD(base.sequencial_contrato::text, 6, '0')
       ),
       protocolo_contrato = COALESCE(
         NULLIF(cg.protocolo_contrato, ''),
         'DC-' ||
         base.codigo_tipo_contrato || '-' ||
         TO_CHAR(base.criado_em, 'YYYYMMDD') || '-' ||
         'DOC' || base.doc_codigo || '-' ||
         LPAD(base.sequencial_contrato::text, 6, '0')
       )
  FROM base
 WHERE cg.id = base.id
   AND (
     cg.numero_contrato IS NULL
     OR btrim(cg.numero_contrato) = ''
     OR cg.protocolo_contrato IS NULL
     OR btrim(cg.protocolo_contrato) = ''
   );

-- Garante que o próximo nextval continue depois do maior sequencial já existente.
SELECT setval(
  'public.contratos_gerados_sequencial_global_seq',
  GREATEST((SELECT COALESCE(MAX(sequencial_contrato), 0) FROM public.contratos_gerados), 1),
  true
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_contratos_numero_contrato_unique
  ON public.contratos_gerados(numero_contrato)
  WHERE numero_contrato IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_contratos_protocolo_contrato_unique
  ON public.contratos_gerados(protocolo_contrato)
  WHERE protocolo_contrato IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_contratos_codigo_tipo_contrato
  ON public.contratos_gerados(codigo_tipo_contrato);

COMMIT;


-- ============================================================
-- db/migrations/029_acompanhamento_bancario_logica_alertas_relatorio.sql
-- ============================================================

-- ============================================================================
-- Destrava Crédito
-- Migration 029 CORRIGIDA — Acompanhamento bancário: lógica, alertas e relatório
-- ============================================================================
-- Objetivo:
-- 1) Corrigir a versão anterior que referenciava a coluna inexistente margem_30.
-- 2) Preparar as colunas usadas pelo acompanhamento bancário sem quebrar dados existentes.
-- 3) Reparar instalações antigas onde total_entradas/saldo_semanal foram criadas como GENERATED.
-- 4) Manter a fórmula oficial:
--    limite anual = faturamento_anual * 1.30
--    média mensal = faturamento_anual / 12
--    teto mensal = (faturamento_anual * 1.30) / 12
--    referência semanal = média mensal / 4
--    teto semanal = teto mensal / 4
--
-- Pré-requisito quando houver erro de ownership:
-- execute antes, como usuário postgres/superuser:
--   ALTER TABLE public.acompanhamentos_bancarios OWNER TO destravadb;
--   ALTER TABLE public.acompanhamento_bancario_atualizacoes OWNER TO destravadb;
--   ALTER TABLE public.acompanhamento_bancario_alertas OWNER TO destravadb;
--   ALTER TABLE public.acompanhamento_bancario_relatorios OWNER TO destravadb;
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Tabela principal
-- ---------------------------------------------------------------------------

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS faturamento_anual NUMERIC(15,2);

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS limite_operacional_anual NUMERIC(15,2);

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS media_mensal_base NUMERIC(15,2);

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS teto_mensal NUMERIC(15,2);

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS referencia_semanal NUMERIC(15,2);

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS teto_semanal NUMERIC(15,2);

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS margem_seguranca_30 NUMERIC(15,2);

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS status_operacional VARCHAR(40) DEFAULT 'pendente';

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS diagnostico_operacional TEXT;

ALTER TABLE public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill oficial sem depender de margem_30, media_mensal antiga ou qualquer coluna legado.
UPDATE public.acompanhamentos_bancarios
SET
  limite_operacional_anual = ROUND(COALESCE(faturamento_anual, 0) * 1.30, 2),
  media_mensal_base = ROUND(COALESCE(faturamento_anual, 0) / 12.0, 2),
  teto_mensal = ROUND((COALESCE(faturamento_anual, 0) * 1.30) / 12.0, 2),
  referencia_semanal = ROUND((COALESCE(faturamento_anual, 0) / 12.0) / 4.0, 2),
  teto_semanal = ROUND(((COALESCE(faturamento_anual, 0) * 1.30) / 12.0) / 4.0, 2),
  margem_seguranca_30 = ROUND(COALESCE(faturamento_anual, 0) * 0.30, 2),
  updated_at = NOW()
WHERE faturamento_anual IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Tabela de atualizações semanais
-- ---------------------------------------------------------------------------

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS entrada_pix NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS entrada_dinheiro NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS entrada_maquininha NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS entrada_boleto NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS entrada_ted NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS entrada_outras NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS referencia_semanal NUMERIC(15,2);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS teto_semanal NUMERIC(15,2);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS acumulado_mensal NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS acumulado_anual NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS saldo_disponivel_mes NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS valor_faltante_referencia NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS valor_excedente_teto NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS meta_dinamica_proxima_semana NUMERIC(15,2);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima_semana NUMERIC(15,2);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS status_semana VARCHAR(40) DEFAULT 'pendente';

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS diagnostico_semana TEXT;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS alerta_risco VARCHAR(40) DEFAULT 'normal';

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS percentual_teto_semanal NUMERIC(8,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS percentual_teto_mensal NUMERIC(8,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS observacao_operacional TEXT;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Colunas usadas pelo monitor semanal anterior, mantidas para compatibilidade.
ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS status_aderencia VARCHAR(40);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS alerta_aderencia VARCHAR(40);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS motivo_alerta_aderencia TEXT;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS meta_base_dinamica NUMERIC(15,2);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima NUMERIC(15,2);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal NUMERIC(8,2);

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal NUMERIC(8,2);

-- Se instalações antigas tiverem total_entradas/saldo_semanal como GENERATED,
-- converte para colunas normais. Isso evita erro em INSERT/UPDATE do backend.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'acompanhamento_bancario_atualizacoes'
      AND column_name = 'total_entradas'
      AND is_generated <> 'NEVER'
  ) THEN
    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ADD COLUMN IF NOT EXISTS total_entradas_tmp NUMERIC(15,2);

    UPDATE public.acompanhamento_bancario_atualizacoes
    SET total_entradas_tmp = COALESCE(total_entradas, 0);

    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      DROP COLUMN total_entradas;

    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      RENAME COLUMN total_entradas_tmp TO total_entradas;

    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ALTER COLUMN total_entradas SET DEFAULT 0;

    UPDATE public.acompanhamento_bancario_atualizacoes
    SET total_entradas = 0
    WHERE total_entradas IS NULL;

    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ALTER COLUMN total_entradas SET NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'acompanhamento_bancario_atualizacoes'
      AND column_name = 'saldo_semanal'
      AND is_generated <> 'NEVER'
  ) THEN
    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ADD COLUMN IF NOT EXISTS saldo_semanal_tmp NUMERIC(15,2);

    UPDATE public.acompanhamento_bancario_atualizacoes
    SET saldo_semanal_tmp = COALESCE(saldo_semanal, 0);

    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      DROP COLUMN saldo_semanal;

    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      RENAME COLUMN saldo_semanal_tmp TO saldo_semanal;

    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ALTER COLUMN saldo_semanal SET DEFAULT 0;

    UPDATE public.acompanhamento_bancario_atualizacoes
    SET saldo_semanal = 0
    WHERE saldo_semanal IS NULL;

    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ALTER COLUMN saldo_semanal SET NOT NULL;
  END IF;
END $$;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS total_entradas NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS saldo_semanal NUMERIC(15,2) DEFAULT 0;

-- Sincroniza legado entrada_maquina -> entrada_maquininha quando existir.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'acompanhamento_bancario_atualizacoes'
      AND column_name = 'entrada_maquina'
  ) THEN
    UPDATE public.acompanhamento_bancario_atualizacoes
    SET entrada_maquininha = COALESCE(NULLIF(entrada_maquininha, 0), entrada_maquina, 0)
    WHERE COALESCE(entrada_maquininha, 0) = 0
      AND COALESCE(entrada_maquina, 0) > 0;
  END IF;
END $$;

-- Recalcula totais por semana sem duplicar maquininha quando houver coluna legado.
UPDATE public.acompanhamento_bancario_atualizacoes
SET
  entrada_pix = COALESCE(entrada_pix, 0),
  entrada_dinheiro = COALESCE(entrada_dinheiro, 0),
  entrada_maquininha = COALESCE(entrada_maquininha, 0),
  entrada_boleto = COALESCE(entrada_boleto, 0),
  entrada_ted = COALESCE(entrada_ted, 0),
  entrada_outras = COALESCE(entrada_outras, 0),
  total_entradas = ROUND(
    COALESCE(entrada_pix, 0)
    + COALESCE(entrada_dinheiro, 0)
    + COALESCE(entrada_maquininha, 0)
    + COALESCE(entrada_boleto, 0)
    + COALESCE(entrada_ted, 0)
    + COALESCE(entrada_outras, 0),
    2
  ),
  saldo_semanal = ROUND(
    COALESCE(entrada_pix, 0)
    + COALESCE(entrada_dinheiro, 0)
    + COALESCE(entrada_maquininha, 0)
    + COALESCE(entrada_boleto, 0)
    + COALESCE(entrada_ted, 0)
    + COALESCE(entrada_outras, 0),
    2
  ),
  updated_at = NOW();

-- ---------------------------------------------------------------------------
-- 3. Reprocessamento financeiro simples das semanas existentes
-- ---------------------------------------------------------------------------

WITH base AS (
  SELECT
    u.id,
    a.id AS acompanhamento_id,
    COALESCE(a.faturamento_anual, 0) AS faturamento_anual,
    ROUND((COALESCE(a.faturamento_anual, 0) / 12.0) / 4.0, 2) AS referencia_sem,
    ROUND(((COALESCE(a.faturamento_anual, 0) * 1.30) / 12.0) / 4.0, 2) AS teto_sem,
    ROUND((COALESCE(a.faturamento_anual, 0) * 1.30) / 12.0, 2) AS teto_mes,
    COALESCE(u.total_entradas, 0) AS total_sem,
    COALESCE(u.data_atualizacao, NOW()) AS data_atualizacao
  FROM public.acompanhamento_bancario_atualizacoes u
  JOIN public.acompanhamentos_bancarios a ON a.id = u.acompanhamento_id
),
calc AS (
  SELECT
    b.*,
    SUM(b.total_sem) OVER (
      PARTITION BY b.acompanhamento_id, DATE_TRUNC('month', b.data_atualizacao)
      ORDER BY b.data_atualizacao, b.id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS acum_mes,
    SUM(b.total_sem) OVER (
      PARTITION BY b.acompanhamento_id, DATE_TRUNC('year', b.data_atualizacao)
      ORDER BY b.data_atualizacao, b.id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS acum_ano
  FROM base b
)
UPDATE public.acompanhamento_bancario_atualizacoes u
SET
  referencia_semanal = c.referencia_sem,
  teto_semanal = c.teto_sem,
  acumulado_mensal = ROUND(c.acum_mes, 2),
  acumulado_anual = ROUND(c.acum_ano, 2),
  saldo_disponivel_mes = GREATEST(ROUND(c.teto_mes - c.acum_mes, 2), 0),
  valor_faltante_referencia = GREATEST(ROUND(c.referencia_sem - c.total_sem, 2), 0),
  valor_excedente_teto = GREATEST(ROUND(c.total_sem - c.teto_sem, 2), 0),
  percentual_teto_semanal = CASE WHEN c.teto_sem > 0 THEN ROUND((c.total_sem / c.teto_sem) * 100, 2) ELSE 0 END,
  percentual_teto_mensal = CASE WHEN c.teto_mes > 0 THEN ROUND((c.acum_mes / c.teto_mes) * 100, 2) ELSE 0 END,
  status_semana = CASE
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem * 1.20 THEN 'risco_critico'
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem THEN 'acima_teto'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem * 0.70 THEN 'muito_abaixo'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem THEN 'abaixo_referencia'
    ELSE 'dentro_faixa'
  END,
  alerta_risco = CASE
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem * 1.20 THEN 'coaf_pld_aml'
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem THEN 'excesso_teto'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem * 0.70 THEN 'baixa_movimentacao'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem THEN 'atenção'
    ELSE 'normal'
  END,
  diagnostico_semana = CASE
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem * 1.20 THEN 'Movimentação semanal acima do teto com risco operacional elevado. Avaliar aderência, origem dos recursos e controles PLD/AML.'
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem THEN 'Movimentação semanal acima do teto operacional. Recomenda-se redistribuir entradas nas semanas seguintes.'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem * 0.70 THEN 'Movimentação semanal muito abaixo da referência. Há risco de baixa aderência ao planejamento.'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem THEN 'Movimentação abaixo da referência semanal, mas ainda em faixa recuperável.'
    ELSE 'Movimentação dentro da faixa operacional esperada.'
  END,
  status_aderencia = CASE
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem * 1.20 THEN 'critico'
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem THEN 'acima_teto'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem * 0.70 THEN 'abaixo_piso'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem THEN 'abaixo_referencia'
    ELSE 'dentro_da_faixa'
  END,
  alerta_aderencia = CASE
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem * 1.20 THEN 'critico'
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem THEN 'vermelho'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem * 0.70 THEN 'vermelho'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem THEN 'amarelo'
    ELSE 'verde'
  END,
  motivo_alerta_aderencia = CASE
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem * 1.20 THEN 'Semana acima de 120% do teto operacional.'
    WHEN c.teto_sem > 0 AND c.total_sem > c.teto_sem THEN 'Semana acima do teto operacional.'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem * 0.70 THEN 'Semana abaixo de 70% da referência.'
    WHEN c.referencia_sem > 0 AND c.total_sem < c.referencia_sem THEN 'Semana abaixo da referência.'
    ELSE 'Semana dentro da faixa.'
  END,
  percentual_uso_semanal = CASE WHEN c.teto_sem > 0 THEN ROUND((c.total_sem / c.teto_sem) * 100, 2) ELSE 0 END,
  percentual_uso_mensal = CASE WHEN c.teto_mes > 0 THEN ROUND((c.acum_mes / c.teto_mes) * 100, 2) ELSE 0 END,
  updated_at = NOW()
FROM calc c
WHERE c.id = u.id;

-- ---------------------------------------------------------------------------
-- 4. Alertas e relatórios
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.acompanhamento_bancario_alertas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES public.acompanhamentos_bancarios(id) ON DELETE CASCADE,
  atualizacao_id UUID REFERENCES public.acompanhamento_bancario_atualizacoes(id) ON DELETE CASCADE,
  tipo VARCHAR(60) NOT NULL,
  severidade VARCHAR(30) NOT NULL DEFAULT 'info',
  titulo TEXT NOT NULL,
  mensagem TEXT NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'aberto',
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolvido_em TIMESTAMPTZ,
  resolvido_por UUID,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.acompanhamento_bancario_relatorios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES public.acompanhamentos_bancarios(id) ON DELETE CASCADE,
  mes INTEGER NOT NULL,
  ano INTEGER NOT NULL,
  total_mensal NUMERIC(15,2) DEFAULT 0,
  referencia_mensal NUMERIC(15,2) DEFAULT 0,
  teto_mensal NUMERIC(15,2) DEFAULT 0,
  status_mensal VARCHAR(40) DEFAULT 'pendente',
  diagnostico_mensal TEXT,
  conteudo_html TEXT,
  pdf_url TEXT,
  assinado_em TIMESTAMPTZ,
  assinado_por TEXT,
  criado_por UUID,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb,
  UNIQUE (acompanhamento_id, mes, ano)
);

CREATE TABLE IF NOT EXISTS public.acompanhamento_compensacoes_historico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES public.acompanhamentos_bancarios(id) ON DELETE CASCADE,
  atualizacao_id UUID REFERENCES public.acompanhamento_bancario_atualizacoes(id) ON DELETE CASCADE,
  numero_semana INTEGER,
  mes INTEGER,
  ano INTEGER,
  meta_dinamica NUMERIC(15,2),
  teto_dinamico NUMERIC(15,2),
  acumulado_mensal NUMERIC(15,2),
  saldo_disponivel_mes NUMERIC(15,2),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Índices seguros
CREATE INDEX IF NOT EXISTS idx_acomp_banc_atualizacoes_acomp_data
  ON public.acompanhamento_bancario_atualizacoes (acompanhamento_id, data_atualizacao DESC);

CREATE INDEX IF NOT EXISTS idx_acomp_banc_atualizacoes_acomp_semana
  ON public.acompanhamento_bancario_atualizacoes (acompanhamento_id, numero_semana);

CREATE INDEX IF NOT EXISTS idx_acomp_banc_alertas_acomp_status
  ON public.acompanhamento_bancario_alertas (acompanhamento_id, status);

CREATE INDEX IF NOT EXISTS idx_acomp_banc_relatorios_acomp_mes_ano
  ON public.acompanhamento_bancario_relatorios (acompanhamento_id, ano, mes);

CREATE INDEX IF NOT EXISTS idx_acomp_compensacoes_acomp_semana
  ON public.acompanhamento_compensacoes_historico (acompanhamento_id, ano, mes, numero_semana);

-- Constraint única defensiva para evitar duplicidade da mesma semana por acompanhamento.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'uq_acompanhamento_semana'
      AND conrelid = 'public.acompanhamento_bancario_atualizacoes'::regclass
  ) THEN
    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ADD CONSTRAINT uq_acompanhamento_semana UNIQUE (acompanhamento_id, numero_semana);
  END IF;
EXCEPTION
  WHEN unique_violation THEN
    RAISE NOTICE 'Não foi possível criar uq_acompanhamento_semana porque há duplicidades existentes. Remova duplicidades antes de criar a constraint.';
END $$;

COMMIT;


-- ============================================================
-- db/migrations/030_contratos_padrao_visual_prestadoras.sql
-- ============================================================

-- 030_contratos_padrao_visual_prestadoras.sql
-- Padroniza identidade visual de prestadoras usadas nos contratos.
-- Seguro para rodar mais de uma vez.
-- Também garante as colunas visuais usadas pelo PDF, caso o banco ainda não tenha recebido
-- os ALTER TABLE executados pelo backend.

BEGIN;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS logo_url TEXT;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS logo_path TEXT;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS cor_primaria TEXT;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS cor_secundaria TEXT;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS cabecalho_html TEXT;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS rodape_html TEXT;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS cidade_assinatura TEXT;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS uf_assinatura TEXT;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS usar_papel_personalizado BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS mostrar_logo_contrato BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.prestadores_servico
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

UPDATE public.prestadores_servico
   SET cor_primaria = COALESCE(NULLIF(cor_primaria, ''), '#0f172a'),
       cor_secundaria = COALESCE(NULLIF(cor_secundaria, ''), '#0ea5e9'),
       usar_papel_personalizado = true,
       mostrar_logo_contrato = true,
       rodape_html = COALESCE(
         NULLIF(rodape_html, ''),
         '<strong>PERMUPAY LTDA</strong> • CNPJ: 61281938000111 • 6135268355 • permupay@gmail.com<br/>QND 25 lote 40, Brasília, DF, 72120-250'
       ),
       updated_at = NOW()
 WHERE regexp_replace(COALESCE(cnpj, ''), '\D', '', 'g') = '61281938000111'
    OR lower(COALESCE(razao_social, nome_fantasia, nome, '')) LIKE '%permupay%'
    OR lower(COALESCE(razao_social, nome_fantasia, nome, '')) LIKE '%permu pay%';

COMMIT;


-- ============================================================
-- db/migrations/031_empresas_dados_receita_cnpj.sql
-- ============================================================

-- 031_empresas_dados_receita_cnpj.sql
-- Corrige cadastro de empresas e adiciona armazenamento completo de dados públicos da Receita/BrasilAPI.
-- Idempotente: pode rodar mais de uma vez com segurança.

BEGIN;

-- Extensões necessárias para gen_random_uuid(), caso ainda não existam.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Colunas de relacionamento que podem faltar em ambientes que não rodaram migrations antigas.
ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS captador_id UUID NULL REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS analista_id UUID NULL REFERENCES public.colaboradores(id) ON DELETE SET NULL;

-- Dados fiscais/cadastrais retornados pela Receita Federal/BrasilAPI.
ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS natureza_juridica TEXT,
  ADD COLUMN IF NOT EXISTS cnae_principal TEXT,
  ADD COLUMN IF NOT EXISTS cnae_descricao TEXT,
  ADD COLUMN IF NOT EXISTS cnaes_secundarios JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS descricao_situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS data_situacao_cadastral DATE,
  ADD COLUMN IF NOT EXISTS motivo_situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS data_inicio_atividade DATE,
  ADD COLUMN IF NOT EXISTS capital_social NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS matriz_filial TEXT,
  ADD COLUMN IF NOT EXISTS dados_receita JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS qsa JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_empresas_captador_id ON public.empresas(captador_id) WHERE captador_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_analista_id ON public.empresas(analista_id) WHERE analista_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_cnae_principal ON public.empresas(cnae_principal) WHERE cnae_principal IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_situacao_cadastral ON public.empresas(descricao_situacao_cadastral) WHERE descricao_situacao_cadastral IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_qsa_gin ON public.empresas USING GIN (qsa);
CREATE INDEX IF NOT EXISTS idx_empresas_dados_receita_gin ON public.empresas USING GIN (dados_receita);

COMMIT;


-- ============================================================
-- db/migrations/031_smart_onboarding_company_hub.sql
-- ============================================================

-- 031_smart_onboarding_company_hub.sql
-- Refatoração Crítica: Smart Onboarding e Company Hub
-- Idempotente (IF NOT EXISTS) para não quebrar funcionalidades anteriores

BEGIN;

-- 1. Enriquecer tabela clientes (no nosso banco é 'empresas')
-- A instrução diz "tabela clientes", mas no esquema atual o nome é 'empresas'.
-- O documento original usa 'empresas' para B2B e 'clientes_pf' para B2C.
-- Vou aplicar em 'empresas'.

ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS natureza_juridica TEXT,
  ADD COLUMN IF NOT EXISTS capital_social NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS cnae_principal TEXT,
  ADD COLUMN IF NOT EXISTS cnaes_secundarios TEXT[],
  ADD COLUMN IF NOT EXISTS data_abertura DATE;

-- Os campos cep, logradouro, numero, complemento, bairro, cidade, estado já existem na tabela empresas.

-- 2. Nova tabela socios_empresa
CREATE TABLE IF NOT EXISTS public.socios_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  cpf_cnpj TEXT,
  qualificacao_socio TEXT,
  percentual_capital NUMERIC(5,2),
  representante_legal BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_id ON public.socios_empresa(empresa_id);

-- Trigger de updated_at para socios_empresa
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_socios_empresa_updated_at') THEN
    CREATE TRIGGER trg_socios_empresa_updated_at
      BEFORE UPDATE ON public.socios_empresa
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 3. Nova tabela documentos_empresa (GED)
-- A instrução pediu "documentos_empresa". Existe uma tabela "empresa_documentos" no backend, mas o prompt exige a criação dessa nova estrutura e enum de status.
CREATE TABLE IF NOT EXISTS public.documentos_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome_arquivo TEXT NOT NULL,
  tipo_documento TEXT CHECK (tipo_documento IN ('contrato_social', 'alteracao_contratual', 'cartao_cnpj', 'cnh_socio', 'comprovante_residencia', 'faturamento', 'imposto_renda', 'outro')),
  url_arquivo TEXT NOT NULL,
  tamanho_bytes INTEGER,
  status_validacao TEXT DEFAULT 'em_analise' CHECK (status_validacao IN ('em_analise', 'aprovado', 'rejeitado')),
  data_vencimento DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_documentos_empresa_empresa_id ON public.documentos_empresa(empresa_id);

-- Trigger de updated_at para documentos_empresa
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_documentos_empresa_updated_at') THEN
    CREATE TRIGGER trg_documentos_empresa_updated_at
      BEFORE UPDATE ON public.documentos_empresa
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

COMMIT;


-- ============================================================
-- db/migrations/032_socios_empresa_completo.sql
-- ============================================================

-- ============================================================
-- 032_socios_empresa_completo.sql
-- Expande socios_empresa com dados completos para análise de crédito:
-- dados pessoais, cônjuge, endereço, RG, junta comercial, advogado
-- Idempotente — usa ADD COLUMN IF NOT EXISTS em tudo
--
-- EXECUTAR:
--   docker cp 032_socios_empresa_completo.sql tr3go0jqyc5h3tuvz7f46zkc:/tmp/
--   docker exec -it tr3go0jqyc5h3tuvz7f46zkc \
--     psql -U postgres -d postgres -f /tmp/032_socios_empresa_completo.sql
-- ============================================================

BEGIN;

\echo '── Garantir função set_updated_at (caso não exista) ─────────'
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

\echo '── Expandir socios_empresa ──────────────────────────────────'

-- Dados pessoais
ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS rg                    TEXT,
  ADD COLUMN IF NOT EXISTS rg_orgao_emissor      TEXT,
  ADD COLUMN IF NOT EXISTS rg_uf_emissao         CHAR(2),
  ADD COLUMN IF NOT EXISTS rg_data_emissao       DATE,
  ADD COLUMN IF NOT EXISTS data_nascimento       DATE,
  ADD COLUMN IF NOT EXISTS nacionalidade         TEXT DEFAULT 'Brasileiro(a)',
  ADD COLUMN IF NOT EXISTS estado_civil          TEXT,
  ADD COLUMN IF NOT EXISTS profissao             TEXT,
  ADD COLUMN IF NOT EXISTS email                 TEXT,
  ADD COLUMN IF NOT EXISTS telefone              TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp              TEXT,
  ADD COLUMN IF NOT EXISTS pep                   BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS ativo                 BOOLEAN DEFAULT true;

-- Endereço do sócio
ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS cep                   TEXT,
  ADD COLUMN IF NOT EXISTS logradouro            TEXT,
  ADD COLUMN IF NOT EXISTS numero                TEXT,
  ADD COLUMN IF NOT EXISTS complemento           TEXT,
  ADD COLUMN IF NOT EXISTS bairro                TEXT,
  ADD COLUMN IF NOT EXISTS cidade                TEXT,
  ADD COLUMN IF NOT EXISTS uf                    CHAR(2);

-- Cônjuge / companheiro(a)
ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS conjuge_nome          TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_cpf           TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_rg            TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_data_nasc     DATE,
  ADD COLUMN IF NOT EXISTS conjuge_profissao     TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_email         TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_telefone      TEXT,
  ADD COLUMN IF NOT EXISTS regime_bens           TEXT;

-- Dados da Junta Comercial / JUCESP / JUCEG
ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS junta_comercial_uf    CHAR(2),
  ADD COLUMN IF NOT EXISTS nire                  TEXT,
  ADD COLUMN IF NOT EXISTS data_registro_junta   DATE,
  ADD COLUMN IF NOT EXISTS numero_protocolo_junta TEXT,
  ADD COLUMN IF NOT EXISTS situacao_junta         TEXT DEFAULT 'regular',
  ADD COLUMN IF NOT EXISTS data_ultima_alteracao  DATE,
  ADD COLUMN IF NOT EXISTS numero_alteracao        TEXT;

-- Advogado / representante legal externo
ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS advogado_nome         TEXT,
  ADD COLUMN IF NOT EXISTS advogado_cpf          TEXT,
  ADD COLUMN IF NOT EXISTS advogado_oab          TEXT,
  ADD COLUMN IF NOT EXISTS advogado_uf_oab       CHAR(2),
  ADD COLUMN IF NOT EXISTS advogado_email        TEXT,
  ADD COLUMN IF NOT EXISTS advogado_telefone     TEXT;

-- Análise de crédito / risco
ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS score_serasa          INTEGER,
  ADD COLUMN IF NOT EXISTS score_spc             INTEGER,
  ADD COLUMN IF NOT EXISTS possui_restricao      BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS valor_restricao       NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS observacoes           TEXT,
  ADD COLUMN IF NOT EXISTS dados_extras          JSONB DEFAULT '{}'::jsonb;

\echo 'OK: socios_empresa expandido.'

-- Índices úteis para análise
CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpf
  ON public.socios_empresa(cpf_cnpj);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_ativo
  ON public.socios_empresa(empresa_id, ativo);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_conjuge_cpf
  ON public.socios_empresa(conjuge_cpf)
  WHERE conjuge_cpf IS NOT NULL;

-- Desabilitar RLS
ALTER TABLE public.socios_empresa DISABLE ROW LEVEL SECURITY;

-- Permissões
GRANT ALL PRIVILEGES ON public.socios_empresa TO postgres;

COMMIT;

\echo ''
\echo '── Validação ────────────────────────────────────────────────'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'socios_empresa'
ORDER BY ordinal_position;

\echo 'CONCLUÍDO'


-- ============================================================
-- db/migrations/033_fix_socios_empresa_bulk.sql
-- ============================================================

-- 033_fix_socios_empresa_bulk.sql
-- Correção cirúrgica para erro 500 em POST /api/empresas/:id/socios/bulk
-- Garante tabela/base mínima usada pelo backend sem quebrar dados existentes.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS public.socios_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  cpf_cnpj TEXT,
  qualificacao_socio TEXT,
  percentual_capital NUMERIC(5,2),
  representante_legal BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS cpf_cnpj TEXT,
  ADD COLUMN IF NOT EXISTS qualificacao_socio TEXT,
  ADD COLUMN IF NOT EXISTS percentual_capital NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS representante_legal BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_id
  ON public.socios_empresa(empresa_id);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_socios_empresa_updated_at') THEN
    CREATE TRIGGER trg_socios_empresa_updated_at
      BEFORE UPDATE ON public.socios_empresa
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

COMMIT;


-- ============================================================
-- db/migrations/034_company_hub_empresas_completo.sql
-- ============================================================

-- 034_company_hub_empresas_completo.sql
-- Enriquecimento definitivo da página Empresas / Company Hub.
-- Idempotente: pode rodar mais de uma vez sem quebrar produção.

BEGIN;

ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS natureza_juridica TEXT,
  ADD COLUMN IF NOT EXISTS capital_social NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS cnae_principal TEXT,
  ADD COLUMN IF NOT EXISTS cnaes_secundarios TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS data_abertura DATE,
  ADD COLUMN IF NOT EXISTS situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS matriz_filial TEXT,
  ADD COLUMN IF NOT EXISTS ultima_sincronizacao_receita TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.empresa_documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  tipo TEXT,
  tamanho INTEGER,
  url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_empresa_documentos_empresa_id ON public.empresa_documentos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresas_cnpj ON public.empresas(cnpj);
CREATE INDEX IF NOT EXISTS idx_empresas_natureza_juridica ON public.empresas(natureza_juridica);
CREATE INDEX IF NOT EXISTS idx_empresas_cnae_principal ON public.empresas(cnae_principal);

COMMIT;


-- ============================================================
-- db/migrations/035_empresa_cadastro_credito_robusto.sql
-- ============================================================

-- 035_empresa_cadastro_credito_robusto.sql
-- Correção sem regressão para cadastro de empresa, Smart Onboarding, sócios,
-- documentos/checklist e histórico. Idempotente para redeploy seguro.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Empresas: campos carregáveis automaticamente ou preenchíveis no dossiê de crédito.
ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS captador_id UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS analista_id UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS natureza_juridica TEXT,
  ADD COLUMN IF NOT EXISTS capital_social NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS cnae_principal TEXT,
  ADD COLUMN IF NOT EXISTS cnaes_secundarios TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS data_abertura DATE,
  ADD COLUMN IF NOT EXISTS situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS matriz_filial TEXT,
  ADD COLUMN IF NOT EXISTS ultima_sincronizacao_receita TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS telefone_2 TEXT,
  ADD COLUMN IF NOT EXISTS inscricao_municipal TEXT,
  ADD COLUMN IF NOT EXISTS data_situacao_cadastral DATE,
  ADD COLUMN IF NOT EXISTS motivo_situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS regime_tributario TEXT,
  ADD COLUMN IF NOT EXISTS score_cnpj INTEGER,
  ADD COLUMN IF NOT EXISTS restricoes_cnpj TEXT,
  ADD COLUMN IF NOT EXISTS observacoes_credito TEXT,
  ADD COLUMN IF NOT EXISTS dados_extra_receita JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_empresas_captador_id ON public.empresas(captador_id) WHERE captador_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_analista_id ON public.empresas(analista_id) WHERE analista_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_cnpj ON public.empresas(cnpj) WHERE cnpj IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_status ON public.empresas(status);
CREATE INDEX IF NOT EXISTS idx_empresas_responsavel_id ON public.empresas(responsavel_id) WHERE responsavel_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_cnae_principal ON public.empresas(cnae_principal) WHERE cnae_principal IS NOT NULL;

-- Histórico da empresa, caso produção ainda não tenha aplicado migrations antigas.
CREATE TABLE IF NOT EXISTS public.empresa_historico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL DEFAULT 'nota',
  descricao TEXT NOT NULL,
  autor TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_empresa_historico_empresa_id ON public.empresa_historico(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresa_historico_created_at ON public.empresa_historico(created_at DESC);

-- Follow-ups da empresa, usados pela página Company Hub.
CREATE TABLE IF NOT EXISTS public.empresa_followups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  tipo TEXT DEFAULT 'ligacao',
  data_agendada TIMESTAMPTZ,
  descricao TEXT,
  concluido BOOLEAN NOT NULL DEFAULT FALSE,
  concluido_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_empresa_followups_empresa_id ON public.empresa_followups(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresa_followups_data ON public.empresa_followups(data_agendada);

-- Documentos oficiais da empresa já usados por /api/empresas/:id/documentos.
CREATE TABLE IF NOT EXISTS public.empresa_documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  tipo TEXT,
  tamanho INTEGER,
  url TEXT,
  status_validacao TEXT DEFAULT 'em_analise',
  observacao_validacao TEXT,
  data_vencimento DATE,
  validado_por UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  validado_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.empresa_documentos
  ADD COLUMN IF NOT EXISTS status_validacao TEXT DEFAULT 'em_analise',
  ADD COLUMN IF NOT EXISTS observacao_validacao TEXT,
  ADD COLUMN IF NOT EXISTS data_vencimento DATE,
  ADD COLUMN IF NOT EXISTS validado_por UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS validado_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
CREATE INDEX IF NOT EXISTS idx_empresa_documentos_empresa_id ON public.empresa_documentos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresa_documentos_tipo ON public.empresa_documentos(tipo);
CREATE INDEX IF NOT EXISTS idx_empresa_documentos_status ON public.empresa_documentos(status_validacao);

-- Estrutura GED antiga/alternativa mantida para compatibilidade com /ged.
CREATE TABLE IF NOT EXISTS public.documentos_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome_arquivo TEXT NOT NULL,
  tipo_documento TEXT,
  url_arquivo TEXT NOT NULL,
  tamanho_bytes INTEGER,
  status_validacao TEXT DEFAULT 'em_analise',
  data_vencimento DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_documentos_empresa_empresa_id ON public.documentos_empresa(empresa_id);

-- Sócios completos.
CREATE TABLE IF NOT EXISTS public.socios_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  cpf_cnpj TEXT,
  qualificacao_socio TEXT,
  percentual_capital NUMERIC(5,2),
  representante_legal BOOLEAN DEFAULT FALSE,
  nome_representante TEXT,
  qualificacao_representante TEXT,
  data_entrada_sociedade DATE,
  pais TEXT,
  rg TEXT,
  data_nascimento DATE,
  estado_civil TEXT,
  profissao TEXT,
  endereco TEXT,
  conjuge_nome TEXT,
  advogado_nome TEXT,
  score INTEGER,
  restricoes TEXT,
  observacoes TEXT,
  dados_extra JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS nome_representante TEXT,
  ADD COLUMN IF NOT EXISTS qualificacao_representante TEXT,
  ADD COLUMN IF NOT EXISTS data_entrada_sociedade DATE,
  ADD COLUMN IF NOT EXISTS pais TEXT,
  ADD COLUMN IF NOT EXISTS rg TEXT,
  ADD COLUMN IF NOT EXISTS data_nascimento DATE,
  ADD COLUMN IF NOT EXISTS estado_civil TEXT,
  ADD COLUMN IF NOT EXISTS profissao TEXT,
  ADD COLUMN IF NOT EXISTS endereco TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_nome TEXT,
  ADD COLUMN IF NOT EXISTS advogado_nome TEXT,
  ADD COLUMN IF NOT EXISTS score INTEGER,
  ADD COLUMN IF NOT EXISTS restricoes TEXT,
  ADD COLUMN IF NOT EXISTS observacoes TEXT,
  ADD COLUMN IF NOT EXISTS dados_extra JSONB DEFAULT '{}'::jsonb;
CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_id ON public.socios_empresa(empresa_id);

-- Checklist automático para dossiê de crédito.
CREATE TABLE IF NOT EXISTS public.empresa_checklist_documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  socio_id UUID NULL REFERENCES public.socios_empresa(id) ON DELETE CASCADE,
  categoria TEXT NOT NULL,
  tipo_documento TEXT NOT NULL,
  nome TEXT NOT NULL,
  obrigatorio BOOLEAN NOT NULL DEFAULT TRUE,
  status TEXT NOT NULL DEFAULT 'pendente',
  origem TEXT NOT NULL DEFAULT 'automatico',
  observacao TEXT,
  arquivo_id UUID NULL,
  data_vencimento DATE NULL,
  criado_por UUID NULL REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (empresa_id, socio_id, tipo_documento)
);
CREATE INDEX IF NOT EXISTS idx_empresa_checklist_empresa_id ON public.empresa_checklist_documentos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresa_checklist_status ON public.empresa_checklist_documentos(status);
CREATE INDEX IF NOT EXISTS idx_empresa_checklist_categoria ON public.empresa_checklist_documentos(categoria);

COMMIT;


-- ============================================================
-- db/migrations/036_crm_clientes_origem_layout.sql
-- ============================================================

-- 036_crm_clientes_origem_layout.sql
-- Organização visual/operacional de clientes e origem sem regressão.
-- Todos os campos são opcionais e compatíveis com dados antigos.

ALTER TABLE IF EXISTS clientes_pf
  ADD COLUMN IF NOT EXISTS origem TEXT DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS canal TEXT,
  ADD COLUMN IF NOT EXISTS campanha TEXT,
  ADD COLUMN IF NOT EXISTS utm_source TEXT,
  ADD COLUMN IF NOT EXISTS utm_medium TEXT,
  ADD COLUMN IF NOT EXISTS utm_campaign TEXT,
  ADD COLUMN IF NOT EXISTS landing_page TEXT,
  ADD COLUMN IF NOT EXISTS produto_interesse TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ativo',
  ADD COLUMN IF NOT EXISTS ultima_interacao TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS proxima_acao TEXT,
  ADD COLUMN IF NOT EXISTS responsavel_id UUID,
  ADD COLUMN IF NOT EXISTS empresa_id UUID,
  ADD COLUMN IF NOT EXISTS tipo_cliente TEXT DEFAULT 'pf';

ALTER TABLE IF EXISTS empresas
  ADD COLUMN IF NOT EXISTS canal TEXT,
  ADD COLUMN IF NOT EXISTS campanha TEXT,
  ADD COLUMN IF NOT EXISTS utm_source TEXT,
  ADD COLUMN IF NOT EXISTS utm_medium TEXT,
  ADD COLUMN IF NOT EXISTS utm_campaign TEXT,
  ADD COLUMN IF NOT EXISTS landing_page TEXT,
  ADD COLUMN IF NOT EXISTS produto_interesse TEXT,
  ADD COLUMN IF NOT EXISTS ultima_interacao TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS proxima_acao TEXT,
  ADD COLUMN IF NOT EXISTS etapa_jornada_cliente TEXT;

ALTER TABLE IF EXISTS leads
  ADD COLUMN IF NOT EXISTS ultima_interacao TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS proxima_acao TEXT,
  ADD COLUMN IF NOT EXISTS produto_interesse TEXT;

CREATE INDEX IF NOT EXISTS idx_clientes_pf_origem ON clientes_pf(origem);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_status ON clientes_pf(status);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_responsavel ON clientes_pf(responsavel_id);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_empresa ON clientes_pf(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresas_origem ON empresas(origem);
CREATE INDEX IF NOT EXISTS idx_empresas_proxima_acao ON empresas(proxima_acao);
CREATE INDEX IF NOT EXISTS idx_leads_proxima_acao ON leads(proxima_acao);


-- ============================================================
-- db/migrations/037_simulacoes_pdf_reimpressao.sql
-- ============================================================

-- 037_simulacoes_pdf_reimpressao.sql
-- Armazena PDFs gerados nas simulações para reimpressão futura.
-- Seguro para produção: não remove nem altera dados existentes.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.simulacao_pdfs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  simulacao_id   UUID NOT NULL REFERENCES public.simulacoes_colaborador(id) ON DELETE CASCADE,
  colaborador_id UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  nome_arquivo   TEXT NOT NULL,
  mime_type      TEXT NOT NULL DEFAULT 'application/pdf',
  pdf_base64     TEXT NOT NULL,
  metadata       JSONB NOT NULL DEFAULT '{}'::jsonb,
  criado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_simulacao_pdfs_simulacao_id
  ON public.simulacao_pdfs(simulacao_id);

CREATE INDEX IF NOT EXISTS idx_simulacao_pdfs_colaborador_id
  ON public.simulacao_pdfs(colaborador_id) WHERE colaborador_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_simulacao_pdfs_criado_em
  ON public.simulacao_pdfs(criado_em DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.simulacao_pdfs TO destravadb;


-- ============================================================
-- db/migrations/038_fix_crm_mover_funil_compat.sql
-- ============================================================

-- 038_fix_crm_mover_funil_compat.sql
-- Correção resiliente para o erro 500 em POST /api/crm/mover-funil.
--
-- Causas cobertas:
-- 1) Banco com etapa_funil em enum antigo da migration 009 (entrada, contato,
--    qualificacao, proposta etc.) enquanto o frontend envia funil novo
--    (novo_lead, tentando_contato etc.). O código foi corrigido para gravar a
--    taxonomia aceita pelo banco.
-- 2) Trigger antigo trg_leads_movimentacao_funil podia falhar ao inserir em
--    crm_historico_funil porque ambientes diferentes tinham nomes de colunas
--    divergentes: etapa_de/etapa_para x etapa_anterior/etapa_nova.
-- 3) crm_atividades podia ter CHECK constraint sem status_change/origem_ia/
--    concluido, causando rollback do UPDATE de leads e 500 no endpoint.
--
-- Idempotente: seguro para reexecutar.

BEGIN;

-- ─── 1. Garantir tabelas mínimas de histórico/atividades ───────────────────
CREATE TABLE IF NOT EXISTS public.crm_historico_funil (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  motivo TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.crm_atividades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  tipo TEXT NOT NULL DEFAULT 'nota',
  titulo TEXT NOT NULL DEFAULT 'Atividade',
  descricao TEXT,
  resultado TEXT,
  origem_ia BOOLEAN DEFAULT FALSE,
  concluido BOOLEAN DEFAULT TRUE,
  agendado_para TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 2. Harmonizar colunas divergentes de crm_historico_funil ──────────────
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_de TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_para TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_anterior TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_nova TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS origem_ia BOOLEAN DEFAULT FALSE;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

UPDATE public.crm_historico_funil
   SET etapa_de = COALESCE(etapa_de, etapa_anterior),
       etapa_para = COALESCE(etapa_para, etapa_nova),
       etapa_anterior = COALESCE(etapa_anterior, etapa_de),
       etapa_nova = COALESCE(etapa_nova, etapa_para)
 WHERE etapa_de IS NULL
    OR etapa_para IS NULL
    OR etapa_anterior IS NULL
    OR etapa_nova IS NULL;

-- ─── 3. Harmonizar crm_atividades ──────────────────────────────────────────
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS titulo TEXT;
ALTER TABLE public.crm_atividades ALTER COLUMN titulo SET DEFAULT 'Atividade';
UPDATE public.crm_atividades SET titulo = COALESCE(titulo, descricao, tipo, 'Atividade') WHERE titulo IS NULL;
ALTER TABLE public.crm_atividades ALTER COLUMN titulo SET NOT NULL;

ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS descricao TEXT;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS resultado TEXT;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS origem_ia BOOLEAN DEFAULT FALSE;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS concluido BOOLEAN DEFAULT TRUE;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS agendado_para TIMESTAMPTZ;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Remover constraints antigas de tipo/resultado que bloqueiam status_change.
DO $$
DECLARE
  c RECORD;
BEGIN
  FOR c IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'public.crm_atividades'::regclass
       AND contype = 'c'
       AND (
         pg_get_constraintdef(oid) ILIKE '%tipo%'
         OR pg_get_constraintdef(oid) ILIKE '%resultado%'
       )
  LOOP
    EXECUTE format('ALTER TABLE public.crm_atividades DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;

ALTER TABLE public.crm_atividades
  ADD CONSTRAINT crm_atividades_tipo_check
  CHECK (tipo IN (
    'nota','ligacao','whatsapp','email','reuniao','proposta','documento',
    'status_change','ia_acao','followup','outro','chatwoot_message',
    'chatwoot_status','chatwoot_assignment'
  ));

ALTER TABLE public.crm_atividades
  ADD CONSTRAINT crm_atividades_resultado_check
  CHECK (resultado IS NULL OR resultado IN ('positivo','neutro','negativo','sem_resposta'));

-- ─── 4. Recriar trigger de movimentação de funil de forma compatível ───────
DROP TRIGGER IF EXISTS trg_leads_movimentacao_funil ON public.leads;

CREATE OR REPLACE FUNCTION public.fn_registrar_movimentacao_funil()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.etapa_funil IS DISTINCT FROM NEW.etapa_funil THEN
    INSERT INTO public.crm_historico_funil (
      lead_id,
      colaborador_id,
      etapa_de,
      etapa_para,
      etapa_anterior,
      etapa_nova,
      motivo,
      origem_ia,
      created_at
    ) VALUES (
      NEW.id,
      NEW.responsavel_id,
      OLD.etapa_funil::TEXT,
      NEW.etapa_funil::TEXT,
      OLD.etapa_funil::TEXT,
      NEW.etapa_funil::TEXT,
      'Movimentação via sistema',
      FALSE,
      NOW()
    );

    INSERT INTO public.crm_atividades (
      lead_id,
      colaborador_id,
      tipo,
      titulo,
      descricao,
      origem_ia,
      concluido,
      created_at
    ) VALUES (
      NEW.id,
      NEW.responsavel_id,
      'status_change',
      'Funil: ' || COALESCE(OLD.etapa_funil::TEXT, '—') || ' → ' || NEW.etapa_funil::TEXT,
      'Movimentação automática registrada pelo sistema',
      FALSE,
      TRUE,
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_leads_movimentacao_funil
  AFTER UPDATE OF etapa_funil ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_registrar_movimentacao_funil();

-- ─── 5. Índices úteis ──────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_crm_historico_funil_lead_data
  ON public.crm_historico_funil (lead_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crm_atividades_lead_data
  ON public.crm_atividades (lead_id, created_at DESC);

COMMIT;


-- ============================================================
-- db/migrations/039_clientes_empresas_melhorias.sql
-- ============================================================

-- 039_clientes_empresas_melhorias.sql
-- Melhorias incrementais: origem de clientes, status de completude,
-- vínculos empresa-simulação/contrato e campos de acompanhamento bancário por empresa.
-- Idempotente: seguro para reexecutar em banco existente.
BEGIN;

-- ─── 1. Campos de origem e completude em leads ─────────────────────────────
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS origem_detalhada TEXT,
  ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS campos_pendentes TEXT[] DEFAULT '{}';

-- ─── 2. Campos de origem e completude em clientes_pf ──────────────────────
ALTER TABLE IF EXISTS public.clientes_pf
  ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS campos_pendentes TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS origem_detalhada TEXT;

-- ─── 3. Campos de origem e completude em empresas ─────────────────────────
ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS campos_pendentes TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS origem_detalhada TEXT;

-- ─── 4. Garantir empresa_historico com campos de autor ────────────────────
CREATE TABLE IF NOT EXISTS public.empresa_historico (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID        NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  tipo       TEXT        NOT NULL DEFAULT 'nota',
  descricao  TEXT        NOT NULL,
  autor      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.empresa_historico
  ADD COLUMN IF NOT EXISTS autor TEXT;

-- ─── 5. Garantir tabela socios_empresa com campos completos ───────────────
CREATE TABLE IF NOT EXISTS public.socios_empresa (
  id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id               UUID        NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome                     TEXT        NOT NULL,
  cpf_cnpj                 TEXT,
  qualificacao_socio       TEXT,
  percentual_capital       NUMERIC(5,2),
  representante_legal      BOOLEAN     DEFAULT FALSE,
  nome_representante       TEXT,
  qualificacao_representante TEXT,
  data_entrada_sociedade   DATE,
  pais                     TEXT,
  dados_extra              JSONB       DEFAULT '{}'::jsonb,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS nome_representante TEXT,
  ADD COLUMN IF NOT EXISTS qualificacao_representante TEXT,
  ADD COLUMN IF NOT EXISTS data_entrada_sociedade DATE,
  ADD COLUMN IF NOT EXISTS pais TEXT,
  ADD COLUMN IF NOT EXISTS dados_extra JSONB DEFAULT '{}'::jsonb;

-- ─── 6. Garantir empresa_documentos com campos completos ──────────────────
CREATE TABLE IF NOT EXISTS public.empresa_documentos (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id           UUID        NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome                 TEXT        NOT NULL,
  tipo                 TEXT,
  tamanho              INTEGER,
  url                  TEXT,
  status_validacao     TEXT        DEFAULT 'em_analise',
  observacao_validacao TEXT,
  data_vencimento      DATE,
  validado_por         UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  validado_em          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.empresa_documentos
  ADD COLUMN IF NOT EXISTS status_validacao TEXT DEFAULT 'em_analise',
  ADD COLUMN IF NOT EXISTS observacao_validacao TEXT,
  ADD COLUMN IF NOT EXISTS data_vencimento DATE,
  ADD COLUMN IF NOT EXISTS validado_por UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS validado_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ─── 7. Garantir simulacoes_colaborador com empresa_id ────────────────────
ALTER TABLE public.simulacoes_colaborador
  ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cliente_empresa TEXT;

-- ─── 8. Garantir contratos_gerados com empresa_id ─────────────────────────
ALTER TABLE IF EXISTS public.contratos_gerados
  ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE SET NULL;

-- ─── 9. Garantir acompanhamentos_bancarios com empresa_id ─────────────────
ALTER TABLE IF EXISTS public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE SET NULL;

-- ─── 10. Índices de performance ───────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_leads_origem_detalhada ON public.leads(origem_detalhada);
CREATE INDEX IF NOT EXISTS idx_leads_cadastro_completo ON public.leads(cadastro_completo);
CREATE INDEX IF NOT EXISTS idx_empresas_cadastro_completo ON public.empresas(cadastro_completo);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_id ON public.socios_empresa(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresa_historico_empresa_id ON public.empresa_historico(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresa_historico_created_at ON public.empresa_historico(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_empresa_documentos_empresa_id ON public.empresa_documentos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_simulacoes_empresa_id ON public.simulacoes_colaborador(empresa_id) WHERE empresa_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contratos_gerados_empresa_id ON public.contratos_gerados(empresa_id) WHERE empresa_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_acompanhamentos_bancarios_empresa_id ON public.acompanhamentos_bancarios(empresa_id) WHERE empresa_id IS NOT NULL;

COMMIT;


-- ============================================================
-- db/migrations/040_fix_acompanhamento_bancario_salvar_atualizacao.sql
-- ============================================================

-- 040_fix_acompanhamento_bancario_salvar_atualizacao.sql
-- Corrige schemas legados do acompanhamento bancário que impediam o botão
-- "Salvar atualização semanal" de persistir a semana. Idempotente e sem perda
-- de dados.

-- Garante colunas usadas pelo backend na tabela de atualizações semanais.
ALTER TABLE IF EXISTS public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS entrada_maquininha NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS entrada_pix NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS entrada_boleto NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS entrada_ted NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS entrada_dinheiro NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS outras_entradas NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_entradas NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_saidas NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_semanal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_medio NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_final NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quantidade_transacoes INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_bacen TEXT,
  ADD COLUMN IF NOT EXISTS rating_interno TEXT,
  ADD COLUMN IF NOT EXISTS possui_restricao BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS restricao_nova BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS scr_status TEXT,
  ADD COLUMN IF NOT EXISTS cenprot_status TEXT,
  ADD COLUMN IF NOT EXISTS serasa_status TEXT,
  ADD COLUMN IF NOT EXISTS cnd_status TEXT,
  ADD COLUMN IF NOT EXISTS pld_aml_status TEXT,
  ADD COLUMN IF NOT EXISTS coaf_status TEXT,
  ADD COLUMN IF NOT EXISTS devolucao_ou_estorno BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS ocorrencia_negativa BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS status_semana TEXT DEFAULT 'neutra',
  ADD COLUMN IF NOT EXISTS analise_semana TEXT,
  ADD COLUMN IF NOT EXISTS orientacao_cliente TEXT,
  ADD COLUMN IF NOT EXISTS proxima_acao TEXT,
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS semanas_no_mes INTEGER DEFAULT 4,
  ADD COLUMN IF NOT EXISTS acumulado_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_anual NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS semanas_restantes_mes INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia TEXT,
  ADD COLUMN IF NOT EXISTS alerta_aderencia BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS motivo_alerta_aderencia TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Ambientes antigos chegaram a ter alerta_aderencia como texto ('verde',
-- 'amarelo', 'vermelho', 'critico'). O backend usa boolean; convertemos de
-- forma segura.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'acompanhamento_bancario_atualizacoes'
      AND column_name = 'alerta_aderencia'
      AND data_type <> 'boolean'
  ) THEN
    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ALTER COLUMN alerta_aderencia TYPE BOOLEAN
      USING (
        LOWER(COALESCE(alerta_aderencia::text, 'false')) IN
        ('true','t','1','sim','s','yes','y','vermelho','amarelo','critico','crítico','alerta','alta')
      );
  END IF;
END $$;

-- Garante a constraint usada pelo ON CONFLICT.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'acompanhamento_bancario_atualizacoes_acomp_semana_uniq'
  ) THEN
    ALTER TABLE public.acompanhamento_bancario_atualizacoes
      ADD CONSTRAINT acompanhamento_bancario_atualizacoes_acomp_semana_uniq
      UNIQUE (acompanhamento_id, numero_semana);
  END IF;
EXCEPTION WHEN duplicate_table OR duplicate_object THEN
  NULL;
END $$;

-- Histórico de compensações usado como log auxiliar. Deve existir, mas falhas
-- nesse histórico não devem impedir o salvamento da semana.
CREATE TABLE IF NOT EXISTS public.acompanhamento_compensacoes_historico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES public.acompanhamentos_bancarios(id) ON DELETE CASCADE,
  numero_semana INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS public.acompanhamento_compensacoes_historico
  ADD COLUMN IF NOT EXISTS data_referencia_inicio DATE,
  ADD COLUMN IF NOT EXISTS data_referencia_fim DATE,
  ADD COLUMN IF NOT EXISTS entrada_realizada NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia TEXT,
  ADD COLUMN IF NOT EXISTS alerta_aderencia BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS motivo_alerta TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico TEXT,
  ADD COLUMN IF NOT EXISTS criado_por UUID;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'acompanhamento_compensacoes_historico'
      AND column_name = 'alerta_aderencia'
      AND data_type <> 'boolean'
  ) THEN
    ALTER TABLE public.acompanhamento_compensacoes_historico
      ALTER COLUMN alerta_aderencia TYPE BOOLEAN
      USING (
        LOWER(COALESCE(alerta_aderencia::text, 'false')) IN
        ('true','t','1','sim','s','yes','y','vermelho','amarelo','critico','crítico','alerta','alta')
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'ux_acomp_comp_hist_acomp_semana'
  ) THEN
    CREATE UNIQUE INDEX ux_acomp_comp_hist_acomp_semana
      ON public.acompanhamento_compensacoes_historico(acompanhamento_id, numero_semana);
  END IF;
END $$;

-- Alertas auxiliares.
CREATE TABLE IF NOT EXISTS public.acompanhamento_bancario_alertas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acompanhamento_id UUID NOT NULL REFERENCES public.acompanhamentos_bancarios(id) ON DELETE CASCADE,
  numero_semana INTEGER,
  tipo TEXT,
  titulo TEXT,
  mensagem TEXT,
  data_alerta DATE DEFAULT CURRENT_DATE,
  status TEXT DEFAULT 'pendente',
  responsavel_id UUID,
  origem TEXT DEFAULT 'sistema',
  prioridade TEXT DEFAULT 'media',
  payload JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS public.acompanhamento_bancario_alertas
  ADD COLUMN IF NOT EXISTS atualizacao_id UUID,
  ADD COLUMN IF NOT EXISTS resolvido_em TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'ux_acomp_alertas_acomp_semana_tipo'
  ) THEN
    CREATE UNIQUE INDEX ux_acomp_alertas_acomp_semana_tipo
      ON public.acompanhamento_bancario_alertas(acompanhamento_id, numero_semana, tipo);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_acomp_banc_atualizacoes_acomp_semana
  ON public.acompanhamento_bancario_atualizacoes(acompanhamento_id, numero_semana);

CREATE INDEX IF NOT EXISTS idx_acomp_banc_alertas_acomp_status
  ON public.acompanhamento_bancario_alertas(acompanhamento_id, status);


-- ============================================================
-- db/migrations/040_fix_crm_funil_enum_to_text.sql
-- ============================================================

-- 040_fix_crm_funil_enum_to_text.sql
-- Corrige definitivamente o erro 500 em POST /api/crm/mover-funil.
--
-- Problema: migration 009 converteu leads.etapa_funil para o tipo enum
-- etapa_funil_enum. O Node/pg envia strings via $1 e o PostgreSQL rejeita
-- a atribuição direta de TEXT a ENUM sem cast explícito, causando erro 500.
--
-- Solução: converter etapa_funil de volta para TEXT com CHECK constraint
-- equivalente, preservando todos os dados existentes.
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

BEGIN;

-- ─── 1. Verificar se etapa_funil ainda é enum e converter para TEXT ─────────
DO $$
DECLARE
  v_col_type TEXT;
BEGIN
  SELECT data_type INTO v_col_type
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name   = 'leads'
     AND column_name  = 'etapa_funil';

  IF v_col_type = 'USER-DEFINED' THEN
    -- Remover default antes de alterar tipo
    ALTER TABLE public.leads ALTER COLUMN etapa_funil DROP DEFAULT;

    -- Converter enum para TEXT preservando todos os valores
    ALTER TABLE public.leads
      ALTER COLUMN etapa_funil TYPE TEXT
      USING etapa_funil::TEXT;

    -- Restaurar default como TEXT
    ALTER TABLE public.leads
      ALTER COLUMN etapa_funil SET DEFAULT 'entrada';

    RAISE NOTICE 'etapa_funil convertida de ENUM para TEXT com sucesso.';
  ELSE
    RAISE NOTICE 'etapa_funil já é TEXT (tipo: %). Nenhuma alteração necessária.', v_col_type;
  END IF;
END $$;

-- ─── 2. Garantir NOT NULL e DEFAULT ─────────────────────────────────────────
UPDATE public.leads
   SET etapa_funil = 'entrada'
 WHERE etapa_funil IS NULL OR BTRIM(etapa_funil) = '';

ALTER TABLE public.leads
  ALTER COLUMN etapa_funil SET NOT NULL,
  ALTER COLUMN etapa_funil SET DEFAULT 'entrada';

-- ─── 3. Remover qualquer CHECK antigo sobre etapa_funil em leads ─────────────
DO $$
DECLARE
  c RECORD;
BEGIN
  FOR c IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'public.leads'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%etapa_funil%'
  LOOP
    EXECUTE format('ALTER TABLE public.leads DROP CONSTRAINT %I', c.conname);
    RAISE NOTICE 'Constraint removida: %', c.conname;
  END LOOP;
END $$;

-- ─── 4. Adicionar CHECK constraint compatível com todas as etapas ────────────
-- Inclui tanto os valores da taxonomia legada (migration 009) quanto os novos
ALTER TABLE public.leads
  ADD CONSTRAINT leads_etapa_funil_check
  CHECK (etapa_funil IN (
    -- Taxonomia migration 009 (usada para persistência)
    'entrada', 'triagem', 'contato', 'qualificacao', 'documentos',
    'analise', 'proposta', 'negociacao', 'ganho', 'perdido',
    'reativacao', 'carteira',
    -- Taxonomia nova do frontend (caso algum valor novo seja gravado diretamente)
    'novo_lead', 'tentando_contato', 'em_atendimento', 'qualificado',
    'proposta_enviada', 'documentos_pendentes', 'contrato_gerado',
    'aguardando_pagamento', 'fechado', 'em_execucao', 'pos_venda',
    -- Taxonomia schema_crm antigo
    'novo', 'contato_feito', 'documentacao', 'aprovacao', 'inativo'
  ));

-- ─── 5. Garantir que o tipo enum ainda exista (não remover para compatibilidade) ─
-- O enum etapa_funil_enum pode ser usado por outras tabelas/funções;
-- não o removemos para evitar quebrar dependências.

-- ─── 6. Recriar trigger de movimentação de funil (compatível com TEXT) ───────
DROP TRIGGER IF EXISTS trg_leads_movimentacao_funil ON public.leads;

CREATE OR REPLACE FUNCTION public.fn_registrar_movimentacao_funil()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.etapa_funil IS DISTINCT FROM NEW.etapa_funil THEN
    -- Garantir que crm_historico_funil existe com as colunas necessárias
    INSERT INTO public.crm_historico_funil (
      lead_id,
      colaborador_id,
      etapa_de,
      etapa_para,
      etapa_anterior,
      etapa_nova,
      motivo,
      origem_ia,
      created_at
    ) VALUES (
      NEW.id,
      NEW.responsavel_id,
      OLD.etapa_funil::TEXT,
      NEW.etapa_funil::TEXT,
      OLD.etapa_funil::TEXT,
      NEW.etapa_funil::TEXT,
      'Movimentação via sistema',
      FALSE,
      NOW()
    );

    -- Registrar atividade automática
    INSERT INTO public.crm_atividades (
      lead_id,
      colaborador_id,
      tipo,
      titulo,
      descricao,
      origem_ia,
      concluido,
      created_at
    ) VALUES (
      NEW.id,
      NEW.responsavel_id,
      'status_change',
      'Funil: ' || COALESCE(OLD.etapa_funil::TEXT, '—') || ' → ' || NEW.etapa_funil::TEXT,
      'Movimentação automática registrada pelo sistema',
      FALSE,
      TRUE,
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_leads_movimentacao_funil
  AFTER UPDATE OF etapa_funil ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_registrar_movimentacao_funil();

-- ─── 7. Garantir crm_historico_funil com todas as colunas necessárias ────────
CREATE TABLE IF NOT EXISTS public.crm_historico_funil (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id       UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id UUID       REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  etapa_de      TEXT,
  etapa_para    TEXT,
  etapa_anterior TEXT,
  etapa_nova    TEXT,
  motivo        TEXT,
  origem_ia     BOOLEAN     DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_de       TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_para     TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_anterior TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_nova     TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS origem_ia      BOOLEAN DEFAULT FALSE;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS motivo         TEXT;

-- ─── 8. Garantir crm_atividades com tipo status_change permitido ──────────────
CREATE TABLE IF NOT EXISTS public.crm_atividades (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id        UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  tipo           TEXT        NOT NULL DEFAULT 'nota',
  titulo         TEXT        NOT NULL DEFAULT 'Atividade',
  descricao      TEXT,
  resultado      TEXT,
  origem_ia      BOOLEAN     DEFAULT FALSE,
  concluido      BOOLEAN     DEFAULT TRUE,
  agendado_para  TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS titulo       TEXT;
ALTER TABLE public.crm_atividades ALTER COLUMN titulo SET DEFAULT 'Atividade';
UPDATE public.crm_atividades SET titulo = COALESCE(titulo, descricao, tipo, 'Atividade') WHERE titulo IS NULL;
ALTER TABLE public.crm_atividades ALTER COLUMN titulo SET NOT NULL;

ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS origem_ia    BOOLEAN DEFAULT FALSE;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS concluido    BOOLEAN DEFAULT TRUE;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS descricao    TEXT;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS resultado    TEXT;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS agendado_para TIMESTAMPTZ;

-- Remover constraints antigas de tipo/resultado que possam bloquear status_change
DO $$
DECLARE
  c RECORD;
BEGIN
  FOR c IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'public.crm_atividades'::regclass
       AND contype = 'c'
       AND (
         pg_get_constraintdef(oid) ILIKE '%tipo%'
         OR pg_get_constraintdef(oid) ILIKE '%resultado%'
       )
  LOOP
    EXECUTE format('ALTER TABLE public.crm_atividades DROP CONSTRAINT IF EXISTS %I', c.conname);
    RAISE NOTICE 'Constraint removida de crm_atividades: %', c.conname;
  END LOOP;
END $$;

-- Recriar constraints abrangentes
ALTER TABLE public.crm_atividades
  ADD CONSTRAINT crm_atividades_tipo_check
  CHECK (tipo IN (
    'nota','ligacao','whatsapp','email','reuniao','proposta','documento',
    'status_change','ia_acao','followup','outro','chatwoot_message',
    'chatwoot_status','chatwoot_assignment'
  ));

ALTER TABLE public.crm_atividades
  ADD CONSTRAINT crm_atividades_resultado_check
  CHECK (resultado IS NULL OR resultado IN ('positivo','neutro','negativo','sem_resposta'));

-- ─── 9. Índices de performance ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_leads_etapa_funil
  ON public.leads (etapa_funil);

CREATE INDEX IF NOT EXISTS idx_crm_historico_funil_lead_data
  ON public.crm_historico_funil (lead_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crm_atividades_lead_data
  ON public.crm_atividades (lead_id, created_at DESC);

-- ─── 10. Garantir crm_logs existe ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_logs (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id    UUID        REFERENCES public.leads(id) ON DELETE CASCADE,
  usuario_id UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  acao       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_logs_lead_id
  ON public.crm_logs (lead_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crm_logs_usuario_id
  ON public.crm_logs (usuario_id, created_at DESC);

COMMIT;


-- ============================================================
-- db/migrations/041_leads_dedup_e_organizacao.sql
-- ============================================================

-- ============================================================
-- Migration 041: Deduplicação de leads e organização de clientes
-- Objetivo: unificar leads duplicados por telefone normalizado,
--           adicionar campo tipo_pessoa padrão, melhorar índices
--           e criar função de normalização de telefone.
-- Seguro para rodar em produção: usa IF NOT EXISTS / ON CONFLICT
-- ============================================================

BEGIN;

-- ─── 1. Função de normalização de telefone ───────────────────
-- Remove tudo que não é dígito, garante prefixo 55 e 11 dígitos
CREATE OR REPLACE FUNCTION normalizar_telefone(tel TEXT)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  digits TEXT;
BEGIN
  IF tel IS NULL THEN RETURN NULL; END IF;
  digits := regexp_replace(tel, '[^0-9]', '', 'g');
  -- Remove 0 inicial de discagem
  IF LEFT(digits, 1) = '0' THEN digits := SUBSTRING(digits FROM 2); END IF;
  -- Remove prefixo 55 se resultar em 13 dígitos (DDI + DDD + número)
  IF LENGTH(digits) = 13 AND LEFT(digits, 2) = '55' THEN
    digits := SUBSTRING(digits FROM 3);
  END IF;
  -- Garante 11 dígitos (DDD + 9 dígitos)
  IF LENGTH(digits) BETWEEN 10 AND 11 THEN
    RETURN digits;
  END IF;
  RETURN digits; -- retorna o que tiver se não bater
END;
$$;

-- ─── 2. Coluna telefone_normalizado ──────────────────────────
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS telefone_normalizado TEXT
    GENERATED ALWAYS AS (normalizar_telefone(telefone)) STORED;

-- ─── 3. Coluna tipo_pessoa padrão ────────────────────────────
-- Garante que tipo_pessoa nunca seja NULL (retroativo)
UPDATE leads SET tipo_pessoa = 'pj'
  WHERE tipo_pessoa IS NULL AND empresa IS NOT NULL;
UPDATE leads SET tipo_pessoa = 'pf'
  WHERE tipo_pessoa IS NULL;

ALTER TABLE leads
  ALTER COLUMN tipo_pessoa SET DEFAULT 'pj';

-- ─── 4. Coluna prioridade ────────────────────────────────────
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS prioridade TEXT NOT NULL DEFAULT 'media'
    CHECK (prioridade IN ('alta', 'media', 'baixa'));

-- ─── 5. Índice em telefone_normalizado para dedupe rápido ────
CREATE INDEX IF NOT EXISTS idx_leads_telefone_normalizado
  ON leads (telefone_normalizado);

-- ─── 6. Índice composto para filtros da tela de Clientes ─────
CREATE INDEX IF NOT EXISTS idx_leads_status_origem_tipo
  ON leads (status, origem, tipo_pessoa);

CREATE INDEX IF NOT EXISTS idx_leads_prioridade
  ON leads (prioridade);

-- ─── 7. Função de deduplicação: mescla leads com mesmo telefone
-- Mantém o mais antigo (maior histórico), copia dados do mais novo
-- e marca o duplicado como "cancelado" com tag "duplicado"
CREATE OR REPLACE FUNCTION deduplicar_leads_por_telefone()
RETURNS TABLE(
  mantido_id UUID,
  removido_id UUID,
  telefone_norm TEXT
) LANGUAGE plpgsql AS $$
DECLARE
  dup RECORD;
  principal_id UUID;
  duplicado_id UUID;
BEGIN
  FOR dup IN
    SELECT telefone_normalizado, COUNT(*) as qtd
    FROM leads
    WHERE telefone_normalizado IS NOT NULL
      AND status != 'cancelado'
    GROUP BY telefone_normalizado
    HAVING COUNT(*) > 1
  LOOP
    -- Pega o mais antigo como principal
    SELECT id INTO principal_id
    FROM leads
    WHERE telefone_normalizado = dup.telefone_normalizado
      AND status != 'cancelado'
    ORDER BY created_at ASC
    LIMIT 1;

    -- Para cada duplicado (mais novos), mescla e cancela
    FOR duplicado_id IN
      SELECT id FROM leads
      WHERE telefone_normalizado = dup.telefone_normalizado
        AND id != principal_id
        AND status != 'cancelado'
    LOOP
      -- Copia dados ausentes do duplicado para o principal
      UPDATE leads SET
        email       = COALESCE(email, (SELECT email FROM leads WHERE id = duplicado_id)),
        cpf_cnpj    = COALESCE(cpf_cnpj, (SELECT cpf_cnpj FROM leads WHERE id = duplicado_id)),
        empresa     = COALESCE(empresa, (SELECT empresa FROM leads WHERE id = duplicado_id)),
        cidade      = COALESCE(cidade, (SELECT cidade FROM leads WHERE id = duplicado_id)),
        estado      = COALESCE(estado, (SELECT estado FROM leads WHERE id = duplicado_id)),
        segmento    = COALESCE(segmento, (SELECT segmento FROM leads WHERE id = duplicado_id)),
        faturamento_anual = COALESCE(faturamento_anual, (SELECT faturamento_anual FROM leads WHERE id = duplicado_id)),
        tags        = COALESCE(tags, (SELECT tags FROM leads WHERE id = duplicado_id)),
        updated_at  = NOW()
      WHERE id = principal_id;

      -- Redireciona atividades do duplicado para o principal
      UPDATE crm_atividades SET lead_id = principal_id WHERE lead_id = duplicado_id;
      UPDATE crm_historico_funil SET lead_id = principal_id WHERE lead_id = duplicado_id;

      -- Marca duplicado como cancelado
      UPDATE leads SET
        status = 'cancelado',
        tags = COALESCE(tags, '') || ',duplicado',
        observacoes_ia = COALESCE(observacoes_ia, '') || ' [DUPLICADO MESCLADO COM ' || principal_id::TEXT || ']',
        updated_at = NOW()
      WHERE id = duplicado_id;

      mantido_id  := principal_id;
      removido_id := duplicado_id;
      telefone_norm := dup.telefone_normalizado;
      RETURN NEXT;
    END LOOP;
  END LOOP;
END;
$$;

-- ─── 8. View atualizada para tela de Clientes ────────────────
-- Expõe campos normalizados para o frontend
CREATE OR REPLACE VIEW vw_clientes_organizados AS
SELECT
  l.id,
  l.nome,
  l.empresa,
  l.cpf_cnpj,
  l.telefone,
  l.telefone_normalizado,
  l.email,
  COALESCE(l.tipo_pessoa, 'pj') AS tipo,
  l.cidade,
  l.estado,
  l.faturamento_anual,
  l.segmento,
  COALESCE(l.status, 'lead') AS status,
  CASE
    WHEN l.origem ILIKE '%campanha%' OR l.utm_source IS NOT NULL THEN 'campanha'
    WHEN l.origem ILIKE '%site%' OR l.origem ILIKE '%formulario%'
      OR l.origem ILIKE '%simulador%' OR l.origem ILIKE '%landing%' THEN 'site'
    WHEN l.origem ILIKE '%whatsapp%' OR l.origem ILIKE '%zap%'
      OR l.canal_origem ILIKE '%whatsapp%' THEN 'whatsapp'
    WHEN l.origem ILIKE '%indicac%' OR l.origem ILIKE '%referral%' THEN 'indicacao'
    WHEN l.origem = 'painel_interno' OR l.origem = 'manual' OR l.origem IS NULL THEN 'manual'
    ELSE LOWER(COALESCE(l.origem, 'manual'))
  END AS origem_normalizada,
  l.origem AS origem_raw,
  COALESCE(l.prioridade, 'media') AS prioridade,
  l.etapa_funil,
  l.temperatura,
  l.score_ia,
  l.tags,
  l.observacoes_ia AS observacoes,
  l.proximo_followup AS proximo_contato,
  l.n8n_notificado,
  l.responsavel_id,
  l.created_at,
  l.updated_at,
  -- Indicador de cadastro incompleto
  (l.email IS NULL OR l.cpf_cnpj IS NULL) AS cadastro_incompleto,
  -- Contagem de atividades
  (SELECT COUNT(*) FROM crm_atividades ca WHERE ca.lead_id = l.id) AS total_atividades
FROM leads l
WHERE l.status != 'cancelado'
   OR (l.tags ILIKE '%duplicado%' IS FALSE);

COMMIT;


-- ============================================================
-- db/migrations/042_score_risco_status_cadastro.sql
-- ============================================================

-- ============================================================
-- Migration 042 — Score manual, classificação de risco e
--                 status_cadastro em leads e empresas
-- Autor : Manus AI
-- Data  : 2026-05-29
-- ============================================================
-- INSTRUÇÕES DE EXECUÇÃO:
--   docker exec <container_postgres> psql -U destravadb -d postgres -f /tmp/042.sql
-- ============================================================

BEGIN;

-- ─── 1. Tabela leads ─────────────────────────────────────────────────────────

-- score_manual: pontuação definida manualmente pelo analista (0-100)
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS score_manual INTEGER
    CHECK (score_manual IS NULL OR score_manual BETWEEN 0 AND 100);

-- risco_classificacao: classificação de risco derivada do score efetivo
--   valores: 'critico' | 'alto' | 'medio' | 'baixo' | NULL
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS risco_classificacao VARCHAR(20)
    CHECK (risco_classificacao IS NULL OR
           risco_classificacao IN ('critico', 'alto', 'medio', 'baixo'));

-- status_cadastro: completude do cadastro
--   valores: 'incompleto' | 'basico' | 'completo' | 'verificado'
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS status_cadastro VARCHAR(20)
    DEFAULT 'incompleto'
    CHECK (status_cadastro IN ('incompleto', 'basico', 'completo', 'verificado'));

-- ─── 2. Tabela empresas ──────────────────────────────────────────────────────

ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS score_interno INTEGER
    CHECK (score_interno IS NULL OR score_interno BETWEEN 0 AND 100);

ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS risco_classificacao VARCHAR(20)
    CHECK (risco_classificacao IS NULL OR
           risco_classificacao IN ('critico', 'alto', 'medio', 'baixo'));

ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS status_cadastro VARCHAR(20)
    DEFAULT 'incompleto'
    CHECK (status_cadastro IN ('incompleto', 'basico', 'completo', 'verificado'));

-- ─── 3. Índices para consultas rápidas ───────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_leads_risco_classificacao
  ON leads (risco_classificacao)
  WHERE risco_classificacao IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_leads_status_cadastro
  ON leads (status_cadastro);

CREATE INDEX IF NOT EXISTS idx_leads_score_manual
  ON leads (score_manual)
  WHERE score_manual IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_empresas_risco_classificacao
  ON empresas (risco_classificacao)
  WHERE risco_classificacao IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_empresas_score_interno
  ON empresas (score_interno)
  WHERE score_interno IS NOT NULL;

-- ─── 4. Função para calcular status_cadastro de leads ────────────────────────
-- Recalcula automaticamente ao inserir ou atualizar um lead.
-- Critérios:
--   incompleto : nome ou telefone ausente
--   basico     : nome + telefone presentes
--   completo   : basico + email + (empresa ou cpf_cnpj)
--   verificado : completo + cpf_cnpj validado (não nulo) + email presente

CREATE OR REPLACE FUNCTION fn_calcular_status_cadastro_lead()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.status_cadastro :=
    CASE
      WHEN NEW.nome IS NULL OR TRIM(NEW.nome) = ''
        OR NEW.telefone IS NULL OR TRIM(NEW.telefone) = ''
        THEN 'incompleto'
      WHEN NEW.email IS NOT NULL AND TRIM(NEW.email) <> ''
        AND NEW.cpf_cnpj IS NOT NULL AND TRIM(NEW.cpf_cnpj) <> ''
        THEN 'verificado'
      WHEN NEW.email IS NOT NULL AND TRIM(NEW.email) <> ''
        AND (NEW.empresa IS NOT NULL OR NEW.cpf_cnpj IS NOT NULL)
        THEN 'completo'
      ELSE 'basico'
    END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_leads_status_cadastro ON leads;
CREATE TRIGGER trg_leads_status_cadastro
  BEFORE INSERT OR UPDATE OF nome, telefone, email, empresa, cpf_cnpj
  ON leads
  FOR EACH ROW EXECUTE FUNCTION fn_calcular_status_cadastro_lead();

-- ─── 5. Função para calcular risco_classificacao de leads ────────────────────
-- Baseado no score_efetivo = COALESCE(score_ia, score_manual, 0)
-- Crítico: 0-24 | Alto: 25-49 | Médio: 50-74 | Baixo: 75-100

CREATE OR REPLACE FUNCTION fn_calcular_risco_lead()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_score INTEGER;
BEGIN
  v_score := COALESCE(NEW.score_ia, NEW.score_manual, 0);
  NEW.risco_classificacao :=
    CASE
      WHEN v_score >= 75 THEN 'baixo'
      WHEN v_score >= 50 THEN 'medio'
      WHEN v_score >= 25 THEN 'alto'
      ELSE 'critico'
    END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_leads_risco ON leads;
CREATE TRIGGER trg_leads_risco
  BEFORE INSERT OR UPDATE OF score_ia, score_manual
  ON leads
  FOR EACH ROW EXECUTE FUNCTION fn_calcular_risco_lead();

-- ─── 6. Backfill: preencher status_cadastro e risco em registros existentes ──

UPDATE leads SET
  status_cadastro = CASE
    WHEN nome IS NULL OR TRIM(nome) = ''
      OR telefone IS NULL OR TRIM(telefone) = ''
      THEN 'incompleto'
    WHEN email IS NOT NULL AND TRIM(email) <> ''
      AND cpf_cnpj IS NOT NULL AND TRIM(cpf_cnpj) <> ''
      THEN 'verificado'
    WHEN email IS NOT NULL AND TRIM(email) <> ''
      AND (empresa IS NOT NULL OR cpf_cnpj IS NOT NULL)
      THEN 'completo'
    ELSE 'basico'
  END,
  risco_classificacao = CASE
    WHEN COALESCE(score_ia, 0) >= 75 THEN 'baixo'
    WHEN COALESCE(score_ia, 0) >= 50 THEN 'medio'
    WHEN COALESCE(score_ia, 0) >= 25 THEN 'alto'
    ELSE 'critico'
  END
WHERE status_cadastro IS NULL OR risco_classificacao IS NULL;

UPDATE empresas SET
  status_cadastro = CASE
    WHEN razao_social IS NULL OR TRIM(razao_social) = ''
      THEN 'incompleto'
    WHEN email IS NOT NULL AND cnpj IS NOT NULL
      THEN 'verificado'
    WHEN email IS NOT NULL OR cnpj IS NOT NULL
      THEN 'completo'
    ELSE 'basico'
  END
WHERE status_cadastro IS NULL;

COMMIT;


-- ============================================================
-- db/migrations/043_audit_logs.sql
-- ============================================================

-- Migration 043: Tabela de logs de auditoria
-- Registra ações críticas realizadas por usuários no sistema.

CREATE TABLE IF NOT EXISTS audit_logs (
  id            BIGSERIAL PRIMARY KEY,
  usuario_id    INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
  usuario_nome  TEXT,
  usuario_cargo TEXT,
  acao          TEXT NOT NULL,          -- ex: 'lead.status_alterado', 'contrato.gerado', 'empresa.editada'
  entidade      TEXT,                   -- ex: 'lead', 'empresa', 'contrato', 'usuario'
  entidade_id   INTEGER,                -- ID do registro afetado
  dados_antes   JSONB,                  -- snapshot antes da alteração
  dados_depois  JSONB,                  -- snapshot depois da alteração
  ip            TEXT,
  user_agent    TEXT,
  criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para consultas frequentes
CREATE INDEX IF NOT EXISTS idx_audit_logs_usuario_id  ON audit_logs(usuario_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entidade     ON audit_logs(entidade, entidade_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_acao         ON audit_logs(acao);
CREATE INDEX IF NOT EXISTS idx_audit_logs_criado_em    ON audit_logs(criado_em DESC);

COMMENT ON TABLE audit_logs IS 'Registro imutável de ações críticas realizadas por usuários no sistema Destrava.';


-- ============================================================
-- db/migrations/044_colaboradores_permissoes_granulares.sql
-- ============================================================

-- Migration: 044_colaboradores_permissoes_granulares.sql
-- Sistema Destrava Crédito
-- Corrige/instala permissões granulares dos colaboradores

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS permissoes JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS permissoes_atualizadas_por UUID NULL,
  ADD COLUMN IF NOT EXISTS permissoes_atualizadas_em TIMESTAMPTZ NULL;

UPDATE colaboradores
SET permissoes = '{}'::jsonb
WHERE permissoes IS NULL;

CREATE INDEX IF NOT EXISTS idx_colaboradores_permissoes_gin
ON colaboradores USING GIN (permissoes);

CREATE TABLE IF NOT EXISTS auditoria_permissoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  colaborador_id UUID NOT NULL,
  alterado_por UUID NULL,
  antes JSONB,
  depois JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auditoria_permissoes_colaborador_id
ON auditoria_permissoes (colaborador_id);

CREATE INDEX IF NOT EXISTS idx_auditoria_permissoes_created_at
ON auditoria_permissoes (created_at);

COMMIT;


-- ============================================================
-- db/migrations/045_cnpj_dados_completos_autosync.sql
-- ============================================================

-- Migration 045 — CNPJ completo, capital social correto e sincronização robusta
-- Idempotente. Pode ser executada mais de uma vez.

BEGIN;

ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS inscricao_estadual TEXT,
  ADD COLUMN IF NOT EXISTS inscricao_municipal TEXT,
  ADD COLUMN IF NOT EXISTS natureza_juridica TEXT,
  ADD COLUMN IF NOT EXISTS capital_social NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS cnae_principal TEXT,
  ADD COLUMN IF NOT EXISTS cnaes_secundarios TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS data_abertura DATE,
  ADD COLUMN IF NOT EXISTS situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS data_situacao_cadastral DATE,
  ADD COLUMN IF NOT EXISTS motivo_situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS matriz_filial TEXT,
  ADD COLUMN IF NOT EXISTS regime_tributario TEXT,
  ADD COLUMN IF NOT EXISTS telefone_2 TEXT,
  ADD COLUMN IF NOT EXISTS dados_extra_receita JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS ultima_sincronizacao_receita TIMESTAMPTZ;

-- Corrige capitais sociais inflados por bug de parsing anterior.
-- Ex.: 50000.00 lido como 5000000.00. Usa o payload bruto/normalizado salvo quando existir.
WITH fonte AS (
  SELECT
    id,
    COALESCE(
      NULLIF(dados_extra_receita #>> '{payload_normalizado,capital_social}', ''),
      NULLIF(dados_extra_receita #>> '{dados_fontes,brasilapi,capital_social}', ''),
      NULLIF(dados_extra_receita #>> '{dados_fontes,cnpja_open,company,equity}', ''),
      NULLIF(dados_extra_receita #>> '{dados_fontes,cnpja_open,equity}', ''),
      NULLIF(dados_extra_receita #>> '{dados_fontes,opencnpj,capital_social}', '')
    ) AS capital_texto
  FROM public.empresas
  WHERE dados_extra_receita IS NOT NULL
), normalizado AS (
  SELECT
    id,
    CASE
      WHEN capital_texto ~ '^[0-9]+([.][0-9]{1,2})?$' THEN capital_texto::numeric
      WHEN capital_texto ~ '^[0-9]+(,[0-9]{1,2})?$' THEN replace(capital_texto, ',', '.')::numeric
      WHEN capital_texto IS NOT NULL THEN NULLIF(regexp_replace(replace(replace(capital_texto, '.', ''), ',', '.'), '[^0-9.-]', '', 'g'), '')::numeric
      ELSE NULL
    END AS capital_correto
  FROM fonte
)
UPDATE public.empresas e
SET capital_social = n.capital_correto
FROM normalizado n
WHERE e.id = n.id
  AND n.capital_correto IS NOT NULL
  AND (
    e.capital_social IS NULL
    OR e.capital_social = 0
    OR e.capital_social >= n.capital_correto * 10
  );

CREATE INDEX IF NOT EXISTS idx_empresas_cnpj_digits
ON public.empresas (regexp_replace(COALESCE(cnpj, ''), '[^0-9]', '', 'g'));

CREATE INDEX IF NOT EXISTS idx_empresas_ultima_sincronizacao_receita
ON public.empresas (ultima_sincronizacao_receita DESC);

COMMIT;


-- ============================================================
-- db/migrations/045_fix_capital_social_cnpj_completo.sql
-- ============================================================

-- 045_fix_capital_social_cnpj_completo.sql
-- Corrige capital_social inflado por parsing de NUMERIC vindo como string decimal
-- Ex.: "50000.00" não pode virar 5.000.000,00.
-- Também garante colunas usadas pela página completa de Empresas/CNPJ.

BEGIN;

ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS natureza_juridica TEXT,
  ADD COLUMN IF NOT EXISTS capital_social NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS cnae_principal TEXT,
  ADD COLUMN IF NOT EXISTS cnaes_secundarios TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS data_abertura DATE,
  ADD COLUMN IF NOT EXISTS situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS matriz_filial TEXT,
  ADD COLUMN IF NOT EXISTS ultima_sincronizacao_receita TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS data_situacao_cadastral DATE,
  ADD COLUMN IF NOT EXISTS motivo_situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS regime_tributario TEXT,
  ADD COLUMN IF NOT EXISTS telefone_2 TEXT,
  ADD COLUMN IF NOT EXISTS dados_extra_receita JSONB DEFAULT '{}'::jsonb;

-- Corrige empresas cujo JSON da Receita já possui capital_social correto.
-- Atualiza somente quando o valor gravado está claramente inflado em 100x
-- ou quando a coluna está vazia.
WITH fonte AS (
  SELECT
    id,
    NULLIF(regexp_replace(dados_extra_receita->>'capital_social', '[^0-9.,-]', '', 'g'), '') AS capital_raw
  FROM public.empresas
  WHERE dados_extra_receita IS NOT NULL
    AND dados_extra_receita <> '{}'::jsonb
    AND dados_extra_receita ? 'capital_social'
), normalizada AS (
  SELECT
    id,
    CASE
      WHEN capital_raw IS NULL THEN NULL
      WHEN capital_raw LIKE '%,%' THEN replace(replace(capital_raw, '.', ''), ',', '.')::numeric
      WHEN capital_raw ~ '^[-]?[0-9]+\.[0-9]{1,2}$' THEN capital_raw::numeric
      WHEN capital_raw ~ '^[-]?[0-9]+$' THEN capital_raw::numeric
      ELSE NULL
    END AS capital_receita
  FROM fonte
)
UPDATE public.empresas e
SET capital_social = n.capital_receita
FROM normalizada n
WHERE e.id = n.id
  AND n.capital_receita IS NOT NULL
  AND (
    e.capital_social IS NULL
    OR e.capital_social = n.capital_receita * 100
    OR e.capital_social > n.capital_receita * 10
  );

CREATE INDEX IF NOT EXISTS idx_empresas_capital_social ON public.empresas(capital_social) WHERE capital_social IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_cnae_principal ON public.empresas(cnae_principal) WHERE cnae_principal IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_empresas_dados_extra_receita_gin ON public.empresas USING GIN (dados_extra_receita);

COMMIT;


-- ============================================================
-- db/migrations/046_cadastros_unicos_incompletos.sql
-- ============================================================

-- Migration 046 — Cadastros únicos, obrigatoriedade de CPF/CNPJ e área de incompletos
-- Sistema Destrava Crédito

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- EMPRESAS: classificação, bloqueio operacional e duplicidade por CNPJ
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS cadastro_status TEXT DEFAULT 'incompleto',
  ADD COLUMN IF NOT EXISTS cadastro_pendencias TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS bloqueado_operacional BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS duplicado_de UUID NULL,
  ADD COLUMN IF NOT EXISTS arquivado_por_duplicidade BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS saneado_em TIMESTAMPTZ NULL;

UPDATE empresas
SET cadastro_pendencias = array_remove(ARRAY[
      CASE WHEN length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) <> 14 THEN 'CNPJ obrigatório/ inválido' END,
      CASE WHEN trim(COALESCE(razao_social,'')) = '' THEN 'Razão social obrigatória' END,
      CASE WHEN trim(COALESCE(cnae_principal,'')) = '' THEN 'CNAE principal não sincronizado' END,
      CASE WHEN trim(COALESCE(natureza_juridica,'')) = '' THEN 'Natureza jurídica não sincronizada' END,
      CASE WHEN capital_social IS NULL OR capital_social <= 0 THEN 'Capital social não sincronizado' END,
      CASE WHEN trim(COALESCE(situacao_cadastral,'')) = '' THEN 'Situação cadastral não sincronizada' END
    ]::TEXT[], NULL),
    cadastro_completo = (
      length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
      AND trim(COALESCE(razao_social,'')) <> ''
      AND trim(COALESCE(cnae_principal,'')) <> ''
      AND trim(COALESCE(natureza_juridica,'')) <> ''
      AND capital_social IS NOT NULL AND capital_social > 0
      AND trim(COALESCE(situacao_cadastral,'')) <> ''
    ),
    cadastro_status = CASE WHEN (
      length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
      AND trim(COALESCE(razao_social,'')) <> ''
      AND trim(COALESCE(cnae_principal,'')) <> ''
      AND trim(COALESCE(natureza_juridica,'')) <> ''
      AND capital_social IS NOT NULL AND capital_social > 0
      AND trim(COALESCE(situacao_cadastral,'')) <> ''
    ) THEN 'completo' ELSE 'incompleto' END,
    bloqueado_operacional = NOT (
      length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
      AND trim(COALESCE(razao_social,'')) <> ''
      AND trim(COALESCE(cnae_principal,'')) <> ''
      AND trim(COALESCE(natureza_juridica,'')) <> ''
      AND capital_social IS NOT NULL AND capital_social > 0
      AND trim(COALESCE(situacao_cadastral,'')) <> ''
    ),
    saneado_em = CASE WHEN (
      length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
      AND trim(COALESCE(razao_social,'')) <> ''
      AND trim(COALESCE(cnae_principal,'')) <> ''
      AND trim(COALESCE(natureza_juridica,'')) <> ''
      AND capital_social IS NOT NULL AND capital_social > 0
      AND trim(COALESCE(situacao_cadastral,'')) <> ''
    ) THEN COALESCE(saneado_em, NOW()) ELSE saneado_em END;

DROP TABLE IF EXISTS tmp_empresas_duplicadas_046;
CREATE TEMP TABLE tmp_empresas_duplicadas_046 AS
WITH ranked AS (
  SELECT id,
         FIRST_VALUE(id) OVER (
           PARTITION BY regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')
           ORDER BY COALESCE(ultima_sincronizacao_receita, updated_at, created_at) DESC NULLS LAST, created_at ASC NULLS LAST, id
         ) AS master_id,
         ROW_NUMBER() OVER (
           PARTITION BY regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')
           ORDER BY COALESCE(ultima_sincronizacao_receita, updated_at, created_at) DESC NULLS LAST, created_at ASC NULLS LAST, id
         ) AS rn
    FROM empresas
   WHERE length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
)
SELECT id AS duplicado_id, master_id
FROM ranked
WHERE rn > 1;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['leads','triagem_leads','simulacoes_colaborador','contratos_gerados'] LOOP
    IF to_regclass(t) IS NOT NULL THEN
      EXECUTE format('UPDATE %I r SET empresa_id = d.master_id FROM tmp_empresas_duplicadas_046 d WHERE r.empresa_id = d.duplicado_id', t);
    END IF;
  END LOOP;
END $$;

UPDATE empresas e
SET arquivado_por_duplicidade = true,
    duplicado_de = d.master_id,
    bloqueado_operacional = true,
    cadastro_completo = false,
    cadastro_status = 'duplicado',
    cadastro_pendencias = ARRAY['Cadastro duplicado arquivado. Usar cadastro principal: ' || d.master_id::text],
    status = CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='empresas' AND column_name='status') THEN 'inativo' ELSE status END
FROM tmp_empresas_duplicadas_046 d
WHERE e.id = d.duplicado_id;

-- Remove automaticamente duplicados totais após redirecionar referências conhecidas.
-- Se alguma FK externa bloquear, o registro segue arquivado e fica disponível para apagar na tela Cadastros Incompletos.
DO $$
BEGIN
  DELETE FROM empresas e
  USING tmp_empresas_duplicadas_046 d
  WHERE e.id = d.duplicado_id;
EXCEPTION WHEN foreign_key_violation THEN
  RAISE NOTICE 'Algumas empresas duplicadas não puderam ser apagadas por vínculo externo; permaneceram arquivadas para revisão.';
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_empresas_cnpj_unico_ativo
ON empresas ((regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')))
WHERE length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
  AND COALESCE(arquivado_por_duplicidade, false) = false;

CREATE INDEX IF NOT EXISTS idx_empresas_cadastro_status ON empresas (cadastro_status);
CREATE INDEX IF NOT EXISTS idx_empresas_cadastro_completo ON empresas (cadastro_completo, bloqueado_operacional);
CREATE INDEX IF NOT EXISTS idx_empresas_duplicado_de ON empresas (duplicado_de);

-- ─────────────────────────────────────────────────────────────────────────────
-- CLIENTES PF: CPF obrigatório/único e bloqueio quando incompleto
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE clientes_pf
  ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS cadastro_status TEXT DEFAULT 'incompleto',
  ADD COLUMN IF NOT EXISTS cadastro_pendencias TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS bloqueado_operacional BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS duplicado_de UUID NULL,
  ADD COLUMN IF NOT EXISTS arquivado_por_duplicidade BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS saneado_em TIMESTAMPTZ NULL;

UPDATE clientes_pf
SET cadastro_pendencias = array_remove(ARRAY[
      CASE WHEN length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) <> 11 THEN 'CPF obrigatório/ inválido' END,
      CASE WHEN trim(COALESCE(nome,'')) = '' THEN 'Nome obrigatório' END
    ]::TEXT[], NULL),
    cadastro_completo = (length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11 AND trim(COALESCE(nome,'')) <> ''),
    cadastro_status = CASE WHEN (length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11 AND trim(COALESCE(nome,'')) <> '') THEN 'completo' ELSE 'incompleto' END,
    bloqueado_operacional = NOT (length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11 AND trim(COALESCE(nome,'')) <> ''),
    saneado_em = CASE WHEN (length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11 AND trim(COALESCE(nome,'')) <> '') THEN COALESCE(saneado_em, NOW()) ELSE saneado_em END;

DROP TABLE IF EXISTS tmp_clientes_pf_duplicados_046;
CREATE TEMP TABLE tmp_clientes_pf_duplicados_046 AS
WITH ranked AS (
  SELECT id,
         FIRST_VALUE(id) OVER (PARTITION BY regexp_replace(COALESCE(cpf,''), '\D', '', 'g') ORDER BY COALESCE(updated_at, created_at) DESC NULLS LAST, created_at ASC NULLS LAST, id) AS master_id,
         ROW_NUMBER() OVER (PARTITION BY regexp_replace(COALESCE(cpf,''), '\D', '', 'g') ORDER BY COALESCE(updated_at, created_at) DESC NULLS LAST, created_at ASC NULLS LAST, id) AS rn
    FROM clientes_pf
   WHERE length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11
)
SELECT id AS duplicado_id, master_id
FROM ranked
WHERE rn > 1;

DO $$
BEGIN
  IF to_regclass('contratos_gerados') IS NOT NULL THEN
    UPDATE contratos_gerados c SET cliente_pf_id = d.master_id
    FROM tmp_clientes_pf_duplicados_046 d
    WHERE c.cliente_pf_id = d.duplicado_id;
  END IF;
END $$;

UPDATE clientes_pf c
SET arquivado_por_duplicidade = true,
    duplicado_de = d.master_id,
    ativo = false,
    bloqueado_operacional = true,
    cadastro_completo = false,
    cadastro_status = 'duplicado',
    cadastro_pendencias = ARRAY['Cadastro duplicado arquivado. Usar cadastro principal: ' || d.master_id::text]
FROM tmp_clientes_pf_duplicados_046 d
WHERE c.id = d.duplicado_id;

-- Remove automaticamente duplicados totais após redirecionar referências conhecidas.
DO $$
BEGIN
  DELETE FROM clientes_pf c
  USING tmp_clientes_pf_duplicados_046 d
  WHERE c.id = d.duplicado_id;
EXCEPTION WHEN foreign_key_violation THEN
  RAISE NOTICE 'Alguns clientes PF duplicados não puderam ser apagados por vínculo externo; permaneceram inativos/arquivados para revisão.';
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_clientes_pf_cpf_unico_ativo
ON clientes_pf ((regexp_replace(COALESCE(cpf,''), '\D', '', 'g')))
WHERE length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11
  AND COALESCE(arquivado_por_duplicidade, false) = false;

CREATE INDEX IF NOT EXISTS idx_clientes_pf_cadastro_status ON clientes_pf (cadastro_status);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_cadastro_completo ON clientes_pf (cadastro_completo, bloqueado_operacional);

-- ─────────────────────────────────────────────────────────────────────────────
-- LEADS/CLIENTES CRM: documento obrigatório e único para a tela de Clientes
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS cadastro_status TEXT DEFAULT 'incompleto',
  ADD COLUMN IF NOT EXISTS cadastro_pendencias TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS bloqueado_operacional BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS duplicado_de UUID NULL,
  ADD COLUMN IF NOT EXISTS arquivado_por_duplicidade BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS saneado_em TIMESTAMPTZ NULL;

UPDATE leads
SET cadastro_pendencias = array_remove(ARRAY[
      CASE WHEN trim(COALESCE(nome,'')) = '' THEN 'Nome obrigatório' END,
      CASE WHEN COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) <> 14 THEN 'CNPJ obrigatório/ inválido' END,
      CASE WHEN COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) <> 11 THEN 'CPF obrigatório/ inválido' END
    ]::TEXT[], NULL),
    cadastro_completo = (
      trim(COALESCE(nome,'')) <> '' AND (
        (COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 14)
        OR (COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 11)
      )
    ),
    cadastro_status = CASE WHEN (
      trim(COALESCE(nome,'')) <> '' AND (
        (COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 14)
        OR (COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 11)
      )
    ) THEN 'completo' ELSE 'incompleto' END,
    bloqueado_operacional = NOT (
      trim(COALESCE(nome,'')) <> '' AND (
        (COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 14)
        OR (COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 11)
      )
    ),
    saneado_em = CASE WHEN (
      trim(COALESCE(nome,'')) <> '' AND (
        (COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 14)
        OR (COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 11)
      )
    ) THEN COALESCE(saneado_em, NOW()) ELSE saneado_em END;

DROP TABLE IF EXISTS tmp_leads_duplicados_046;
CREATE TEMP TABLE tmp_leads_duplicados_046 AS
WITH ranked AS (
  SELECT id,
         FIRST_VALUE(id) OVER (PARTITION BY regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g') ORDER BY COALESCE(updated_at, created_at) DESC NULLS LAST, created_at ASC NULLS LAST, id) AS master_id,
         ROW_NUMBER() OVER (PARTITION BY regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g') ORDER BY COALESCE(updated_at, created_at) DESC NULLS LAST, created_at ASC NULLS LAST, id) AS rn
    FROM leads
   WHERE length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) IN (11,14)
)
SELECT id AS duplicado_id, master_id
FROM ranked
WHERE rn > 1;

DO $$
BEGIN
  IF to_regclass('crm_atividades') IS NOT NULL THEN
    UPDATE crm_atividades a SET lead_id = d.master_id
    FROM tmp_leads_duplicados_046 d
    WHERE a.lead_id = d.duplicado_id;
  END IF;
  IF to_regclass('contratos_gerados') IS NOT NULL THEN
    UPDATE contratos_gerados c SET lead_id = d.master_id
    FROM tmp_leads_duplicados_046 d
    WHERE c.lead_id = d.duplicado_id;
  END IF;
END $$;

UPDATE leads l
SET arquivado_por_duplicidade = true,
    duplicado_de = d.master_id,
    bloqueado_operacional = true,
    cadastro_completo = false,
    cadastro_status = 'duplicado',
    cadastro_pendencias = ARRAY['Cadastro duplicado arquivado. Usar cadastro principal: ' || d.master_id::text],
    status = COALESCE(NULLIF(status, ''), 'cancelado')
FROM tmp_leads_duplicados_046 d
WHERE l.id = d.duplicado_id;

-- Remove automaticamente duplicados totais após redirecionar referências conhecidas.
DO $$
BEGIN
  DELETE FROM leads l
  USING tmp_leads_duplicados_046 d
  WHERE l.id = d.duplicado_id;
EXCEPTION WHEN foreign_key_violation THEN
  RAISE NOTICE 'Alguns leads duplicados não puderam ser apagados por vínculo externo; permaneceram arquivados para revisão.';
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_leads_documento_unico_ativo
ON leads ((regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')))
WHERE length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) IN (11,14)
  AND COALESCE(arquivado_por_duplicidade, false) = false;

CREATE INDEX IF NOT EXISTS idx_leads_cadastro_status ON leads (cadastro_status);
CREATE INDEX IF NOT EXISTS idx_leads_cadastro_completo ON leads (cadastro_completo, bloqueado_operacional);

COMMIT;


-- ============================================================
-- db/migrations/046_cadastros_unicos_incompletos_SAFE.sql
-- ============================================================

-- Migration 046 SAFE — Cadastros únicos, incompletos e bloqueio operacional
-- Sistema Destrava Crédito
-- Execute antes do deploy da versão que usa a nova regra de cadastros.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- EMPRESAS
-- ============================================================
ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS cadastro_status TEXT DEFAULT 'incompleto',
  ADD COLUMN IF NOT EXISTS cadastro_pendencias TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS bloqueado_operacional BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS duplicado_de UUID NULL,
  ADD COLUMN IF NOT EXISTS arquivado_por_duplicidade BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS saneado_em TIMESTAMPTZ NULL;

UPDATE empresas
SET cadastro_pendencias = array_remove(ARRAY[
      CASE WHEN length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) <> 14 THEN 'CNPJ obrigatório/ inválido' END,
      CASE WHEN trim(COALESCE(razao_social,'')) = '' THEN 'Razão social obrigatória' END,
      CASE WHEN trim(COALESCE(cnae_principal,'')) = '' THEN 'CNAE principal não sincronizado' END,
      CASE WHEN trim(COALESCE(natureza_juridica,'')) = '' THEN 'Natureza jurídica não sincronizada' END,
      CASE WHEN capital_social IS NULL OR capital_social <= 0 THEN 'Capital social não sincronizado' END,
      CASE WHEN trim(COALESCE(situacao_cadastral,'')) = '' THEN 'Situação cadastral não sincronizada' END
    ]::TEXT[], NULL),
    cadastro_completo = (
      length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
      AND trim(COALESCE(razao_social,'')) <> ''
      AND trim(COALESCE(cnae_principal,'')) <> ''
      AND trim(COALESCE(natureza_juridica,'')) <> ''
      AND capital_social IS NOT NULL AND capital_social > 0
      AND trim(COALESCE(situacao_cadastral,'')) <> ''
    ),
    cadastro_status = CASE WHEN (
      length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
      AND trim(COALESCE(razao_social,'')) <> ''
      AND trim(COALESCE(cnae_principal,'')) <> ''
      AND trim(COALESCE(natureza_juridica,'')) <> ''
      AND capital_social IS NOT NULL AND capital_social > 0
      AND trim(COALESCE(situacao_cadastral,'')) <> ''
    ) THEN 'completo' ELSE 'incompleto' END,
    bloqueado_operacional = NOT (
      length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
      AND trim(COALESCE(razao_social,'')) <> ''
      AND trim(COALESCE(cnae_principal,'')) <> ''
      AND trim(COALESCE(natureza_juridica,'')) <> ''
      AND capital_social IS NOT NULL AND capital_social > 0
      AND trim(COALESCE(situacao_cadastral,'')) <> ''
    ),
    saneado_em = CASE WHEN (
      length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
      AND trim(COALESCE(razao_social,'')) <> ''
      AND trim(COALESCE(cnae_principal,'')) <> ''
      AND trim(COALESCE(natureza_juridica,'')) <> ''
      AND capital_social IS NOT NULL AND capital_social > 0
      AND trim(COALESCE(situacao_cadastral,'')) <> ''
    ) THEN COALESCE(saneado_em, NOW()) ELSE saneado_em END;

DROP TABLE IF EXISTS tmp_empresas_duplicadas_046;
CREATE TEMP TABLE tmp_empresas_duplicadas_046 AS
WITH ranked AS (
  SELECT id,
         FIRST_VALUE(id) OVER (
           PARTITION BY regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')
           ORDER BY COALESCE(ultima_sincronizacao_receita, updated_at, created_at) DESC NULLS LAST, created_at ASC NULLS LAST, id
         ) AS master_id,
         ROW_NUMBER() OVER (
           PARTITION BY regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')
           ORDER BY COALESCE(ultima_sincronizacao_receita, updated_at, created_at) DESC NULLS LAST, created_at ASC NULLS LAST, id
         ) AS rn
    FROM empresas
   WHERE length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
)
SELECT id AS duplicado_id, master_id
FROM ranked
WHERE rn > 1;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT table_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name = 'empresa_id'
      AND table_name IN ('leads','triagem_leads','simulacoes_colaborador','contratos_gerados','contratos','simulacoes')
  LOOP
    EXECUTE format(
      'UPDATE %I t SET empresa_id = d.master_id FROM tmp_empresas_duplicadas_046 d WHERE t.empresa_id = d.duplicado_id',
      r.table_name
    );
  END LOOP;
END $$;

UPDATE empresas e
SET arquivado_por_duplicidade = true,
    duplicado_de = d.master_id,
    bloqueado_operacional = true,
    cadastro_completo = false,
    cadastro_status = 'duplicado',
    cadastro_pendencias = ARRAY['Cadastro duplicado arquivado. Usar cadastro principal: ' || d.master_id::text]
FROM tmp_empresas_duplicadas_046 d
WHERE e.id = d.duplicado_id;

CREATE UNIQUE INDEX IF NOT EXISTS ux_empresas_cnpj_unico_ativo
ON empresas ((regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')))
WHERE length(regexp_replace(COALESCE(cnpj,''), '\D', '', 'g')) = 14
  AND COALESCE(arquivado_por_duplicidade, false) = false;

CREATE INDEX IF NOT EXISTS idx_empresas_cadastro_status ON empresas (cadastro_status);
CREATE INDEX IF NOT EXISTS idx_empresas_cadastro_completo ON empresas (cadastro_completo, bloqueado_operacional);
CREATE INDEX IF NOT EXISTS idx_empresas_duplicado_de ON empresas (duplicado_de);

-- ============================================================
-- CLIENTES PF
-- ============================================================
DO $$
BEGIN
  IF to_regclass('public.clientes_pf') IS NOT NULL THEN
    ALTER TABLE clientes_pf
      ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS cadastro_status TEXT DEFAULT 'incompleto',
      ADD COLUMN IF NOT EXISTS cadastro_pendencias TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS bloqueado_operacional BOOLEAN DEFAULT true,
      ADD COLUMN IF NOT EXISTS duplicado_de UUID NULL,
      ADD COLUMN IF NOT EXISTS arquivado_por_duplicidade BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS saneado_em TIMESTAMPTZ NULL;

    UPDATE clientes_pf
    SET cadastro_pendencias = array_remove(ARRAY[
          CASE WHEN length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) <> 11 THEN 'CPF obrigatório/ inválido' END,
          CASE WHEN trim(COALESCE(nome,'')) = '' THEN 'Nome obrigatório' END
        ]::TEXT[], NULL),
        cadastro_completo = (length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11 AND trim(COALESCE(nome,'')) <> ''),
        cadastro_status = CASE WHEN (length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11 AND trim(COALESCE(nome,'')) <> '') THEN 'completo' ELSE 'incompleto' END,
        bloqueado_operacional = NOT (length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11 AND trim(COALESCE(nome,'')) <> ''),
        saneado_em = CASE WHEN (length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11 AND trim(COALESCE(nome,'')) <> '') THEN COALESCE(saneado_em, NOW()) ELSE saneado_em END;

    DROP TABLE IF EXISTS tmp_clientes_pf_duplicados_046;
    CREATE TEMP TABLE tmp_clientes_pf_duplicados_046 AS
    WITH ranked AS (
      SELECT id,
             FIRST_VALUE(id) OVER (PARTITION BY regexp_replace(COALESCE(cpf,''), '\D', '', 'g') ORDER BY updated_at DESC NULLS LAST, created_at ASC NULLS LAST, id) AS master_id,
             ROW_NUMBER() OVER (PARTITION BY regexp_replace(COALESCE(cpf,''), '\D', '', 'g') ORDER BY updated_at DESC NULLS LAST, created_at ASC NULLS LAST, id) AS rn
      FROM clientes_pf
      WHERE length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11
    )
    SELECT id AS duplicado_id, master_id
    FROM ranked
    WHERE rn > 1;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='contratos_gerados' AND column_name='cliente_pf_id') THEN
      UPDATE contratos_gerados c SET cliente_pf_id = d.master_id
      FROM tmp_clientes_pf_duplicados_046 d
      WHERE c.cliente_pf_id = d.duplicado_id;
    END IF;

    UPDATE clientes_pf c
    SET arquivado_por_duplicidade = true,
        duplicado_de = d.master_id,
        ativo = false,
        bloqueado_operacional = true,
        cadastro_completo = false,
        cadastro_status = 'duplicado',
        cadastro_pendencias = ARRAY['Cadastro duplicado arquivado. Usar cadastro principal: ' || d.master_id::text]
    FROM tmp_clientes_pf_duplicados_046 d
    WHERE c.id = d.duplicado_id;

    CREATE UNIQUE INDEX IF NOT EXISTS ux_clientes_pf_cpf_unico_ativo
    ON clientes_pf ((regexp_replace(COALESCE(cpf,''), '\D', '', 'g')))
    WHERE length(regexp_replace(COALESCE(cpf,''), '\D', '', 'g')) = 11
      AND COALESCE(arquivado_por_duplicidade, false) = false;

    CREATE INDEX IF NOT EXISTS idx_clientes_pf_cadastro_status ON clientes_pf (cadastro_status);
    CREATE INDEX IF NOT EXISTS idx_clientes_pf_cadastro_completo ON clientes_pf (cadastro_completo, bloqueado_operacional);
  END IF;
END $$;

-- ============================================================
-- LEADS / CLIENTES CRM
-- ============================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  IF to_regclass('public.leads') IS NOT NULL THEN
    ALTER TABLE leads
      ADD COLUMN IF NOT EXISTS cadastro_completo BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS cadastro_status TEXT DEFAULT 'incompleto',
      ADD COLUMN IF NOT EXISTS cadastro_pendencias TEXT[] DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS bloqueado_operacional BOOLEAN DEFAULT true,
      ADD COLUMN IF NOT EXISTS duplicado_de UUID NULL,
      ADD COLUMN IF NOT EXISTS arquivado_por_duplicidade BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS saneado_em TIMESTAMPTZ NULL;

    UPDATE leads
    SET cadastro_pendencias = array_remove(ARRAY[
          CASE WHEN trim(COALESCE(nome,'')) = '' THEN 'Nome obrigatório' END,
          CASE WHEN COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) <> 14 THEN 'CNPJ obrigatório/ inválido' END,
          CASE WHEN COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) <> 11 THEN 'CPF obrigatório/ inválido' END
        ]::TEXT[], NULL),
        cadastro_completo = (
          trim(COALESCE(nome,'')) <> '' AND (
            (COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 14)
            OR (COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 11)
          )
        ),
        cadastro_status = CASE WHEN (
          trim(COALESCE(nome,'')) <> '' AND (
            (COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 14)
            OR (COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 11)
          )
        ) THEN 'completo' ELSE 'incompleto' END,
        bloqueado_operacional = NOT (
          trim(COALESCE(nome,'')) <> '' AND (
            (COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 14)
            OR (COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 11)
          )
        ),
        saneado_em = CASE WHEN (
          trim(COALESCE(nome,'')) <> '' AND (
            (COALESCE(tipo_pessoa,'pf') = 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 14)
            OR (COALESCE(tipo_pessoa,'pf') <> 'pj' AND length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) = 11)
          )
        ) THEN COALESCE(saneado_em, NOW()) ELSE saneado_em END;

    DROP TABLE IF EXISTS tmp_leads_duplicados_046;
    CREATE TEMP TABLE tmp_leads_duplicados_046 AS
    WITH ranked AS (
      SELECT id,
             FIRST_VALUE(id) OVER (PARTITION BY regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g') ORDER BY updated_at DESC NULLS LAST, created_at ASC NULLS LAST, id) AS master_id,
             ROW_NUMBER() OVER (PARTITION BY regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g') ORDER BY updated_at DESC NULLS LAST, created_at ASC NULLS LAST, id) AS rn
      FROM leads
      WHERE length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) IN (11,14)
    )
    SELECT id AS duplicado_id, master_id
    FROM ranked
    WHERE rn > 1;

    FOR r IN
      SELECT table_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND column_name = 'lead_id'
        AND table_name IN ('crm_atividades','contratos_gerados','simulacoes_colaborador','triagem_leads')
    LOOP
      EXECUTE format(
        'UPDATE %I t SET lead_id = d.master_id FROM tmp_leads_duplicados_046 d WHERE t.lead_id = d.duplicado_id',
        r.table_name
      );
    END LOOP;

    UPDATE leads l
    SET arquivado_por_duplicidade = true,
        duplicado_de = d.master_id,
        bloqueado_operacional = true,
        cadastro_completo = false,
        cadastro_status = 'duplicado',
        cadastro_pendencias = ARRAY['Cadastro duplicado arquivado. Usar cadastro principal: ' || d.master_id::text]
    FROM tmp_leads_duplicados_046 d
    WHERE l.id = d.duplicado_id;

    CREATE UNIQUE INDEX IF NOT EXISTS ux_leads_documento_unico_ativo
    ON leads ((regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')))
    WHERE length(regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')) IN (11,14)
      AND COALESCE(arquivado_por_duplicidade, false) = false;

    CREATE INDEX IF NOT EXISTS idx_leads_cadastro_status ON leads (cadastro_status);
    CREATE INDEX IF NOT EXISTS idx_leads_cadastro_completo ON leads (cadastro_completo, bloqueado_operacional);
  END IF;
END $$;

COMMIT;


-- ============================================================
-- db/migrations/047_socios_representantes_dados_contrato.sql
-- ============================================================

-- ============================================================
-- 047_socios_representantes_dados_contrato.sql
-- Destrava Crédito
-- Expande sócios/representantes para contratos e análises.
-- Mantém dados públicos importados das APIs de CNPJ e campos manuais
-- necessários para contrato: CPF completo, RG, estado civil, cônjuge,
-- regime de bens, profissão, contato e endereço residencial.
-- Idempotente.
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.socios_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  cpf_cnpj TEXT,
  qualificacao_socio TEXT,
  percentual_capital NUMERIC(5,2),
  representante_legal BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS nome_representante TEXT,
  ADD COLUMN IF NOT EXISTS qualificacao_representante TEXT,
  ADD COLUMN IF NOT EXISTS data_entrada_sociedade DATE,
  ADD COLUMN IF NOT EXISTS pais TEXT,
  ADD COLUMN IF NOT EXISTS rg TEXT,
  ADD COLUMN IF NOT EXISTS rg_orgao_emissor TEXT,
  ADD COLUMN IF NOT EXISTS rg_uf_emissao CHAR(2),
  ADD COLUMN IF NOT EXISTS rg_data_emissao DATE,
  ADD COLUMN IF NOT EXISTS data_nascimento DATE,
  ADD COLUMN IF NOT EXISTS nacionalidade TEXT DEFAULT 'Brasileiro(a)',
  ADD COLUMN IF NOT EXISTS estado_civil TEXT,
  ADD COLUMN IF NOT EXISTS profissao TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS telefone TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp TEXT,
  ADD COLUMN IF NOT EXISTS cep TEXT,
  ADD COLUMN IF NOT EXISTS logradouro TEXT,
  ADD COLUMN IF NOT EXISTS numero TEXT,
  ADD COLUMN IF NOT EXISTS complemento TEXT,
  ADD COLUMN IF NOT EXISTS bairro TEXT,
  ADD COLUMN IF NOT EXISTS cidade TEXT,
  ADD COLUMN IF NOT EXISTS uf CHAR(2),
  ADD COLUMN IF NOT EXISTS conjuge_nome TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_cpf TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_rg TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_data_nasc DATE,
  ADD COLUMN IF NOT EXISTS conjuge_profissao TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_email TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_telefone TEXT,
  ADD COLUMN IF NOT EXISTS regime_bens TEXT,
  ADD COLUMN IF NOT EXISTS pep BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS fonte_dados TEXT,
  ADD COLUMN IF NOT EXISTS dados_extra JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS dados_extras JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS observacoes TEXT;

UPDATE public.socios_empresa
SET nacionalidade = COALESCE(NULLIF(nacionalidade, ''), 'Brasileiro(a)'),
    ativo = COALESCE(ativo, true),
    fonte_dados = COALESCE(NULLIF(fonte_dados, ''), 'api_publica_cnpj'),
    dados_extra = COALESCE(dados_extra, '{}'::jsonb),
    dados_extras = COALESCE(dados_extras, '{}'::jsonb)
WHERE nacionalidade IS NULL
   OR ativo IS NULL
   OR fonte_dados IS NULL
   OR dados_extra IS NULL
   OR dados_extras IS NULL;

CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_id
  ON public.socios_empresa(empresa_id);

CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpf_cnpj_digits
  ON public.socios_empresa ((regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g')));

CREATE INDEX IF NOT EXISTS idx_socios_empresa_ativo
  ON public.socios_empresa(empresa_id, ativo);

CREATE INDEX IF NOT EXISTS idx_socios_empresa_representante
  ON public.socios_empresa(empresa_id, representante_legal)
  WHERE COALESCE(ativo, true) = true;

CREATE INDEX IF NOT EXISTS idx_socios_empresa_conjuge_cpf
  ON public.socios_empresa(conjuge_cpf)
  WHERE conjuge_cpf IS NOT NULL;

-- Permite documentos societários vinculados a sócios quando a tabela GED existir/for criada.
CREATE TABLE IF NOT EXISTS public.documentos_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  socio_id UUID NULL REFERENCES public.socios_empresa(id) ON DELETE CASCADE,
  nome_arquivo TEXT NOT NULL,
  tipo_documento TEXT NOT NULL DEFAULT 'outro',
  url_arquivo TEXT NOT NULL,
  tamanho_bytes BIGINT,
  status_validacao TEXT DEFAULT 'pendente',
  data_vencimento DATE,
  observacoes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.documentos_empresa
  ADD COLUMN IF NOT EXISTS socio_id UUID NULL REFERENCES public.socios_empresa(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS status_validacao TEXT DEFAULT 'pendente',
  ADD COLUMN IF NOT EXISTS observacoes TEXT;

CREATE INDEX IF NOT EXISTS idx_documentos_empresa_socios
  ON public.documentos_empresa(empresa_id, socio_id, tipo_documento);

COMMIT;


-- ============================================================
-- db/migrations/048_unificar_clientes_menu_origem.sql
-- ============================================================

-- Migration 048 — Unificação de Clientes e origem de cadastro PF
-- Sistema Destrava Crédito
-- Prepara clientes_pf para aparecerem na tela unificada de Clientes com origem, canal e usuário cadastrador.

BEGIN;

ALTER TABLE clientes_pf
  ADD COLUMN IF NOT EXISTS origem TEXT DEFAULT 'painel_interno',
  ADD COLUMN IF NOT EXISTS canal_origem TEXT NULL,
  ADD COLUMN IF NOT EXISTS fonte_cadastro TEXT DEFAULT 'Cliente PF cadastrado manualmente',
  ADD COLUMN IF NOT EXISTS cadastrado_por UUID NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'colaboradores'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'clientes_pf_cadastrado_por_fkey'
    ) THEN
      ALTER TABLE clientes_pf
        ADD CONSTRAINT clientes_pf_cadastrado_por_fkey
        FOREIGN KEY (cadastrado_por) REFERENCES colaboradores(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

UPDATE clientes_pf
SET origem = COALESCE(NULLIF(origem, ''), 'painel_interno'),
    fonte_cadastro = COALESCE(NULLIF(fonte_cadastro, ''), 'Cliente PF cadastrado manualmente')
WHERE origem IS NULL OR origem = '' OR fonte_cadastro IS NULL OR fonte_cadastro = '';

CREATE INDEX IF NOT EXISTS idx_clientes_pf_origem ON clientes_pf (origem);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_cadastrado_por ON clientes_pf (cadastrado_por);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_created_at ON clientes_pf (created_at DESC);

COMMIT;


-- ============================================================
-- db/migrations/049_opencnpj_socios_conjuge_contrato_social.sql
-- ============================================================

-- Migration 049 — OpenCNPJ + sócios completos + cônjuge + contrato social
-- Sistema Destrava Crédito
-- Execute antes do deploy desta versão.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Empresas: metadados de fonte/sincronização da consulta CNPJ.
ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS dados_extra_receita JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS dados_fontes_cnpj JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS ultima_sincronizacao_receita TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS provedor_cnpj TEXT NULL,
  ADD COLUMN IF NOT EXISTS fontes_cnpj TEXT[] DEFAULT ARRAY[]::TEXT[];

-- Sócios/representantes usados pelo sistema atual.
CREATE TABLE IF NOT EXISTS socios_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  cpf_cnpj TEXT,
  qualificacao_socio TEXT,
  percentual_capital NUMERIC(8,2),
  representante_legal BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE socios_empresa
  ADD COLUMN IF NOT EXISTS nome_representante TEXT,
  ADD COLUMN IF NOT EXISTS qualificacao_representante TEXT,
  ADD COLUMN IF NOT EXISTS data_entrada_sociedade DATE,
  ADD COLUMN IF NOT EXISTS pais TEXT,
  ADD COLUMN IF NOT EXISTS rg TEXT,
  ADD COLUMN IF NOT EXISTS rg_orgao_emissor TEXT,
  ADD COLUMN IF NOT EXISTS rg_uf_emissao CHAR(2),
  ADD COLUMN IF NOT EXISTS rg_data_emissao DATE,
  ADD COLUMN IF NOT EXISTS data_nascimento DATE,
  ADD COLUMN IF NOT EXISTS nacionalidade TEXT,
  ADD COLUMN IF NOT EXISTS estado_civil TEXT,
  ADD COLUMN IF NOT EXISTS profissao TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS telefone TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp TEXT,
  ADD COLUMN IF NOT EXISTS cep TEXT,
  ADD COLUMN IF NOT EXISTS logradouro TEXT,
  ADD COLUMN IF NOT EXISTS numero TEXT,
  ADD COLUMN IF NOT EXISTS complemento TEXT,
  ADD COLUMN IF NOT EXISTS bairro TEXT,
  ADD COLUMN IF NOT EXISTS cidade TEXT,
  ADD COLUMN IF NOT EXISTS uf CHAR(2),
  ADD COLUMN IF NOT EXISTS conjuge_nome TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_cpf TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_rg TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_data_nasc DATE,
  ADD COLUMN IF NOT EXISTS conjuge_profissao TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_email TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_telefone TEXT,
  ADD COLUMN IF NOT EXISTS regime_bens TEXT,
  ADD COLUMN IF NOT EXISTS pep BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS fonte_dados TEXT DEFAULT 'api_publica_cnpj',
  ADD COLUMN IF NOT EXISTS cpf_completo_manual VARCHAR(14),
  ADD COLUMN IF NOT EXISTS cpf_validado BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cpf_fonte VARCHAR(50) DEFAULT 'opencnpj',
  ADD COLUMN IF NOT EXISTS ultima_atualizacao_pessoal TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS assinante_contrato BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS pendencias_contrato TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS cadastro_completo_contrato BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS dados_extra JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_id ON socios_empresa(empresa_id);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpf_cnpj ON socios_empresa(cpf_cnpj);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpf_completo_manual ON socios_empresa(cpf_completo_manual);

-- Compatibilidade com prompt/tabela antiga caso exista tabela socios.
DO $$
BEGIN
  IF to_regclass('public.socios') IS NOT NULL THEN
    ALTER TABLE socios
      ADD COLUMN IF NOT EXISTS cpf_completo_manual VARCHAR(14),
      ADD COLUMN IF NOT EXISTS cpf_validado BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS cpf_fonte VARCHAR(50) DEFAULT 'opencnpj',
      ADD COLUMN IF NOT EXISTS ultima_atualizacao_pessoal TIMESTAMPTZ DEFAULT NOW();
    CREATE INDEX IF NOT EXISTS idx_socios_cpf_completo ON socios(cpf_completo_manual);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS socios_conjuge (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  socio_id UUID NOT NULL REFERENCES socios_empresa(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  conjuge_nome VARCHAR(255),
  conjuge_cpf VARCHAR(14),
  regime_bens VARCHAR(100),
  data_casamento DATE,
  estado_civil VARCHAR(50),
  fonte VARCHAR(50) DEFAULT 'manual',
  criado_por UUID NULL REFERENCES colaboradores(id) ON DELETE SET NULL,
  atualizado_por UUID NULL REFERENCES colaboradores(id) ON DELETE SET NULL,
  data_insercao TIMESTAMPTZ DEFAULT NOW(),
  ultima_atualizacao TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_socios_conjuge_socio_id ON socios_conjuge(socio_id);
CREATE INDEX IF NOT EXISTS idx_socios_conjuge_empresa_id ON socios_conjuge(empresa_id);

CREATE TABLE IF NOT EXISTS empresas_contratos_sociais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome_arquivo VARCHAR(255) NOT NULL,
  caminho_arquivo VARCHAR(500) NOT NULL,
  url VARCHAR(500),
  tamanho_bytes INT,
  tipo_mime VARCHAR(50) DEFAULT 'application/pdf',
  data_assinatura DATE,
  numero_registro VARCHAR(50),
  data_registro DATE,
  numero_alteracoes INT DEFAULT 0,
  ultima_alteracao DATE,
  descricao TEXT,
  uploaded_by UUID NULL REFERENCES colaboradores(id) ON DELETE SET NULL,
  data_upload TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contratos_sociais_empresa_id ON empresas_contratos_sociais(empresa_id);
CREATE INDEX IF NOT EXISTS idx_contratos_sociais_data_upload ON empresas_contratos_sociais(data_upload);

COMMIT;


-- ============================================================
-- db/migrations/050_socios_empresa_qsa_fallback_upsert.sql
-- ============================================================

-- Migration 050 — índices de apoio para importação/upsert de sócios por CNPJ
-- Sistema Destrava Crédito
-- Execute depois da 049 e antes do deploy desta versão.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Garante a tabela/colunas centrais caso algum ambiente tenha aplicado versões parciais.
CREATE TABLE IF NOT EXISTS public.socios_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  cpf_cnpj TEXT,
  qualificacao_socio TEXT,
  percentual_capital NUMERIC(8,2),
  representante_legal BOOLEAN DEFAULT false,
  ativo BOOLEAN DEFAULT true,
  fonte_dados TEXT DEFAULT 'api_publica_cnpj',
  dados_extra JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS nome_representante TEXT,
  ADD COLUMN IF NOT EXISTS qualificacao_representante TEXT,
  ADD COLUMN IF NOT EXISTS data_entrada_sociedade DATE,
  ADD COLUMN IF NOT EXISTS pais TEXT,
  ADD COLUMN IF NOT EXISTS rg TEXT,
  ADD COLUMN IF NOT EXISTS rg_orgao_emissor TEXT,
  ADD COLUMN IF NOT EXISTS rg_uf_emissao CHAR(2),
  ADD COLUMN IF NOT EXISTS rg_data_emissao DATE,
  ADD COLUMN IF NOT EXISTS data_nascimento DATE,
  ADD COLUMN IF NOT EXISTS nacionalidade TEXT,
  ADD COLUMN IF NOT EXISTS estado_civil TEXT,
  ADD COLUMN IF NOT EXISTS profissao TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS telefone TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp TEXT,
  ADD COLUMN IF NOT EXISTS cep TEXT,
  ADD COLUMN IF NOT EXISTS logradouro TEXT,
  ADD COLUMN IF NOT EXISTS numero TEXT,
  ADD COLUMN IF NOT EXISTS complemento TEXT,
  ADD COLUMN IF NOT EXISTS bairro TEXT,
  ADD COLUMN IF NOT EXISTS cidade TEXT,
  ADD COLUMN IF NOT EXISTS uf CHAR(2),
  ADD COLUMN IF NOT EXISTS conjuge_nome TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_cpf TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_rg TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_data_nasc DATE,
  ADD COLUMN IF NOT EXISTS conjuge_profissao TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_email TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_telefone TEXT,
  ADD COLUMN IF NOT EXISTS regime_bens TEXT,
  ADD COLUMN IF NOT EXISTS pep BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS cpf_completo_manual VARCHAR(14),
  ADD COLUMN IF NOT EXISTS cpf_validado BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS cpf_fonte VARCHAR(50) DEFAULT 'opencnpj',
  ADD COLUMN IF NOT EXISTS ultima_atualizacao_pessoal TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS assinante_contrato BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS pendencias_contrato TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS cadastro_completo_contrato BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_id ON public.socios_empresa(empresa_id);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_nome_lower ON public.socios_empresa(empresa_id, lower(nome));
CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_cpf_cnpj_digits ON public.socios_empresa(empresa_id, regexp_replace(COALESCE(cpf_cnpj,''), '\D', '', 'g'));
CREATE INDEX IF NOT EXISTS idx_socios_empresa_ativo ON public.socios_empresa(empresa_id, ativo);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_dados_extra_gin ON public.socios_empresa USING GIN (dados_extra);

COMMIT;


-- ============================================================
-- db/migrations/051_socios_empresa_cpfhub_enriquecimento.sql
-- ============================================================

-- 051_socios_empresa_cpfhub_enriquecimento.sql
-- Complementa socios_empresa para armazenar dados cadastrais retornados pela CPFHub.io.
-- A chave da API fica somente em variável de ambiente: CPFHUB_API_KEY.

BEGIN;

ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS genero VARCHAR(20),
  ADD COLUMN IF NOT EXISTS cpfhub_consultado_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cpfhub_status TEXT;

CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpfhub_consultado_at
  ON public.socios_empresa(cpfhub_consultado_at);

CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpf_fonte
  ON public.socios_empresa(cpf_fonte);

COMMIT;


-- ============================================================
-- db/migrations/052_socios_empresa_cpfcnpj_qsa_full.sql
-- ============================================================

BEGIN;

ALTER TABLE public.socios_empresa
  ADD COLUMN IF NOT EXISTS cpfcnpj_consultado_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cpfcnpj_status TEXT,
  ADD COLUMN IF NOT EXISTS cpfcnpj_fonte TEXT,
  ADD COLUMN IF NOT EXISTS cpfcnpj_payload_resumo JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpfcnpj_status
  ON public.socios_empresa(cpfcnpj_status);

CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpfcnpj_consultado_at
  ON public.socios_empresa(cpfcnpj_consultado_at);

CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpf_completo_manual_digits
  ON public.socios_empresa ((regexp_replace(COALESCE(cpf_completo_manual, ''), '\D', '', 'g')));

COMMIT;


-- ============================================================
-- db/migrations/053_socios_manual_cpfhub_contratos.sql
-- ============================================================

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE IF EXISTS public.socios_empresa
  ADD COLUMN IF NOT EXISTS cpf_completo_manual VARCHAR(14),
  ADD COLUMN IF NOT EXISTS cpf_validado BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cpf_fonte VARCHAR(50) DEFAULT 'api_publica_cnpj',
  ADD COLUMN IF NOT EXISTS ultima_atualizacao_pessoal TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS genero VARCHAR(20),
  ADD COLUMN IF NOT EXISTS cpfhub_consultado_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cpfhub_status TEXT,
  ADD COLUMN IF NOT EXISTS dados_extra JSONB DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.empresas_contratos_sociais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  nome_arquivo VARCHAR(255) NOT NULL,
  caminho_arquivo VARCHAR(500) NOT NULL,
  url VARCHAR(500),
  tamanho_bytes INT,
  tipo_mime VARCHAR(50) DEFAULT 'application/pdf',
  data_assinatura DATE,
  numero_registro VARCHAR(50),
  data_registro DATE,
  numero_alteracoes INT DEFAULT 0,
  ultima_alteracao DATE,
  descricao TEXT,
  uploaded_by UUID NULL REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  data_upload TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_contratos_sociais_empresa_id ON public.empresas_contratos_sociais(empresa_id);
CREATE INDEX IF NOT EXISTS idx_contratos_sociais_data_upload ON public.empresas_contratos_sociais(data_upload);

CREATE TABLE IF NOT EXISTS public.socios_conjuge (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  socio_id UUID NOT NULL REFERENCES public.socios_empresa(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  conjuge_nome VARCHAR(255),
  conjuge_cpf VARCHAR(14),
  regime_bens VARCHAR(100),
  data_casamento DATE,
  estado_civil VARCHAR(50),
  fonte VARCHAR(50) DEFAULT 'manual',
  criado_por UUID NULL REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  atualizado_por UUID NULL REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  data_insercao TIMESTAMPTZ DEFAULT NOW(),
  ultima_atualizacao TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_socios_conjuge_socio_id ON public.socios_conjuge(socio_id);
CREATE INDEX IF NOT EXISTS idx_socios_conjuge_empresa_id ON public.socios_conjuge(empresa_id);

COMMIT;


-- ============================================================
-- db/migrations/054_acompanhamento_sincronizar_dados_empresa.sql
-- ============================================================

-- 054_acompanhamento_sincronizar_dados_empresa.sql
-- Garante que o módulo de Acompanhamento Bancário consiga usar os mesmos
-- dados cadastrais já sincronizados no cadastro de Empresas.
-- Idempotente e seguro para produção: não apaga nem reseta dados.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE IF EXISTS public.acompanhamentos_bancarios
  ADD COLUMN IF NOT EXISTS empresa_id UUID NULL,
  ADD COLUMN IF NOT EXISTS lead_id UUID NULL,
  ADD COLUMN IF NOT EXISTS cnpj TEXT,
  ADD COLUMN IF NOT EXISTS telefone_cliente TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp_cliente TEXT,
  ADD COLUMN IF NOT EXISTS email_cliente TEXT,
  ADD COLUMN IF NOT EXISTS gerente_banco TEXT,
  ADD COLUMN IF NOT EXISTS contato_banco TEXT,
  ADD COLUMN IF NOT EXISTS data_abertura_conta DATE,
  ADD COLUMN IF NOT EXISTS valor_credito_pretendido NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS linha_credito_pretendida TEXT,
  ADD COLUMN IF NOT EXISTS faturamento_anual NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS media_mensal NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS margem_seguranca_30 NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS percentual_operacional NUMERIC(8,2) DEFAULT 30,
  ADD COLUMN IF NOT EXISTS ultimo_update_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conname = 'acompanhamentos_bancarios_empresa_id_fkey'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = 'empresas'
  ) THEN
    ALTER TABLE public.acompanhamentos_bancarios
      ADD CONSTRAINT acompanhamentos_bancarios_empresa_id_fkey
      FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE SET NULL;
  END IF;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_acompanhamentos_bancarios_empresa_id
  ON public.acompanhamentos_bancarios(empresa_id)
  WHERE empresa_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_acompanhamentos_bancarios_cnpj_digits
  ON public.acompanhamentos_bancarios((regexp_replace(COALESCE(cnpj, ''), '[^0-9]', '', 'g')))
  WHERE cnpj IS NOT NULL;

COMMIT;


-- ============================================================
-- db/migrations/054_fix_colunas_faltantes_idempotente.sql
-- ============================================================

-- Migration 054 — Garantir colunas faltantes de forma idempotente
-- Corrige erros 500 causados por colunas inexistentes em ambientes que não
-- executaram todas as migrations anteriores na ordem correta.
-- Pode ser executada mais de uma vez sem efeitos colaterais.
BEGIN;

-- ─── Tabela: empresas ────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.empresas
  ADD COLUMN IF NOT EXISTS inscricao_estadual TEXT,
  ADD COLUMN IF NOT EXISTS inscricao_municipal TEXT,
  ADD COLUMN IF NOT EXISTS natureza_juridica TEXT,
  ADD COLUMN IF NOT EXISTS capital_social NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS cnae_principal TEXT,
  ADD COLUMN IF NOT EXISTS cnaes_secundarios TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS data_abertura DATE,
  ADD COLUMN IF NOT EXISTS situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS data_situacao_cadastral DATE,
  ADD COLUMN IF NOT EXISTS motivo_situacao_cadastral TEXT,
  ADD COLUMN IF NOT EXISTS matriz_filial TEXT,
  ADD COLUMN IF NOT EXISTS regime_tributario TEXT,
  ADD COLUMN IF NOT EXISTS telefone_2 TEXT,
  ADD COLUMN IF NOT EXISTS dados_extra_receita JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS ultima_sincronizacao_receita TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS analista_id UUID NULL REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS captador_id UUID NULL REFERENCES public.colaboradores(id) ON DELETE SET NULL;

-- ─── Tabela: socios_empresa ──────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.socios_empresa
  ADD COLUMN IF NOT EXISTS nome_representante TEXT,
  ADD COLUMN IF NOT EXISTS qualificacao_representante TEXT,
  ADD COLUMN IF NOT EXISTS data_entrada_sociedade DATE,
  ADD COLUMN IF NOT EXISTS pais TEXT,
  ADD COLUMN IF NOT EXISTS rg TEXT,
  ADD COLUMN IF NOT EXISTS rg_orgao_emissor TEXT,
  ADD COLUMN IF NOT EXISTS rg_uf_emissao CHAR(2),
  ADD COLUMN IF NOT EXISTS rg_data_emissao DATE,
  ADD COLUMN IF NOT EXISTS data_nascimento DATE,
  ADD COLUMN IF NOT EXISTS nacionalidade TEXT,
  ADD COLUMN IF NOT EXISTS estado_civil TEXT,
  ADD COLUMN IF NOT EXISTS profissao TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS telefone TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp TEXT,
  ADD COLUMN IF NOT EXISTS cep TEXT,
  ADD COLUMN IF NOT EXISTS logradouro TEXT,
  ADD COLUMN IF NOT EXISTS numero TEXT,
  ADD COLUMN IF NOT EXISTS complemento TEXT,
  ADD COLUMN IF NOT EXISTS bairro TEXT,
  ADD COLUMN IF NOT EXISTS cidade TEXT,
  ADD COLUMN IF NOT EXISTS uf CHAR(2),
  ADD COLUMN IF NOT EXISTS conjuge_nome TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_cpf TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_rg TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_data_nasc DATE,
  ADD COLUMN IF NOT EXISTS conjuge_profissao TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_email TEXT,
  ADD COLUMN IF NOT EXISTS conjuge_telefone TEXT,
  ADD COLUMN IF NOT EXISTS regime_bens TEXT,
  ADD COLUMN IF NOT EXISTS pep BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS fonte_dados TEXT DEFAULT 'api_publica_cnpj',
  ADD COLUMN IF NOT EXISTS percentual_capital NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS cpf_completo_manual VARCHAR(14),
  ADD COLUMN IF NOT EXISTS cpf_validado BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cpf_fonte VARCHAR(50) DEFAULT 'api_publica_cnpj',
  ADD COLUMN IF NOT EXISTS ultima_atualizacao_pessoal TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS assinante_contrato BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS pendencias_contrato TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS cadastro_completo_contrato BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS dados_extra JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS genero VARCHAR(20),
  ADD COLUMN IF NOT EXISTS cpfhub_consultado_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cpfhub_status TEXT,
  ADD COLUMN IF NOT EXISTS cpfcnpj_consultado_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cpfcnpj_status TEXT,
  ADD COLUMN IF NOT EXISTS cpfcnpj_fonte TEXT,
  ADD COLUMN IF NOT EXISTS cpfcnpj_payload_resumo JSONB DEFAULT '{}'::jsonb;

-- ─── Tabela: acompanhamento_bancario_atualizacoes ────────────────────────────
ALTER TABLE IF EXISTS public.acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS semanas_no_mes INTEGER DEFAULT 4,
  ADD COLUMN IF NOT EXISTS semanas_restantes_mes INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_anual NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS motivo_alerta_aderencia TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico TEXT,
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia TEXT,
  ADD COLUMN IF NOT EXISTS alerta_aderencia BOOLEAN DEFAULT false;

-- ─── Tabela: acompanhamento_compensacoes_historico ───────────────────────────
ALTER TABLE IF EXISTS public.acompanhamento_compensacoes_historico
  ADD COLUMN IF NOT EXISTS data_referencia_inicio DATE,
  ADD COLUMN IF NOT EXISTS data_referencia_fim DATE,
  ADD COLUMN IF NOT EXISTS entrada_realizada NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual NUMERIC(8,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia TEXT,
  ADD COLUMN IF NOT EXISTS alerta_aderencia BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS motivo_alerta TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico TEXT,
  ADD COLUMN IF NOT EXISTS criado_por UUID;

-- Índice único para evitar duplicatas no histórico de compensações
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'ux_acomp_comp_hist_acomp_semana'
  ) THEN
    CREATE UNIQUE INDEX ux_acomp_comp_hist_acomp_semana
      ON public.acompanhamento_compensacoes_historico(acompanhamento_id, numero_semana);
  END IF;
END $$;

-- ─── Tabela: empresa_checklist_documentos ────────────────────────────────────
-- Garante que a coluna socio_id existe (pode não existir em instâncias antigas)
ALTER TABLE IF EXISTS public.empresa_checklist_documentos
  ADD COLUMN IF NOT EXISTS socio_id UUID NULL REFERENCES public.socios_empresa(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS origem TEXT NOT NULL DEFAULT 'automatico',
  ADD COLUMN IF NOT EXISTS arquivo_id UUID NULL,
  ADD COLUMN IF NOT EXISTS data_vencimento DATE NULL;

-- Índices úteis
CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpf ON public.socios_empresa(cpf_cnpj);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_empresa_id ON public.socios_empresa(empresa_id);
CREATE INDEX IF NOT EXISTS idx_socios_empresa_cpfhub_status ON public.socios_empresa(cpfhub_status);

COMMIT;


-- ============================================================
-- db/migrations/055_documentos_arquivos_entidades_regras.sql
-- ============================================================

-- 055_documentos_arquivos_entidades_regras.sql
-- Estrutura centralizada e auditável para documentos por entidade.
-- Idempotente e segura: cria novas tabelas/índices, preserva legados e migra referências conhecidas sem apagar arquivos.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'documento_entidade_tipo') THEN
    CREATE TYPE documento_entidade_tipo AS ENUM (
      'empresa', 'cliente_pf', 'lead', 'socio', 'contrato', 'simulacao',
      'acompanhamento_bancario', 'acompanhamento_financeiro', 'faturamento', 'contador', 'outros'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'documento_status_tipo') THEN
    CREATE TYPE documento_status_tipo AS ENUM (
      'ativo', 'arquivado', 'substituido', 'excluido', 'pendente_validacao', 'validado', 'recusado'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'documento_origem_tipo') THEN
    CREATE TYPE documento_origem_tipo AS ENUM (
      'upload_manual', 'gerado_sistema', 'importado_api', 'sincronizacao', 'migracao'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.documentos_arquivos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entidade_tipo TEXT NOT NULL,
  entidade_id UUID NOT NULL,
  empresa_id UUID NULL,
  cliente_pf_id UUID NULL,
  lead_id UUID NULL,
  socio_id UUID NULL,
  contrato_id UUID NULL,
  simulacao_id UUID NULL,
  tipo_documento TEXT NOT NULL,
  nome_original TEXT NOT NULL,
  nome_arquivo TEXT NOT NULL,
  caminho_arquivo TEXT NOT NULL,
  url_arquivo TEXT NULL,
  mime_type TEXT,
  tamanho_bytes BIGINT,
  hash_arquivo TEXT NULL,
  status TEXT DEFAULT 'ativo',
  origem TEXT DEFAULT 'upload_manual',
  obrigatorio BOOLEAN DEFAULT false,
  validado BOOLEAN DEFAULT false,
  validado_por UUID NULL,
  validado_em TIMESTAMPTZ NULL,
  observacoes TEXT NULL,
  metadados JSONB DEFAULT '{}'::jsonb,
  criado_por UUID NULL,
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW(),
  excluido_em TIMESTAMPTZ NULL,
  CONSTRAINT documentos_arquivos_entidade_tipo_chk CHECK (entidade_tipo IN (
    'empresa','cliente_pf','lead','socio','contrato','simulacao','acompanhamento_bancario','acompanhamento_financeiro','faturamento','contador','outros'
  )),
  CONSTRAINT documentos_arquivos_status_chk CHECK (status IN (
    'ativo','arquivado','substituido','excluido','pendente_validacao','validado','recusado'
  )),
  CONSTRAINT documentos_arquivos_origem_chk CHECK (origem IN (
    'upload_manual','gerado_sistema','importado_api','sincronizacao','migracao'
  )),
  CONSTRAINT documentos_arquivos_tipo_chk CHECK (tipo_documento IN (
    'contrato_social','alteracao_contratual','documento_socio','rg','cpf','cnh','comprovante_residencia',
    'comprovante_faturamento','extrato_bancario','imposto_renda','balanco','dre','certidao','procuracao',
    'contrato_assessoria','declaracao_faturamento','cartao_cnpj','nire','estatuto','contrato_gerado',
    'contrato_assinado','outros'
  )),
  CONSTRAINT documentos_arquivos_cliente_pf_obr_chk CHECK (entidade_tipo <> 'cliente_pf' OR cliente_pf_id IS NOT NULL),
  CONSTRAINT documentos_arquivos_socio_obr_chk CHECK (entidade_tipo <> 'socio' OR (socio_id IS NOT NULL AND empresa_id IS NOT NULL)),
  CONSTRAINT documentos_arquivos_contrato_obr_chk CHECK (entidade_tipo <> 'contrato' OR contrato_id IS NOT NULL),
  CONSTRAINT documentos_arquivos_simulacao_obr_chk CHECK (entidade_tipo <> 'simulacao' OR simulacao_id IS NOT NULL),
  CONSTRAINT documentos_arquivos_lead_obr_chk CHECK (entidade_tipo <> 'lead' OR lead_id IS NOT NULL),
  CONSTRAINT documentos_arquivos_empresa_obr_chk CHECK (entidade_tipo <> 'empresa' OR empresa_id IS NOT NULL),
  CONSTRAINT documentos_arquivos_sem_pessoal_na_empresa_chk CHECK (
    NOT (entidade_tipo = 'empresa' AND tipo_documento IN ('rg','cpf','cnh','comprovante_residencia','documento_socio') AND socio_id IS NULL)
  ),
  CONSTRAINT documentos_arquivos_sem_empresarial_pf_chk CHECK (
    NOT (entidade_tipo = 'cliente_pf' AND tipo_documento IN ('contrato_social','alteracao_contratual','cartao_cnpj','nire','estatuto'))
  )
);

CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_entidade ON public.documentos_arquivos(entidade_tipo, entidade_id);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_empresa_id ON public.documentos_arquivos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_cliente_pf_id ON public.documentos_arquivos(cliente_pf_id);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_lead_id ON public.documentos_arquivos(lead_id);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_socio_id ON public.documentos_arquivos(socio_id);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_contrato_id ON public.documentos_arquivos(contrato_id);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_simulacao_id ON public.documentos_arquivos(simulacao_id);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_tipo_documento ON public.documentos_arquivos(tipo_documento);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_status ON public.documentos_arquivos(status);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_hash ON public.documentos_arquivos(hash_arquivo);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_ativos ON public.documentos_arquivos(entidade_tipo, entidade_id, status) WHERE excluido_em IS NULL;

CREATE TABLE IF NOT EXISTS public.auditoria_documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  documento_id UUID NULL,
  acao TEXT NOT NULL,
  antes JSONB,
  depois JSONB,
  usuario_id UUID NULL,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_auditoria_documentos_documento_id ON public.auditoria_documentos(documento_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_documentos_usuario_id ON public.auditoria_documentos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_documentos_criado_em ON public.auditoria_documentos(criado_em DESC);

CREATE OR REPLACE FUNCTION public.set_documentos_arquivos_atualizado_em()
RETURNS TRIGGER AS $$
BEGIN
  NEW.atualizado_em = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_documentos_arquivos_atualizado_em ON public.documentos_arquivos;
CREATE TRIGGER trg_documentos_arquivos_atualizado_em
BEFORE UPDATE ON public.documentos_arquivos
FOR EACH ROW EXECUTE FUNCTION public.set_documentos_arquivos_atualizado_em();

-- Migração compatível: empresa_documentos legado -> documentos_arquivos.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='empresa_documentos') THEN
    INSERT INTO public.documentos_arquivos (
      entidade_tipo, entidade_id, empresa_id, tipo_documento, nome_original, nome_arquivo, caminho_arquivo,
      url_arquivo, mime_type, tamanho_bytes, status, origem, metadados, criado_em, atualizado_em
    )
    SELECT
      'empresa', ed.empresa_id, ed.empresa_id,
      CASE
        WHEN lower(coalesce(ed.tipo, '')) IN ('contrato_social','alteracao_contratual','cartao_cnpj','nire','estatuto') THEN lower(ed.tipo)
        WHEN lower(coalesce(ed.tipo, '')) IN ('rg','cpf','cnh','comprovante_residencia') THEN 'outros'
        ELSE 'outros'
      END,
      coalesce(ed.nome, ed.url, 'documento_legado'),
      coalesce(split_part(ed.url, '/', array_length(string_to_array(ed.url, '/'), 1)), ed.nome, ed.id::text),
      coalesce(ed.url, '/legado/empresa_documentos/' || ed.id::text),
      ed.url,
      NULL,
      ed.tamanho,
      CASE WHEN lower(coalesce(ed.tipo, '')) IN ('rg','cpf','cnh','comprovante_residencia') THEN 'pendente_validacao' ELSE 'ativo' END,
      'migracao',
      jsonb_build_object('origem_tabela','empresa_documentos','origem_id',ed.id,'tipo_legado',ed.tipo),
      coalesce(ed.created_at, NOW()),
      coalesce(ed.created_at, NOW())
    FROM public.empresa_documentos ed
    WHERE ed.empresa_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.documentos_arquivos da
        WHERE da.metadados->>'origem_tabela'='empresa_documentos'
          AND da.metadados->>'origem_id'=ed.id::text
      );
  END IF;
END $$;

-- Migração GED legado -> documentos_arquivos, preservando vínculo da empresa.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='documentos_empresa') THEN
    INSERT INTO public.documentos_arquivos (
      entidade_tipo, entidade_id, empresa_id, tipo_documento, nome_original, nome_arquivo, caminho_arquivo,
      url_arquivo, mime_type, tamanho_bytes, status, origem, observacoes, metadados, criado_em, atualizado_em
    )
    SELECT
      'empresa', de.empresa_id, de.empresa_id,
      CASE
        WHEN de.tipo_documento IN ('contrato_social','alteracao_contratual','cartao_cnpj','nire','estatuto','declaracao_faturamento','extrato_bancario','dre','balanco','procuracao') THEN de.tipo_documento
        WHEN de.tipo_documento IN ('rg_socio','cpf_socio','cnh_socio','comprovante_residencia_socio') THEN 'outros'
        ELSE 'outros'
      END,
      coalesce(de.nome_arquivo, 'documento_ged'),
      coalesce(split_part(de.url_arquivo, '/', array_length(string_to_array(de.url_arquivo, '/'), 1)), de.nome_arquivo, de.id::text),
      coalesce(de.url_arquivo, '/legado/documentos_empresa/' || de.id::text),
      de.url_arquivo,
      NULL,
      de.tamanho_bytes,
      CASE
        WHEN de.status_validacao IN ('validado','recusado') THEN de.status_validacao
        WHEN de.status_validacao IN ('em_analise','pendente','pendente_validacao') THEN 'pendente_validacao'
        ELSE 'ativo'
      END,
      'migracao',
      NULL,
      jsonb_build_object('origem_tabela','documentos_empresa','origem_id',de.id,'tipo_legado',de.tipo_documento,'status_validacao',de.status_validacao),
      coalesce(de.created_at, NOW()),
      coalesce(de.updated_at, de.created_at, NOW())
    FROM public.documentos_empresa de
    WHERE de.empresa_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.documentos_arquivos da
        WHERE da.metadados->>'origem_tabela'='documentos_empresa'
          AND da.metadados->>'origem_id'=de.id::text
      );
  END IF;
END $$;

-- Migração contratos sociais legado -> documentos_arquivos.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='empresas_contratos_sociais') THEN
    INSERT INTO public.documentos_arquivos (
      entidade_tipo, entidade_id, empresa_id, tipo_documento, nome_original, nome_arquivo, caminho_arquivo,
      url_arquivo, mime_type, tamanho_bytes, status, origem, observacoes, criado_por, metadados, criado_em, atualizado_em
    )
    SELECT
      'empresa', ecs.empresa_id, ecs.empresa_id,
      CASE WHEN coalesce(ecs.numero_alteracoes, 0) > 0 THEN 'alteracao_contratual' ELSE 'contrato_social' END,
      coalesce(ecs.nome_arquivo, 'contrato_social.pdf'),
      coalesce(split_part(ecs.caminho_arquivo, '/', array_length(string_to_array(ecs.caminho_arquivo, '/'), 1)), ecs.nome_arquivo, ecs.id::text),
      coalesce(ecs.caminho_arquivo, ecs.url, '/legado/empresas_contratos_sociais/' || ecs.id::text),
      ecs.url,
      coalesce(ecs.tipo_mime, 'application/pdf'),
      ecs.tamanho_bytes,
      'ativo',
      'migracao',
      ecs.descricao,
      ecs.uploaded_by,
      jsonb_build_object('origem_tabela','empresas_contratos_sociais','origem_id',ecs.id,'numero_registro',ecs.numero_registro,'data_registro',ecs.data_registro),
      coalesce(ecs.data_upload, NOW()),
      coalesce(ecs.data_upload, NOW())
    FROM public.empresas_contratos_sociais ecs
    WHERE ecs.empresa_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.documentos_arquivos da
        WHERE da.metadados->>'origem_tabela'='empresas_contratos_sociais'
          AND da.metadados->>'origem_id'=ecs.id::text
      );
  END IF;
END $$;

-- Migração contratos gerados -> documentos_arquivos como entidade contrato.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='contratos_gerados') THEN
    INSERT INTO public.documentos_arquivos (
      entidade_tipo, entidade_id, empresa_id, cliente_pf_id, lead_id, contrato_id, tipo_documento, nome_original,
      nome_arquivo, caminho_arquivo, url_arquivo, mime_type, tamanho_bytes, hash_arquivo, status, origem,
      criado_por, metadados, criado_em, atualizado_em
    )
    SELECT
      'contrato', cg.id, cg.empresa_id, cg.cliente_pf_id, cg.lead_id, cg.id,
      CASE WHEN cg.tipo_contrato = 'assessoria' THEN 'contrato_assessoria' ELSE 'contrato_gerado' END,
      coalesce('contrato-' || cg.id::text || '.pdf', 'contrato.pdf'),
      coalesce(split_part(cg.pdf_path, '/', array_length(string_to_array(cg.pdf_path, '/'), 1)), 'contrato-' || cg.id::text || '.pdf'),
      coalesce(cg.pdf_path, '/legado/contratos_gerados/' || cg.id::text || '.pdf'),
      CASE WHEN cg.pdf_path IS NOT NULL THEN '/uploads/contratos/' || split_part(cg.pdf_path, '/', array_length(string_to_array(cg.pdf_path, '/'), 1)) ELSE NULL END,
      'application/pdf',
      NULL,
      cg.hash_documento,
      'ativo',
      'gerado_sistema',
      cg.criado_por,
      jsonb_build_object('origem_tabela','contratos_gerados','origem_id',cg.id,'tipo_contrato',cg.tipo_contrato,'status_contrato',cg.status),
      coalesce(cg.created_at, NOW()),
      coalesce(cg.updated_at, cg.created_at, NOW())
    FROM public.contratos_gerados cg
    WHERE cg.pdf_path IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.documentos_arquivos da
        WHERE da.metadados->>'origem_tabela'='contratos_gerados'
          AND da.metadados->>'origem_id'=cg.id::text
      );
  END IF;
END $$;

INSERT INTO public.auditoria_documentos (documento_id, acao, antes, depois, usuario_id)
SELECT da.id, 'migracao_inicial', NULL, jsonb_build_object('id', da.id, 'entidade_tipo', da.entidade_tipo, 'entidade_id', da.entidade_id, 'origem', da.origem), NULL
FROM public.documentos_arquivos da
WHERE da.origem = 'migracao'
  AND NOT EXISTS (
    SELECT 1 FROM public.auditoria_documentos ad
    WHERE ad.documento_id = da.id AND ad.acao = 'migracao_inicial'
  );

COMMENT ON TABLE public.documentos_arquivos IS 'Armazenamento centralizado de arquivos por entidade cadastral, com vínculo principal obrigatório e referências auxiliares.';
COMMENT ON TABLE public.auditoria_documentos IS 'Auditoria de upload, edição, validação, exclusão lógica e migrações de documentos.';


-- ============================================================
-- db/migrations/056_dossie_documental_credito_blocos_ia.sql
-- ============================================================

-- 056_dossie_documental_credito_blocos_ia.sql
-- Camada de Dossiê Documental de Crédito Empresarial.
-- Não altera documentos_arquivos, empresas, socios_empresa, faturamento ou contratos existentes.
-- Cria blocos estruturados acima da base central de documentos para CNPJ, QSA e demais análises.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.documentacao_blocos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT NOT NULL UNIQUE,
  nome_amigavel TEXT NOT NULL,
  descricao TEXT NULL,
  entidade_principal TEXT NOT NULL DEFAULT 'empresa',
  obrigatorio BOOLEAN NOT NULL DEFAULT false,
  ordem INTEGER NOT NULL DEFAULT 0,
  ativo BOOLEAN NOT NULL DEFAULT true,
  configuracao JSONB NOT NULL DEFAULT '{}'::jsonb,
  criacao_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizacao_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT documentacao_blocos_entidade_principal_chk CHECK (
    entidade_principal IN ('empresa','socio','cliente_pf','contrato','simulacao','lead','outros')
  )
);

CREATE TABLE IF NOT EXISTS public.documentacao_entidade_blocos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bloco_id UUID NOT NULL REFERENCES public.documentacao_blocos(id) ON DELETE RESTRICT,
  entidade_tipo TEXT NOT NULL,
  entidade_id UUID NOT NULL,
  empresa_id UUID NULL,
  cliente_pf_id UUID NULL,
  socio_id UUID NULL,
  contrato_id UUID NULL,
  simulacao_id UUID NULL,
  status TEXT NOT NULL DEFAULT 'pendente',
  completo BOOLEAN NOT NULL DEFAULT false,
  validado BOOLEAN NOT NULL DEFAULT false,
  validado_por UUID NULL,
  validado_em TIMESTAMPTZ NULL,
  dados_estruturados JSONB NOT NULL DEFAULT '{}'::jsonb,
  pendencias JSONB NOT NULL DEFAULT '[]'::jsonb,
  resultado_ia_id UUID NULL,
  origem TEXT NOT NULL DEFAULT 'sistema',
  atualizado_por UUID NULL,
  criacao_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizacao_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT documentacao_entidade_blocos_entidade_tipo_chk CHECK (
    entidade_tipo IN ('empresa','socio','cliente_pf','contrato','simulacao','lead','outros')
  ),
  CONSTRAINT documentacao_entidade_blocos_status_chk CHECK (
    status IN ('nao_iniciado','pendente','em_preenchimento','em_validacao','validado','recusado','desatualizado','inconclusivo')
  ),
  CONSTRAINT documentacao_entidade_blocos_origem_chk CHECK (
    origem IN ('sistema','manual','receita','ia','migracao','sincronizacao')
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_documentacao_entidade_blocos_entidade_bloco
  ON public.documentacao_entidade_blocos (entidade_tipo, entidade_id, bloco_id);
CREATE INDEX IF NOT EXISTS idx_documentacao_entidade_blocos_empresa_id ON public.documentacao_entidade_blocos (empresa_id);
CREATE INDEX IF NOT EXISTS idx_documentacao_entidade_blocos_socio_id ON public.documentacao_entidade_blocos (socio_id);
CREATE INDEX IF NOT EXISTS idx_documentacao_entidade_blocos_status ON public.documentacao_entidade_blocos (status);
CREATE INDEX IF NOT EXISTS idx_documentacao_entidade_blocos_dados_gin ON public.documentacao_entidade_blocos USING GIN (dados_estruturados);
CREATE INDEX IF NOT EXISTS idx_documentacao_entidade_blocos_pendencias_gin ON public.documentacao_entidade_blocos USING GIN (pendencias);

CREATE TABLE IF NOT EXISTS public.documentacao_bloco_arquivos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entidade_bloco_id UUID NOT NULL REFERENCES public.documentacao_entidade_blocos(id) ON DELETE CASCADE,
  arquivo_id UUID NOT NULL REFERENCES public.documentos_arquivos(id) ON DELETE RESTRICT,
  tipo_documento TEXT NULL,
  papel_documento TEXT NULL,
  principal BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'ativo',
  observacoes TEXT NULL,
  criacao_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizacao_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT documentacao_bloco_arquivos_status_chk CHECK (status IN ('ativo','pendente','validado','recusado','arquivado'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_documentacao_bloco_arquivos_bloco_arquivo
  ON public.documentacao_bloco_arquivos (entidade_bloco_id, arquivo_id);
CREATE INDEX IF NOT EXISTS idx_documentacao_bloco_arquivos_arquivo_id ON public.documentacao_bloco_arquivos (arquivo_id);
CREATE INDEX IF NOT EXISTS idx_documentacao_bloco_arquivos_tipo ON public.documentacao_bloco_arquivos (tipo_documento);

CREATE TABLE IF NOT EXISTS public.documentos_extracoes_ia (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  arquivo_id UUID NOT NULL REFERENCES public.documentos_arquivos(id) ON DELETE RESTRICT,
  entidade_bloco_id UUID NULL REFERENCES public.documentacao_entidade_blocos(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pendente',
  modelo TEXT NULL,
  prompt_codigo TEXT NULL,
  prompt_versao TEXT NULL,
  texto_extraido TEXT NULL,
  campos_extraidos JSONB NOT NULL DEFAULT '{}'::jsonb,
  resultado JSONB NOT NULL DEFAULT '{}'::jsonb,
  nivel_confianca NUMERIC(5,4) NULL,
  pendencias JSONB NOT NULL DEFAULT '[]'::jsonb,
  erros JSONB NOT NULL DEFAULT '[]'::jsonb,
  processado_em TIMESTAMPTZ NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT documentos_extracoes_ia_status_chk CHECK (status IN ('pendente','processando','concluido','falhou','revisao_humana'))
);

CREATE INDEX IF NOT EXISTS idx_documentos_extracoes_ia_arquivo_id ON public.documentos_extracoes_ia (arquivo_id);
CREATE INDEX IF NOT EXISTS idx_documentos_extracoes_ia_bloco_id ON public.documentos_extracoes_ia (entidade_bloco_id);
CREATE INDEX IF NOT EXISTS idx_documentos_extracoes_ia_status ON public.documentos_extracoes_ia (status);

CREATE TABLE IF NOT EXISTS public.documentacao_analises_ia (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entidade_tipo TEXT NOT NULL DEFAULT 'empresa',
  entidade_id UUID NOT NULL,
  empresa_id UUID NULL,
  simulacao_id UUID NULL,
  tipo_analise TEXT NOT NULL DEFAULT 'analise_documental_empresa',
  status TEXT NOT NULL DEFAULT 'em_analise',
  prompt_codigo TEXT NULL,
  prompt_versao TEXT NULL,
  versao_modelo TEXT NULL,
  entrada_contexto JSONB NOT NULL DEFAULT '{}'::jsonb,
  resultado JSONB NOT NULL DEFAULT '{}'::jsonb,
  relatorio_texto TEXT NULL,
  score NUMERIC(6,2) NULL,
  nivel_confianca NUMERIC(5,4) NULL,
  risco_documental TEXT NULL,
  pendencias JSONB NOT NULL DEFAULT '[]'::jsonb,
  comentarios_revisor TEXT NULL,
  revisado_por UUID NULL,
  revisado_em TIMESTAMPTZ NULL,
  criado_por UUID NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT documentacao_analises_ia_status_chk CHECK (status IN ('aguardando','em_analise','concluido','revisao_pendente','falhou'))
);

CREATE INDEX IF NOT EXISTS idx_documentacao_analises_ia_entidade ON public.documentacao_analises_ia (entidade_tipo, entidade_id);
CREATE INDEX IF NOT EXISTS idx_documentacao_analises_ia_empresa_id ON public.documentacao_analises_ia (empresa_id);
CREATE INDEX IF NOT EXISTS idx_documentacao_analises_ia_status ON public.documentacao_analises_ia (status);

CREATE TABLE IF NOT EXISTS public.ia_prompts_documentais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bloco_id UUID NULL REFERENCES public.documentacao_blocos(id) ON DELETE SET NULL,
  codigo TEXT NOT NULL,
  versao TEXT NOT NULL DEFAULT '1.0.0',
  nome TEXT NOT NULL,
  descricao TEXT NULL,
  prompt_sistema TEXT NOT NULL,
  prompt_usuario_template TEXT NOT NULL,
  schema_saida JSONB NOT NULL DEFAULT '{}'::jsonb,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criacao_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizacao_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (codigo, versao)
);

CREATE INDEX IF NOT EXISTS idx_ia_prompts_documentais_codigo ON public.ia_prompts_documentais (codigo);
CREATE INDEX IF NOT EXISTS idx_ia_prompts_documentais_bloco_id ON public.ia_prompts_documentais (bloco_id);

CREATE TABLE IF NOT EXISTS public.auditoria_documentacao (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entidade_bloco_id UUID NULL,
  analise_id UUID NULL,
  arquivo_id UUID NULL,
  acao TEXT NOT NULL,
  antes JSONB NULL,
  depois JSONB NULL,
  usuario_id UUID NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auditoria_documentacao_bloco_id ON public.auditoria_documentacao (entidade_bloco_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_documentacao_analise_id ON public.auditoria_documentacao (analise_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_documentacao_arquivo_id ON public.auditoria_documentacao (arquivo_id);

CREATE OR REPLACE FUNCTION public.atualizar_atualizacao_em_documentacao()
RETURNS TRIGGER AS $$
BEGIN
  NEW.atualizacao_em = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_documentacao_blocos_atualizacao_em ON public.documentacao_blocos;
CREATE TRIGGER trg_documentacao_blocos_atualizacao_em
BEFORE UPDATE ON public.documentacao_blocos
FOR EACH ROW EXECUTE FUNCTION public.atualizar_atualizacao_em_documentacao();

DROP TRIGGER IF EXISTS trg_documentacao_entidade_blocos_atualizacao_em ON public.documentacao_entidade_blocos;
CREATE TRIGGER trg_documentacao_entidade_blocos_atualizacao_em
BEFORE UPDATE ON public.documentacao_entidade_blocos
FOR EACH ROW EXECUTE FUNCTION public.atualizar_atualizacao_em_documentacao();

DROP TRIGGER IF EXISTS trg_documentacao_bloco_arquivos_atualizacao_em ON public.documentacao_bloco_arquivos;
CREATE TRIGGER trg_documentacao_bloco_arquivos_atualizacao_em
BEFORE UPDATE ON public.documentacao_bloco_arquivos
FOR EACH ROW EXECUTE FUNCTION public.atualizar_atualizacao_em_documentacao();

DROP TRIGGER IF EXISTS trg_documentos_extracoes_ia_atualizacao_em ON public.documentos_extracoes_ia;
CREATE TRIGGER trg_documentos_extracoes_ia_atualizacao_em
BEFORE UPDATE ON public.documentos_extracoes_ia
FOR EACH ROW EXECUTE FUNCTION public.atualizar_atualizacao_em_documentacao();

DROP TRIGGER IF EXISTS trg_documentacao_analises_ia_atualizacao_em ON public.documentacao_analises_ia;
CREATE TRIGGER trg_documentacao_analises_ia_atualizacao_em
BEFORE UPDATE ON public.documentacao_analises_ia
FOR EACH ROW EXECUTE FUNCTION public.atualizar_atualizacao_em_documentacao();

DROP TRIGGER IF EXISTS trg_ia_prompts_documentais_atualizacao_em ON public.ia_prompts_documentais;
CREATE TRIGGER trg_ia_prompts_documentais_atualizacao_em
BEFORE UPDATE ON public.ia_prompts_documentais
FOR EACH ROW EXECUTE FUNCTION public.atualizar_atualizacao_em_documentacao();

INSERT INTO public.documentacao_blocos (codigo, nome_amigavel, descricao, entidade_principal, obrigatorio, ordem, configuracao)
VALUES
  ('cnpj_receita', 'CNPJ / Receita Federal', 'Dados oficiais e estruturados de CNPJ, situação cadastral, CNAE, capital social e sincronização da Receita.', 'empresa', true, 1, '{"prioridade":"imediata","fonte":"empresas,dados_extra_receita"}'::jsonb),
  ('qsa_quadro_societario', 'QSA / Quadro Societário', 'Quadro de sócios e administradores, origem Receita e cadastro operacional dos sócios.', 'empresa', true, 2, '{"prioridade":"imediata","fonte":"socios_empresa,empresas.socios_receita"}'::jsonb),
  ('contrato_social_alteracoes', 'Contrato Social e Alterações', 'Contrato social vigente, alterações, poderes de administração e assinatura.', 'empresa', true, 3, '{}'::jsonb),
  ('socios_representantes', 'Sócios, Administradores e Representantes', 'Documentação e dados pessoais/operacionais dos sócios e representantes.', 'socio', true, 4, '{}'::jsonb),
  ('endereco_contatos', 'Endereço, Contatos e Dados Operacionais', 'Endereços, telefones, e-mails, responsáveis e comprovantes.', 'empresa', false, 5, '{}'::jsonb),
  ('faturamento_historico', 'Faturamento Histórico', 'Histórico mensal de faturamento e documentos comprobatórios.', 'empresa', true, 6, '{}'::jsonb),
  ('previsao_faturamento', 'Previsão de Faturamento', 'Projeções e capacidade estimada de pagamento.', 'empresa', false, 7, '{}'::jsonb),
  ('demonstracoes_contabeis_fiscais', 'Demonstrações Contábeis e Fiscais', 'Balanço, DRE, balancete, ECD, ECF e documentos fiscais.', 'empresa', false, 8, '{}'::jsonb),
  ('extratos_movimentacao_bancaria', 'Extratos Bancários e Movimentação', 'Extratos e movimentação bancária para conciliação com faturamento.', 'empresa', false, 9, '{}'::jsonb),
  ('acompanhamento_bancario', 'Acompanhamento Bancário', 'Dados semanais de monitoramento bancário, rating e recomendações.', 'empresa', false, 10, '{}'::jsonb),
  ('acompanhamento_financeiro', 'Acompanhamento Financeiro', 'Pagamentos, parcelas, inadimplência, comissões e cobranças.', 'empresa', false, 11, '{}'::jsonb),
  ('certidoes_regularidade', 'Certidões e Regularidade', 'CNDs, FGTS, CNDT, protestos e consultas de restrição.', 'empresa', false, 12, '{}'::jsonb),
  ('scr_endividamento', 'SCR / Endividamento', 'Relatórios SCR/BACEN, dívidas, financiamentos, atrasos e instituições credoras.', 'empresa', false, 13, '{}'::jsonb),
  ('garantias', 'Garantias', 'Garantias vinculadas a empresa, contrato ou operação.', 'empresa', false, 14, '{}'::jsonb),
  ('contratos_gerados', 'Contratos Gerados', 'Contratos de assessoria e PDFs gerados/assinados.', 'empresa', false, 15, '{}'::jsonb),
  ('pendencias_documentais', 'Pendências Documentais', 'Consolidação de documentos faltantes, vencidos ou divergentes.', 'empresa', true, 16, '{}'::jsonb),
  ('analise_ia_credito', 'Parecer de Crédito', 'Parecer consolidado com revisão humana.', 'empresa', false, 17, '{}'::jsonb)
ON CONFLICT (codigo) DO UPDATE SET
  nome_amigavel = EXCLUDED.nome_amigavel,
  descricao = EXCLUDED.descricao,
  entidade_principal = EXCLUDED.entidade_principal,
  obrigatorio = EXCLUDED.obrigatorio,
  ordem = EXCLUDED.ordem,
  ativo = true,
  configuracao = public.documentacao_blocos.configuracao || EXCLUDED.configuracao;

INSERT INTO public.ia_prompts_documentais (bloco_id, codigo, versao, nome, descricao, prompt_sistema, prompt_usuario_template, schema_saida)
SELECT b.id, 'extrair_' || b.codigo, '1.0.0', 'Extrair ' || b.nome_amigavel,
       'Prompt inicial preparado para conferência do bloco ' || b.codigo,
       'Confira a documentação de crédito empresarial. Extraia somente informações comprovadas no bloco/documentos enviados. Nunca tome decisão final de crédito; apenas registre achados e pendências para revisão humana.',
       'Analise o bloco {{bloco_codigo}} da entidade {{entidade_tipo}}/{{entidade_id}}. Use os dados estruturados e documentos fornecidos. Retorne JSON válido com campos_extraidos, pendencias, inconsistencias, recomendacoes, nivel_confianca e revisao_humana_necessaria.',
       '{"type":"object","required":["campos_extraidos","pendencias","inconsistencias","nivel_confianca","revisao_humana_necessaria"]}'::jsonb
FROM public.documentacao_blocos b
WHERE b.codigo IN ('cnpj_receita','qsa_quadro_societario','contrato_social_alteracoes','socios_representantes','faturamento_historico','analise_ia_credito')
ON CONFLICT (codigo, versao) DO UPDATE SET
  bloco_id = EXCLUDED.bloco_id,
  nome = EXCLUDED.nome,
  descricao = EXCLUDED.descricao,
  prompt_sistema = EXCLUDED.prompt_sistema,
  prompt_usuario_template = EXCLUDED.prompt_usuario_template,
  schema_saida = EXCLUDED.schema_saida,
  ativo = true;


-- ============================================================
-- db/migrations/057_documentos_credito_comprovante_endereco.sql
-- ============================================================

-- 057_documentos_credito_comprovante_endereco.sql
-- Adiciona tipo documental de comprovante de endereço empresarial para arquivos usados em análise de crédito.
-- Mantém contrato_assessoria permitido no banco por compatibilidade histórica, mas o frontend de Arquivos de Crédito não oferece esse tipo.

ALTER TABLE public.documentos_arquivos
  DROP CONSTRAINT IF EXISTS documentos_arquivos_tipo_chk;

ALTER TABLE public.documentos_arquivos
  ADD CONSTRAINT documentos_arquivos_tipo_chk CHECK (tipo_documento IN (
    'contrato_social','alteracao_contratual','documento_socio','rg','cpf','cnh','comprovante_residencia',
    'comprovante_endereco','comprovante_faturamento','extrato_bancario','imposto_renda','balanco','dre','certidao','procuracao',
    'contrato_assessoria','declaracao_faturamento','cartao_cnpj','nire','estatuto','contrato_gerado',
    'contrato_assinado','outros'
  ));


-- ============================================================
-- db/migrations/058_documentos_credito_ia_rag_checklist.sql
-- ============================================================

-- 058_documentos_credito_ia_rag_checklist.sql
-- Expande o acervo documental para análise de crédito, Cartão CNPJ, regras documentais e base RAG auditável.
-- Idempotente: não apaga documentos existentes e preserva compatibilidade com uploads atuais.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.documentos_arquivos
  DROP CONSTRAINT IF EXISTS documentos_arquivos_tipo_chk;

ALTER TABLE public.documentos_arquivos
  ADD CONSTRAINT documentos_arquivos_tipo_chk CHECK (tipo_documento IN (
    'contrato_prestacao_servicos','contrato_assessoria','cartao_cnpj','qsa','atos_junta_comercial',
    'contrato_social','alteracao_contratual','documento_socio','rg','cpf','cnh','comprovante_residencia',
    'certidao_casamento','averbacao_divorcio','certidao_obito','imposto_renda','recibo_irpf',
    'rating_bacen_cnpj','rating_bacen_cpf','cenprot_cnpj','cenprot_cpf','cnd_rfb_cnpj','cnd_rfb_cpf',
    'cadin_cnpj','cadin_cpf','pgfn_cnpj','pgfn_cpf','simples_nacional','pgdas','pgmei','ecf',
    'recibo_ecf','recibo_pgdas','recibo_pgmei','defis','dasn_simei','recibo_defis','recibo_dasn_simei',
    'scr_cnpj','ccs_cnpj','ccf_cnpj','scr_cpf','ccs_cpf','ccf_cpf','consulta_serasa_cnpj','consulta_serasa_cpf',
    'compartilhamento_ecac','foto_fachada','foto_interna_1','foto_interna_2','foto_interna_3',
    'faturamento_12_meses','comprovante_endereco','comprovante_faturamento','declaracao_faturamento',
    'extrato_bancario','balanco','dre','certidao','procuracao','nire','estatuto',
    'contrato_gerado','contrato_assinado','outros'
  ));

ALTER TABLE public.documentos_arquivos
  DROP CONSTRAINT IF EXISTS documentos_arquivos_status_chk;

ALTER TABLE public.documentos_arquivos
  ADD CONSTRAINT documentos_arquivos_status_chk CHECK (status IN (
    'ativo','arquivado','substituido','excluido','pendente_validacao','validado','recusado','desatualizado'
  ));

ALTER TABLE public.documentos_arquivos
  ADD COLUMN IF NOT EXISTS data_emissao_documento DATE,
  ADD COLUMN IF NOT EXISTS data_validade_documento DATE,
  ADD COLUMN IF NOT EXISTS validade_dias INTEGER,
  ADD COLUMN IF NOT EXISTS status_validade TEXT DEFAULT 'nao_verificado',
  ADD COLUMN IF NOT EXISTS exige_revisao_humana BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS nome_customizado TEXT,
  ADD COLUMN IF NOT EXISTS resultado_validacao JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS ultima_extracao_ia_id UUID NULL,
  ADD COLUMN IF NOT EXISTS ultima_indexacao_rag_id UUID NULL;

CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_status_validade ON public.documentos_arquivos(status_validade);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_data_emissao ON public.documentos_arquivos(data_emissao_documento);
CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_nome_customizado ON public.documentos_arquivos(nome_customizado);

-- Regras documentais usadas pelo checklist e pelo relatório de crédito.
CREATE TABLE IF NOT EXISTS public.documentos_regras_credito (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT UNIQUE NOT NULL,
  tipo_documento TEXT NOT NULL,
  nome_amigavel TEXT NOT NULL,
  entidade_tipo TEXT NOT NULL DEFAULT 'empresa',
  escopo TEXT NOT NULL DEFAULT 'empresa',
  obrigatorio BOOLEAN NOT NULL DEFAULT true,
  permite_multiplos BOOLEAN NOT NULL DEFAULT false,
  validade_dias INTEGER NULL,
  condicao JSONB NOT NULL DEFAULT '{}'::jsonb,
  descricao TEXT NULL,
  ativo BOOLEAN NOT NULL DEFAULT true,
  ordem INTEGER NOT NULL DEFAULT 0,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_documentos_regras_credito_entidade ON public.documentos_regras_credito(entidade_tipo, ativo, ordem);
CREATE INDEX IF NOT EXISTS idx_documentos_regras_credito_tipo ON public.documentos_regras_credito(tipo_documento);

-- Texto extraído preserva o conteúdo pesquisável sem substituir o arquivo original.
CREATE TABLE IF NOT EXISTS public.documentos_textos_extraidos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  documento_id UUID NOT NULL REFERENCES public.documentos_arquivos(id) ON DELETE CASCADE,
  empresa_id UUID NULL,
  socio_id UUID NULL,
  origem TEXT NOT NULL DEFAULT 'ia_ocr',
  status TEXT NOT NULL DEFAULT 'pendente',
  texto_extraido TEXT NULL,
  metadados JSONB NOT NULL DEFAULT '{}'::jsonb,
  erro TEXT NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(documento_id, origem)
);
CREATE INDEX IF NOT EXISTS idx_documentos_textos_extraidos_doc ON public.documentos_textos_extraidos(documento_id);
CREATE INDEX IF NOT EXISTS idx_documentos_textos_extraidos_empresa ON public.documentos_textos_extraidos(empresa_id);

-- Chunks RAG: índice derivado para perguntas/relatórios. O arquivo original continua sendo a fonte oficial.
CREATE TABLE IF NOT EXISTS public.documentos_rag_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  documento_id UUID NOT NULL REFERENCES public.documentos_arquivos(id) ON DELETE CASCADE,
  texto_extraido_id UUID NULL REFERENCES public.documentos_textos_extraidos(id) ON DELETE CASCADE,
  empresa_id UUID NULL,
  socio_id UUID NULL,
  chunk_index INTEGER NOT NULL DEFAULT 0,
  conteudo TEXT NOT NULL,
  metadados JSONB NOT NULL DEFAULT '{}'::jsonb,
  embedding_model TEXT NULL,
  embedding JSONB NULL,
  hash_chunk TEXT NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(documento_id, chunk_index)
);
CREATE INDEX IF NOT EXISTS idx_documentos_rag_chunks_doc ON public.documentos_rag_chunks(documento_id);
CREATE INDEX IF NOT EXISTS idx_documentos_rag_chunks_empresa ON public.documentos_rag_chunks(empresa_id);
CREATE INDEX IF NOT EXISTS idx_documentos_rag_chunks_hash ON public.documentos_rag_chunks(hash_chunk);

-- Campos extraídos por IA: especialmente Cartão CNPJ, QSA, certidões e consultas.
CREATE TABLE IF NOT EXISTS public.documentos_campos_extraidos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  documento_id UUID NOT NULL REFERENCES public.documentos_arquivos(id) ON DELETE CASCADE,
  empresa_id UUID NULL,
  socio_id UUID NULL,
  tipo_documento TEXT NOT NULL,
  campos_extraidos JSONB NOT NULL DEFAULT '{}'::jsonb,
  alertas JSONB NOT NULL DEFAULT '[]'::jsonb,
  divergencias JSONB NOT NULL DEFAULT '[]'::jsonb,
  nivel_confianca NUMERIC(5,4) NULL,
  modelo_ia TEXT NULL,
  prompt_versao TEXT NULL,
  status TEXT NOT NULL DEFAULT 'pendente',
  revisao_humana_necessaria BOOLEAN NOT NULL DEFAULT false,
  revisado_por UUID NULL,
  revisado_em TIMESTAMPTZ NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_documentos_campos_extraidos_doc ON public.documentos_campos_extraidos(documento_id);
CREATE INDEX IF NOT EXISTS idx_documentos_campos_extraidos_empresa_tipo ON public.documentos_campos_extraidos(empresa_id, tipo_documento);

-- Alertas persistentes para relatório e gestão: alterações de CNAE, endereço, situação, CNPJ vencido etc.
CREATE TABLE IF NOT EXISTS public.documentos_alertas_ia (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL,
  socio_id UUID NULL,
  documento_id UUID NULL REFERENCES public.documentos_arquivos(id) ON DELETE SET NULL,
  extracao_id UUID NULL REFERENCES public.documentos_campos_extraidos(id) ON DELETE SET NULL,
  tipo_alerta TEXT NOT NULL,
  severidade TEXT NOT NULL DEFAULT 'media',
  campo TEXT NULL,
  valor_anterior TEXT NULL,
  valor_atual TEXT NULL,
  mensagem TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'aberto',
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolvido_em TIMESTAMPTZ NULL,
  resolvido_por UUID NULL
);
CREATE INDEX IF NOT EXISTS idx_documentos_alertas_ia_empresa_status ON public.documentos_alertas_ia(empresa_id, status, criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_documentos_alertas_ia_documento ON public.documentos_alertas_ia(documento_id);

-- Credenciais sensíveis: estrutura preparada, mas só deve ser usada com APP_ENCRYPTION_KEY e criptografia no backend.
CREATE TABLE IF NOT EXISTS public.credenciais_sensiveis_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL,
  socio_id UUID NULL,
  tipo TEXT NOT NULL,
  identificador TEXT NULL,
  segredo_criptografado TEXT NOT NULL,
  observacoes TEXT NULL,
  criado_por UUID NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_credenciais_sensiveis_empresa ON public.credenciais_sensiveis_empresa(empresa_id);
CREATE INDEX IF NOT EXISTS idx_credenciais_sensiveis_socio ON public.credenciais_sensiveis_empresa(socio_id);

CREATE OR REPLACE FUNCTION public.set_atualizado_em_generico()
RETURNS TRIGGER AS $$
BEGIN
  NEW.atualizado_em = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_documentos_regras_credito_atualizado ON public.documentos_regras_credito;
CREATE TRIGGER trg_documentos_regras_credito_atualizado BEFORE UPDATE ON public.documentos_regras_credito
FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em_generico();

DROP TRIGGER IF EXISTS trg_documentos_textos_extraidos_atualizado ON public.documentos_textos_extraidos;
CREATE TRIGGER trg_documentos_textos_extraidos_atualizado BEFORE UPDATE ON public.documentos_textos_extraidos
FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em_generico();

DROP TRIGGER IF EXISTS trg_documentos_rag_chunks_atualizado ON public.documentos_rag_chunks;
CREATE TRIGGER trg_documentos_rag_chunks_atualizado BEFORE UPDATE ON public.documentos_rag_chunks
FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em_generico();

DROP TRIGGER IF EXISTS trg_documentos_campos_extraidos_atualizado ON public.documentos_campos_extraidos;
CREATE TRIGGER trg_documentos_campos_extraidos_atualizado BEFORE UPDATE ON public.documentos_campos_extraidos
FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em_generico();

DROP TRIGGER IF EXISTS trg_credenciais_sensiveis_empresa_atualizado ON public.credenciais_sensiveis_empresa;
CREATE TRIGGER trg_credenciais_sensiveis_empresa_atualizado BEFORE UPDATE ON public.credenciais_sensiveis_empresa
FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em_generico();

-- Catálogo inicial das regras documentais.
INSERT INTO public.documentos_regras_credito (codigo, tipo_documento, nome_amigavel, entidade_tipo, escopo, obrigatorio, permite_multiplos, validade_dias, condicao, descricao, ordem)
VALUES
  ('empresa_contrato_prestacao_servicos', 'contrato_prestacao_servicos', 'Contrato de prestação de serviços', 'empresa', 'empresa', true, false, null, '{}'::jsonb, 'Contrato entre Destrava/assessoria e cliente.', 10),
  ('empresa_cartao_cnpj_30d', 'cartao_cnpj', 'Cartão CNPJ emitido há menos de 31 dias', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Documento oficial da Receita Federal. Deve ser atual.', 20),
  ('empresa_qsa', 'qsa', 'QSA / Quadro Societário', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Quadro de sócios e administradores.', 30),
  ('empresa_atos_junta', 'atos_junta_comercial', 'Atos da Junta Comercial', 'empresa', 'empresa', true, true, null, '{}'::jsonb, 'Atos arquivados na Junta Comercial.', 40),
  ('empresa_contrato_social', 'contrato_social', 'Contrato social e alterações', 'empresa', 'empresa', true, true, null, '{}'::jsonb, 'Contrato social vigente e alterações contratuais.', 50),
  ('empresa_rating_bacen', 'rating_bacen_cnpj', 'Consulta de Rating BACEN (CNPJ)', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Consulta de rating/relatório BACEN do CNPJ.', 60),
  ('empresa_cenprot', 'cenprot_cnpj', 'Consulta CENPROT (CNPJ)', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Consulta de protestos do CNPJ.', 70),
  ('empresa_cnd_rfb', 'cnd_rfb_cnpj', 'CND RFB (CNPJ)', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Certidão negativa/positiva com efeitos de negativa da Receita Federal.', 80),
  ('empresa_cadin_se_cnd_ausente', 'cadin_cnpj', 'Nada consta CADIN (CNPJ)', 'empresa', 'empresa', false, false, 30, '{"quando":"cnd_rfb_cnpj_ausente"}'::jsonb, 'Exigido se a CND RFB CNPJ não for disponibilizada.', 90),
  ('empresa_pgfn_se_cnd_ausente', 'pgfn_cnpj', 'Nada consta PGFN (CNPJ)', 'empresa', 'empresa', false, false, 30, '{"quando":"cnd_rfb_cnpj_ausente"}'::jsonb, 'Exigido se a CND RFB CNPJ não for disponibilizada.', 100),
  ('empresa_simples_nacional', 'simples_nacional', 'Consulta de optante pelo Simples Nacional', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Comprovação do regime/opção tributária.', 110),
  ('empresa_pgdas', 'pgdas', 'PGDAS', 'empresa', 'empresa', false, true, null, '{"regime":"simples_nacional"}'::jsonb, 'Obrigatório para optantes pelo Simples Nacional quando aplicável.', 120),
  ('empresa_pgmei', 'pgmei', 'PGMEI', 'empresa', 'empresa', false, true, null, '{"regime":"mei"}'::jsonb, 'Obrigatório para MEI quando aplicável.', 130),
  ('empresa_ecf', 'ecf', 'ECF', 'empresa', 'empresa', false, true, null, '{"regime":["lucro_presumido","lucro_real","lucro_arbitrado"]}'::jsonb, 'Obrigatória para Lucro Presumido, Real ou Arbitrado.', 140),
  ('empresa_defis', 'defis', 'DEFIS', 'empresa', 'empresa', false, true, null, '{"regime":"simples_nacional","exceto":"mei"}'::jsonb, 'Obrigatória para optantes do Simples que não sejam MEI.', 150),
  ('empresa_dasn_simei', 'dasn_simei', 'DASN-SIMEI', 'empresa', 'empresa', false, true, null, '{"regime":"mei"}'::jsonb, 'Obrigatória para MEI.', 160),
  ('empresa_scr', 'scr_cnpj', 'Relatório SCR do CNPJ', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Relatório SCR da empresa.', 170),
  ('empresa_ccs', 'ccs_cnpj', 'Relatório CCS do CNPJ', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Relatório CCS da empresa.', 180),
  ('empresa_ccf', 'ccf_cnpj', 'Relatório CCF do CNPJ', 'empresa', 'empresa', true, false, 30, '{}'::jsonb, 'Relatório CCF da empresa.', 190),
  ('empresa_ecac', 'compartilhamento_ecac', 'Compartilhamento eCAC por banco', 'empresa', 'empresa', false, true, null, '{}'::jsonb, 'Compartilhamento eCAC discriminado por banco destinatário.', 200),
  ('empresa_foto_fachada', 'foto_fachada', 'Foto da fachada', 'empresa', 'empresa', false, false, null, '{}'::jsonb, 'Foto da fachada da empresa.', 210),
  ('empresa_foto_interna_1', 'foto_interna_1', 'Foto interna 1', 'empresa', 'empresa', false, false, null, '{}'::jsonb, 'Foto interna da empresa.', 220),
  ('empresa_foto_interna_2', 'foto_interna_2', 'Foto interna 2', 'empresa', 'empresa', false, false, null, '{}'::jsonb, 'Foto interna da empresa.', 230),
  ('empresa_foto_interna_3', 'foto_interna_3', 'Foto interna 3', 'empresa', 'empresa', false, false, null, '{}'::jsonb, 'Foto interna da empresa.', 240),
  ('empresa_faturamento_12m', 'faturamento_12_meses', 'Faturamento bruto dos últimos 12 meses', 'empresa', 'empresa', true, true, null, '{}'::jsonb, 'Faturamento bruto da empresa dos últimos 12 meses ou período solicitado.', 250),
  ('socio_documento_id', 'documento_socio', 'Documento de identificação do sócio', 'socio', 'socio', true, true, null, '{}'::jsonb, 'CNH ou RG do sócio.', 300),
  ('socio_comprovante_residencia', 'comprovante_residencia', 'Comprovante de endereço do sócio', 'socio', 'socio', true, false, 90, '{}'::jsonb, 'Comprovante de residência do sócio.', 310),
  ('socio_irpf', 'imposto_renda', 'IRPF do sócio', 'socio', 'socio', true, true, null, '{}'::jsonb, 'Declaração de IRPF do sócio.', 320),
  ('socio_recibo_irpf', 'recibo_irpf', 'Recibo de entrega do IRPF do sócio', 'socio', 'socio', true, true, null, '{}'::jsonb, 'Recibo de entrega do IRPF do sócio.', 330),
  ('socio_cnd_rfb', 'cnd_rfb_cpf', 'CND RFB (CPF)', 'socio', 'socio', true, false, 30, '{}'::jsonb, 'CND RFB de cada sócio.', 340),
  ('socio_cadin_se_cnd_ausente', 'cadin_cpf', 'Nada consta CADIN (CPF)', 'socio', 'socio', false, false, 30, '{"quando":"cnd_rfb_cpf_ausente"}'::jsonb, 'Exigido se a CND RFB CPF não for disponibilizada.', 350),
  ('socio_pgfn_se_cnd_ausente', 'pgfn_cpf', 'Nada consta PGFN (CPF)', 'socio', 'socio', false, false, 30, '{"quando":"cnd_rfb_cpf_ausente"}'::jsonb, 'Exigido se a CND RFB CPF não for disponibilizada.', 360),
  ('socio_rating_bacen', 'rating_bacen_cpf', 'Consulta de Rating BACEN (CPF)', 'socio', 'socio', true, false, 30, '{}'::jsonb, 'Consulta de rating/relatório BACEN do CPF.', 370),
  ('socio_cenprot', 'cenprot_cpf', 'Consulta CENPROT (CPF)', 'socio', 'socio', true, false, 30, '{}'::jsonb, 'Consulta de protestos do CPF.', 380),
  ('socio_scr', 'scr_cpf', 'Relatório SCR do CPF', 'socio', 'socio', true, false, 30, '{}'::jsonb, 'Relatório SCR de todos os sócios.', 390),
  ('socio_ccs', 'ccs_cpf', 'Relatório CCS do CPF', 'socio', 'socio', true, false, 30, '{}'::jsonb, 'Relatório CCS de todos os sócios.', 400),
  ('socio_ccf', 'ccf_cpf', 'Relatório CCF do CPF', 'socio', 'socio', true, false, 30, '{}'::jsonb, 'Relatório CCF de todos os sócios.', 410),
  ('socio_conjuge_certidao', 'certidao_casamento', 'Certidão de casamento/divórcio/óbito', 'socio', 'socio', false, true, null, '{"quando":"houver_conjuge"}'::jsonb, 'Documento civil exigido quando houver cônjuge.', 420),
  ('socio_conjuge_serasa', 'consulta_serasa_cpf', 'Consulta Serasa do cônjuge', 'socio', 'conjuge', false, true, 30, '{"quando":"houver_conjuge"}'::jsonb, 'Consulta Serasa exigida em caso de cônjuge.', 430)
ON CONFLICT (codigo) DO UPDATE SET
  tipo_documento = EXCLUDED.tipo_documento,
  nome_amigavel = EXCLUDED.nome_amigavel,
  entidade_tipo = EXCLUDED.entidade_tipo,
  escopo = EXCLUDED.escopo,
  obrigatorio = EXCLUDED.obrigatorio,
  permite_multiplos = EXCLUDED.permite_multiplos,
  validade_dias = EXCLUDED.validade_dias,
  condicao = EXCLUDED.condicao,
  descricao = EXCLUDED.descricao,
  ordem = EXCLUDED.ordem,
  ativo = true,
  atualizado_em = NOW();

-- Prompt específico do Cartão CNPJ para futura extração IA estruturada.
INSERT INTO public.ia_prompts_documentais (codigo, versao, nome, descricao, prompt_sistema, prompt_usuario_template, schema_saida)
VALUES (
  'extrair_cartao_cnpj_receita',
  '1.0.0',
  'Extrair Cartão CNPJ da Receita Federal',
  'Extrai e valida Cartão CNPJ para relatório de crédito empresarial.',
  'Você é um extrator documental de crédito empresarial. Leia somente o documento fornecido. Retorne JSON válido. Não invente campos. Se um campo não existir no documento, retorne null e adicione pendência.',
  'Extraia do Cartão CNPJ: cnpj, matriz_filial, data_abertura, tempo_abertura_meses, alerta_menos_12_meses, nome_empresarial, nome_fantasia, cnae_principal_codigo, cnae_principal_descricao, natureza_juridica_codigo, natureza_juridica_descricao, porte, endereco completo, situacao_cadastral e data_emissao. Valide se a emissão tem menos de 31 dias. Compare com o cadastro/histórico quando houver contexto. Gere alertas se nome empresarial, CNAE, endereço ou situação cadastral divergirem.',
  '{"type":"object","required":["tipo_documento","campos_extraidos","alertas","divergencias","nivel_confianca","revisao_humana_necessaria"],"properties":{"tipo_documento":{"const":"cartao_cnpj"},"campos_extraidos":{"type":"object"},"alertas":{"type":"array"},"divergencias":{"type":"array"},"nivel_confianca":{"type":"number"},"revisao_humana_necessaria":{"type":"boolean"}}}'::jsonb
)
ON CONFLICT (codigo, versao) DO UPDATE SET
  nome = EXCLUDED.nome,
  descricao = EXCLUDED.descricao,
  prompt_sistema = EXCLUDED.prompt_sistema,
  prompt_usuario_template = EXCLUDED.prompt_usuario_template,
  schema_saida = EXCLUDED.schema_saida,
  ativo = true;


-- ============================================================
-- db/migrations/060_fix_acompanhamento_empresas_faturamento.sql
-- ============================================================

-- ============================================================
-- MIGRATION 060: Fix crítico — Acompanhamento, Empresas e Faturamento
-- Data: 2026-06-08
-- Idempotente: seguro para rodar N vezes em qualquer ambiente.
-- Resolve:
--   1. Empresas do acompanhamento bancário sumindo da listagem
--   2. Tela de faturamento não mostrando empresas do acompanhamento
--   3. Semana do acompanhamento não salvando (schema de compensacoes_historico incompleto)
-- ============================================================
BEGIN;

-- ── 1. Garantir colunas novas na acompanhamento_compensacoes_historico ────────
-- O INSERT do backend usa estas colunas que podem não existir em instâncias
-- que nunca rodaram as migrations 026/054 completas.
ALTER TABLE IF EXISTS acompanhamento_compensacoes_historico
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao     NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao    NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_mensal             NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana          NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana       NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal    NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica           NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal       NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal        NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual         NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia             TEXT,
  ADD COLUMN IF NOT EXISTS alerta_aderencia             BOOLEAN       NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS motivo_alerta                TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico          TEXT,
  ADD COLUMN IF NOT EXISTS criado_por                   UUID;

-- ── 2. Garantir UNIQUE constraint para o ON CONFLICT do INSERT ────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = current_schema()
      AND indexname = 'ux_acomp_comp_hist_acomp_semana'
  ) THEN
    CREATE UNIQUE INDEX ux_acomp_comp_hist_acomp_semana
      ON acompanhamento_compensacoes_historico(acompanhamento_id, numero_semana);
  END IF;
END $$;

-- ── 3. Garantir colunas novas em acompanhamento_bancario_atualizacoes ─────────
-- Colunas necessárias para o UPDATE da semana (migrations 026/027/028/054).
ALTER TABLE IF EXISTS acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao     NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao    NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS semanas_no_mes               INTEGER        NOT NULL DEFAULT 4,
  ADD COLUMN IF NOT EXISTS acumulado_mensal             NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_anual              NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana          NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana       NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal    NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS semanas_restantes_mes        INTEGER        NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica           NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal       NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal        NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual         NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia             TEXT,
  ADD COLUMN IF NOT EXISTS alerta_aderencia             BOOLEAN        NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS motivo_alerta_aderencia      TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico          TEXT,
  ADD COLUMN IF NOT EXISTS media_mensal_referencia      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS limite_mensal_referencia     NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS media_semanal_referencia     NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quantidade_semanas_mes       INTEGER        NOT NULL DEFAULT 4,
  ADD COLUMN IF NOT EXISTS compensacao_semana_anterior  NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS entrada_com_compensacao      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS diferenca_referencia_semanal NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS compensacao_necessaria_proxima NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS alerta_rating                BOOLEAN        NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS saldo_faltante_mes           NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_dinamica_proxima_semana NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_mes          NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS scr_status                   TEXT,
  ADD COLUMN IF NOT EXISTS cenprot_status               TEXT,
  ADD COLUMN IF NOT EXISTS serasa_status                TEXT,
  ADD COLUMN IF NOT EXISTS cnd_status                   TEXT,
  ADD COLUMN IF NOT EXISTS pld_aml_status               TEXT,
  ADD COLUMN IF NOT EXISTS coaf_status                  TEXT,
  ADD COLUMN IF NOT EXISTS analise_semana               TEXT,
  ADD COLUMN IF NOT EXISTS orientacao_cliente           TEXT,
  ADD COLUMN IF NOT EXISTS proxima_acao                 TEXT;

-- ── 4. Garantir coluna de permissão financeira em colaboradores ───────────────
ALTER TABLE IF EXISTS colaboradores
  ADD COLUMN IF NOT EXISTS acesso_acompanhamento_financeiro BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE colaboradores
SET acesso_acompanhamento_financeiro = TRUE
WHERE LOWER(TRIM(COALESCE(cargo, '')))  IN ('administrador','admin','diretor','gestor_credito','gestor de credito')
   OR LOWER(TRIM(COALESCE(perfil, ''))) IN ('administrador','admin','diretor','gestor_credito','gestor de credito');

-- ── 5. Índices de performance para a query de empresas com acompanhamento ─────
CREATE INDEX IF NOT EXISTS idx_acomp_bancario_empresa_status
  ON acompanhamentos_bancarios(empresa_id, status)
  WHERE empresa_id IS NOT NULL;

-- ── 6. Garantir que empresas vinculadas a acompanhamentos não fiquem bloqueadas ─
-- Empresas criadas via acompanhamento bancário não passam pelo flow de enriquecimento
-- de CNPJ, por isso ficam com cadastro_completo=false e bloqueado_operacional=true.
-- Estas empresas são válidas — estão em uso ativo no módulo mais importante do sistema.
UPDATE empresas e
SET
  bloqueado_operacional = FALSE,
  cadastro_status = CASE
    WHEN COALESCE(e.cadastro_status, '') = '' THEN 'em_uso_acompanhamento'
    ELSE e.cadastro_status
  END
WHERE EXISTS (
  SELECT 1 FROM acompanhamentos_bancarios ab
  WHERE ab.empresa_id = e.id
    AND ab.status NOT IN ('encerrado', 'cancelado')
)
AND COALESCE(e.bloqueado_operacional, FALSE) = TRUE;

COMMIT;
-- ── FIM DA MIGRATION 060 ──────────────────────────────────────────────────────


-- ============================================================
-- db/migrations/060_fix_urgente_atualizacao_semanal.sql
-- ============================================================

-- ============================================================
-- MIGRATION 060 — FIX URGENTE: Acompanhamento bancário
-- Roda direto no banco sem precisar de deploy.
-- Comando: psql $DATABASE_URL < db/migrations/060_fix_urgente_atualizacao_semanal.sql
-- Idempotente: seguro para rodar N vezes.
-- ============================================================
BEGIN;

-- ── Tabela principal de atualizações semanais ─────────────────────────────────
ALTER TABLE acompanhamento_bancario_atualizacoes
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref          NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao       NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS semanas_no_mes                 INTEGER        NOT NULL DEFAULT 4,
  ADD COLUMN IF NOT EXISTS acumulado_mensal               NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_anual                NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana            NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana         NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal   NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS semanas_restantes_mes          INTEGER        NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica             NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima          NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal         NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal          NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual           NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia               TEXT,
  ADD COLUMN IF NOT EXISTS alerta_aderencia               BOOLEAN        NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS motivo_alerta_aderencia        TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico            TEXT,
  ADD COLUMN IF NOT EXISTS scr_status                     TEXT,
  ADD COLUMN IF NOT EXISTS cenprot_status                 TEXT,
  ADD COLUMN IF NOT EXISTS serasa_status                  TEXT,
  ADD COLUMN IF NOT EXISTS cnd_status                     TEXT,
  ADD COLUMN IF NOT EXISTS pld_aml_status                 TEXT,
  ADD COLUMN IF NOT EXISTS coaf_status                    TEXT,
  ADD COLUMN IF NOT EXISTS analise_semana                 TEXT,
  ADD COLUMN IF NOT EXISTS orientacao_cliente             TEXT,
  ADD COLUMN IF NOT EXISTS proxima_acao                   TEXT,
  ADD COLUMN IF NOT EXISTS media_mensal_referencia        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS limite_mensal_referencia       NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS media_semanal_referencia       NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quantidade_semanas_mes         INTEGER        NOT NULL DEFAULT 4,
  ADD COLUMN IF NOT EXISTS compensacao_semana_anterior    NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS entrada_com_compensacao        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS diferenca_referencia_semanal   NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS compensacao_necessaria_proxima NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS alerta_rating                  BOOLEAN        NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS saldo_faltante_mes             NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_dinamica_proxima_semana   NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_mes            NUMERIC(15,2) NOT NULL DEFAULT 0;

-- ── Tabela de histórico de compensações ──────────────────────────────────────
ALTER TABLE acompanhamento_compensacoes_historico
  ADD COLUMN IF NOT EXISTS faturamento_anual_ref          NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_anual_movimentacao        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS faturamento_mensal_base        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_mensal_movimentacao       NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referencia_semanal_base        NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_semanal_movimentacao      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS acumulado_mensal               NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_abaixo_semana            NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_excedente_semana         NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_faltante_ref_mensal      NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_disponivel_teto_mensal   NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS meta_base_dinamica             NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS teto_dinamico_proxima          NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_semanal         NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_mensal          NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS percentual_uso_anual           NUMERIC(8,2)  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status_aderencia               TEXT,
  ADD COLUMN IF NOT EXISTS alerta_aderencia               BOOLEAN        NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS motivo_alerta                  TEXT,
  ADD COLUMN IF NOT EXISTS diagnostico_tecnico            TEXT,
  ADD COLUMN IF NOT EXISTS criado_por                     UUID;

-- ── UNIQUE constraint para ON CONFLICT do INSERT de compensações ─────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = current_schema()
      AND indexname = 'ux_acomp_comp_hist_acomp_semana'
  ) THEN
    CREATE UNIQUE INDEX ux_acomp_comp_hist_acomp_semana
      ON acompanhamento_compensacoes_historico(acompanhamento_id, numero_semana);
  END IF;
END $$;

-- ── Índice de performance para query de empresas com acompanhamento ───────────
CREATE INDEX IF NOT EXISTS idx_acomp_bancario_empresa_status
  ON acompanhamentos_bancarios(empresa_id, status)
  WHERE empresa_id IS NOT NULL;

-- ── Desbloquear empresas que estão em acompanhamento ativo ───────────────────
UPDATE empresas e
SET bloqueado_operacional = FALSE
WHERE EXISTS (
  SELECT 1 FROM acompanhamentos_bancarios ab
  WHERE ab.empresa_id = e.id
    AND ab.status NOT IN ('encerrado', 'cancelado')
)
AND COALESCE(e.bloqueado_operacional, FALSE) = TRUE;

-- ── Permissão de acesso ao módulo financeiro ─────────────────────────────────
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS acesso_acompanhamento_financeiro BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE colaboradores
SET acesso_acompanhamento_financeiro = TRUE
WHERE LOWER(TRIM(COALESCE(cargo,'')))  IN ('administrador','admin','diretor','gestor_credito','gestor de credito')
   OR LOWER(TRIM(COALESCE(perfil,''))) IN ('administrador','admin','diretor','gestor_credito','gestor de credito');

COMMIT;

-- Verificação final
SELECT
  'acompanhamento_bancario_atualizacoes'   AS tabela,
  COUNT(*)                                  AS colunas_novas
FROM information_schema.columns
WHERE table_name = 'acompanhamento_bancario_atualizacoes'
  AND column_name IN (
    'faturamento_anual_ref','teto_anual_movimentacao','acumulado_mensal',
    'status_aderencia','diagnostico_tecnico','scr_status','analise_semana'
  )
UNION ALL
SELECT
  'acompanhamento_compensacoes_historico'  AS tabela,
  COUNT(*)                                  AS colunas_novas
FROM information_schema.columns
WHERE table_name = 'acompanhamento_compensacoes_historico'
  AND column_name IN (
    'faturamento_anual_ref','teto_anual_movimentacao','acumulado_mensal',
    'status_aderencia','diagnostico_tecnico'
  );


-- ============================================================
-- db/migrations/061_documentos_slots_visualizacao_exportacao_segura.sql
-- ============================================================

-- 061_documentos_slots_visualizacao_exportacao_segura.sql
-- Garante a base mínima para anexar cada documento em seu local correto,
-- visualizar com JWT via blob e exportar documentos selecionados sem regressão.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE IF EXISTS public.documentos_arquivos
  ADD COLUMN IF NOT EXISTS data_emissao_documento DATE,
  ADD COLUMN IF NOT EXISTS data_validade_documento DATE,
  ADD COLUMN IF NOT EXISTS validade_dias INTEGER,
  ADD COLUMN IF NOT EXISTS status_validade TEXT DEFAULT 'nao_verificado',
  ADD COLUMN IF NOT EXISTS exige_revisao_humana BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS nome_customizado TEXT,
  ADD COLUMN IF NOT EXISTS resultado_validacao JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS ultima_extracao_ia_id UUID,
  ADD COLUMN IF NOT EXISTS ultima_indexacao_rag_id UUID;

ALTER TABLE IF EXISTS public.documentos_arquivos
  DROP CONSTRAINT IF EXISTS documentos_arquivos_tipo_chk;

ALTER TABLE IF EXISTS public.documentos_arquivos
  ADD CONSTRAINT documentos_arquivos_tipo_chk CHECK (tipo_documento IN (
    'contrato_prestacao_servicos','contrato_assessoria',
    'cartao_cnpj','qsa','atos_junta_comercial','contrato_social','alteracao_contratual',
    'documento_socio','rg','cpf','cnh','comprovante_residencia','comprovante_endereco',
    'imposto_renda','irpf','recibo_irpf','certidao_casamento','averbacao_divorcio','certidao_obito',
    'rating_bacen_cnpj','rating_bacen_cpf','cenprot_cnpj','cenprot_cpf',
    'cnd_rfb_cnpj','cnd_rfb_cpf','cadin_cnpj','cadin_cpf','pgfn_cnpj','pgfn_cpf',
    'simples_nacional','pgdas','pgmei','ecf','recibo_ecf','recibo_pgdas','recibo_pgmei',
    'defis','dasn_simei','recibo_defis','recibo_dasn_simei',
    'scr_cnpj','ccs_cnpj','ccf_cnpj','scr_cpf','ccs_cpf','ccf_cpf',
    'consulta_serasa_cnpj','consulta_serasa_cpf','compartilhamento_ecac',
    'foto_fachada','foto_interna_1','foto_interna_2','foto_interna_3',
    'faturamento_12_meses','comprovante_faturamento','declaracao_faturamento','extrato_bancario',
    'balanco','dre','certidao','procuracao','nire','estatuto','contrato_gerado','contrato_assinado','outros'
  ));

CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_entidade_tipo_doc
  ON public.documentos_arquivos(entidade_tipo, entidade_id, tipo_documento)
  WHERE excluido_em IS NULL;

CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_status_validade
  ON public.documentos_arquivos(status_validade)
  WHERE excluido_em IS NULL;

CREATE INDEX IF NOT EXISTS idx_documentos_arquivos_data_emissao
  ON public.documentos_arquivos(data_emissao_documento)
  WHERE excluido_em IS NULL;


-- ============================================================
-- db/migrations/062_analise_cnpj_receita_cartao.sql
-- ============================================================

-- 062_analise_cnpj_receita_cartao.sql
-- Fase 1 da IA documental: análise do CNPJ usando Receita Federal + Cartão CNPJ anexado.
-- Idempotente: pode ser executada mais de uma vez.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.analises_cnpj_empresa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  cartao_cnpj_arquivo_id UUID NULL REFERENCES public.documentos_arquivos(id) ON DELETE SET NULL,

  status TEXT NOT NULL DEFAULT 'concluida',
  score_cnpj INTEGER NOT NULL DEFAULT 0,
  risco_cnpj TEXT NOT NULL DEFAULT 'nao_calculado',

  cnpj TEXT NULL,
  matriz_filial TEXT NULL,
  data_abertura DATE NULL,
  idade_meses INTEGER NULL,
  tempo_abertura_descricao TEXT NULL,
  alerta_menos_12_meses BOOLEAN NOT NULL DEFAULT false,
  alerta_mais_36_meses BOOLEAN NOT NULL DEFAULT false,

  situacao_cadastral TEXT NULL,
  risco_situacao TEXT NULL,
  cnae_principal TEXT NULL,
  natureza_juridica TEXT NULL,
  porte TEXT NULL,
  capital_social NUMERIC NULL,

  data_emissao_cartao DATE NULL,
  dias_emissao_cartao INTEGER NULL,
  status_validade_cartao TEXT NOT NULL DEFAULT 'nao_verificado',
  cartao_pendente_ocr BOOLEAN NOT NULL DEFAULT false,
  cartao_anexado BOOLEAN NOT NULL DEFAULT false,

  campos_receita JSONB NOT NULL DEFAULT '{}'::jsonb,
  campos_cartao JSONB NOT NULL DEFAULT '{}'::jsonb,
  comparacao JSONB NOT NULL DEFAULT '{}'::jsonb,
  divergencias JSONB NOT NULL DEFAULT '[]'::jsonb,
  alertas JSONB NOT NULL DEFAULT '[]'::jsonb,
  pontos_positivos JSONB NOT NULL DEFAULT '[]'::jsonb,
  pontos_atencao JSONB NOT NULL DEFAULT '[]'::jsonb,
  pontos_impeditivos JSONB NOT NULL DEFAULT '[]'::jsonb,
  recomendacoes JSONB NOT NULL DEFAULT '[]'::jsonb,
  diagnostico TEXT NULL,
  resultado JSONB NOT NULL DEFAULT '{}'::jsonb,
  fonte_receita TEXT NULL,

  criado_por UUID NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT analises_cnpj_empresa_status_chk CHECK (status IN ('concluida','pendente_documento','pendente_ocr','revisao_humana','falhou')),
  CONSTRAINT analises_cnpj_empresa_risco_chk CHECK (risco_cnpj IN ('baixo','medio','alto','critico','nao_calculado')),
  CONSTRAINT analises_cnpj_empresa_validade_chk CHECK (status_validade_cartao IN ('valido','vencido','pendente','nao_verificado','divergente','ilegivel'))
);

CREATE INDEX IF NOT EXISTS idx_analises_cnpj_empresa_empresa_id ON public.analises_cnpj_empresa (empresa_id);
CREATE INDEX IF NOT EXISTS idx_analises_cnpj_empresa_criado_em ON public.analises_cnpj_empresa (criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_analises_cnpj_empresa_score ON public.analises_cnpj_empresa (score_cnpj);
CREATE INDEX IF NOT EXISTS idx_analises_cnpj_empresa_resultado_gin ON public.analises_cnpj_empresa USING GIN (resultado);

CREATE OR REPLACE FUNCTION public.atualizar_timestamp_analises_cnpj_empresa()
RETURNS TRIGGER AS $$
BEGIN
  NEW.atualizado_em = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_analises_cnpj_empresa_atualizado_em ON public.analises_cnpj_empresa;
CREATE TRIGGER trg_analises_cnpj_empresa_atualizado_em
BEFORE UPDATE ON public.analises_cnpj_empresa
FOR EACH ROW EXECUTE FUNCTION public.atualizar_timestamp_analises_cnpj_empresa();


-- ============================================================
-- db/migrations/063_orcamentos_timbrados.sql
-- ============================================================

-- 063_orcamentos_timbrados.sql
-- Orçamentos timbrados Destrava / PermuPay com clientes PJ/PF, edição livre, assinaturas e anexos.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.orcamentos_timbrados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero TEXT UNIQUE,
  tipo_cliente TEXT NOT NULL DEFAULT 'empresa'
    CHECK (tipo_cliente IN ('empresa','pessoa_fisica','livre')),
  empresa_id UUID REFERENCES public.empresas(id) ON DELETE SET NULL,
  cliente_pf_id UUID REFERENCES public.clientes_pf(id) ON DELETE SET NULL,
  cliente_nome TEXT,
  cliente_documento TEXT,
  cliente_email TEXT,
  cliente_telefone TEXT,
  marca TEXT NOT NULL DEFAULT 'destrava'
    CHECK (marca IN ('destrava','permupay')),
  titulo TEXT NOT NULL DEFAULT 'Orçamento de Serviços',
  descricao TEXT,
  conteudo TEXT NOT NULL DEFAULT '',
  valor_total NUMERIC(14,2) DEFAULT 0,
  validade_dias INTEGER DEFAULT 7,
  validade_ate DATE,
  status TEXT NOT NULL DEFAULT 'rascunho'
    CHECK (status IN ('rascunho','finalizado','enviado','cancelado')),
  assinaturas JSONB NOT NULL DEFAULT '[]'::jsonb,
  anexos_count INTEGER NOT NULL DEFAULT 0,
  pdf_path TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  criado_por UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finalizado_em TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.orcamentos_timbrados_anexos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  orcamento_id UUID NOT NULL REFERENCES public.orcamentos_timbrados(id) ON DELETE CASCADE,
  tipo TEXT DEFAULT 'anexo',
  descricao TEXT,
  nome_original TEXT NOT NULL,
  mime_type TEXT,
  tamanho_bytes BIGINT,
  storage_path TEXT NOT NULL,
  url TEXT,
  hash_sha256 TEXT,
  criado_por UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orcamentos_timbrados_status ON public.orcamentos_timbrados(status);
CREATE INDEX IF NOT EXISTS idx_orcamentos_timbrados_empresa ON public.orcamentos_timbrados(empresa_id);
CREATE INDEX IF NOT EXISTS idx_orcamentos_timbrados_cliente_pf ON public.orcamentos_timbrados(cliente_pf_id);
CREATE INDEX IF NOT EXISTS idx_orcamentos_timbrados_criado_em ON public.orcamentos_timbrados(criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_orcamentos_timbrados_anexos_orcamento ON public.orcamentos_timbrados_anexos(orcamento_id);

CREATE OR REPLACE FUNCTION public.atualizar_timestamp_orcamentos_timbrados()
RETURNS TRIGGER AS $$
BEGIN
  NEW.atualizado_em = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orcamentos_timbrados_atualizado_em ON public.orcamentos_timbrados;

CREATE TRIGGER trg_orcamentos_timbrados_atualizado_em
BEFORE UPDATE ON public.orcamentos_timbrados
FOR EACH ROW
EXECUTE FUNCTION public.atualizar_timestamp_orcamentos_timbrados();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.orcamentos_timbrados TO destravadb;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.orcamentos_timbrados_anexos TO destravadb;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO destravadb;


-- ============================================================
-- db/migrations/064_preservar_documentos_anexos.sql
-- ============================================================

-- 064_preservar_documentos_anexos.sql
-- Regra de segurança: anexos/documentos não devem ser apagados fisicamente.
-- Esta migration permite arquivamento lógico dos anexos de orçamentos.

ALTER TABLE public.orcamentos_timbrados_anexos
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ativo';

ALTER TABLE public.orcamentos_timbrados_anexos
  ADD COLUMN IF NOT EXISTS arquivado_em TIMESTAMPTZ;

ALTER TABLE public.orcamentos_timbrados_anexos
  ADD COLUMN IF NOT EXISTS arquivado_por UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL;

UPDATE public.orcamentos_timbrados_anexos
   SET status = 'ativo'
 WHERE status IS NULL;

CREATE INDEX IF NOT EXISTS idx_orcamentos_timbrados_anexos_status
  ON public.orcamentos_timbrados_anexos(status);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.orcamentos_timbrados_anexos TO destravadb;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO destravadb;


-- ============================================================
-- db/migrations/065_empresas_uf_compat_orcamentos_receita.sql
-- ============================================================

-- 065_empresas_uf_compat_orcamentos_receita.sql
-- Compatibilidade sem regressão: algumas rotas legadas ainda referenciam empresas.uf,
-- enquanto o cadastro principal usa empresas.estado. Mantém os dois campos sincronizados.

ALTER TABLE public.empresas
  ADD COLUMN IF NOT EXISTS uf TEXT;

UPDATE public.empresas
   SET uf = UPPER(SUBSTRING(COALESCE(NULLIF(TRIM(uf), ''), NULLIF(TRIM(estado), '')) FROM 1 FOR 2))
 WHERE COALESCE(NULLIF(TRIM(uf), ''), '') = ''
   AND COALESCE(NULLIF(TRIM(estado), ''), '') <> '';

UPDATE public.empresas
   SET estado = UPPER(SUBSTRING(COALESCE(NULLIF(TRIM(estado), ''), NULLIF(TRIM(uf), '')) FROM 1 FOR 2))
 WHERE COALESCE(NULLIF(TRIM(estado), ''), '') = ''
   AND COALESCE(NULLIF(TRIM(uf), ''), '') <> '';

CREATE OR REPLACE FUNCTION public.sincronizar_empresas_estado_uf()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado IS NOT NULL AND TRIM(NEW.estado) <> '' THEN
    NEW.estado := UPPER(SUBSTRING(TRIM(NEW.estado) FROM 1 FOR 2));
  END IF;

  IF NEW.uf IS NOT NULL AND TRIM(NEW.uf) <> '' THEN
    NEW.uf := UPPER(SUBSTRING(TRIM(NEW.uf) FROM 1 FOR 2));
  END IF;

  IF (NEW.uf IS NULL OR TRIM(NEW.uf) = '') AND NEW.estado IS NOT NULL AND TRIM(NEW.estado) <> '' THEN
    NEW.uf := NEW.estado;
  END IF;

  IF (NEW.estado IS NULL OR TRIM(NEW.estado) = '') AND NEW.uf IS NOT NULL AND TRIM(NEW.uf) <> '' THEN
    NEW.estado := NEW.uf;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_empresas_estado_uf_sync ON public.empresas;

CREATE TRIGGER trg_empresas_estado_uf_sync
BEFORE INSERT OR UPDATE OF estado, uf ON public.empresas
FOR EACH ROW
EXECUTE FUNCTION public.sincronizar_empresas_estado_uf();

CREATE INDEX IF NOT EXISTS idx_empresas_uf ON public.empresas(uf);

GRANT SELECT, INSERT, UPDATE ON public.empresas TO destravadb;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO destravadb;


-- ============================================================
-- db/migrations/066_orcamentos_itens.sql
-- ============================================================

-- 066_orcamentos_itens.sql
-- Adiciona coluna itens (JSONB) à tabela orcamentos_timbrados para itens configuráveis com valor individual.

ALTER TABLE public.orcamentos_timbrados
  ADD COLUMN IF NOT EXISTS itens JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.orcamentos_timbrados.itens IS
  'Itens do orçamento: [{descricao: string, quantidade: number, valor_unitario: number}]';


-- ============================================================
-- db/migrations/067_fix_documentos_check_constraint.sql
-- ============================================================

-- 067_fix_documentos_check_constraint.sql
-- Recria a CHECK constraint documentos_arquivos_tipo_documento com lista completa e definitiva.
-- Idempotente: DROP IF EXISTS antes de recriar.

BEGIN;

ALTER TABLE public.documentos_arquivos
  DROP CONSTRAINT IF EXISTS documentos_arquivos_tipo_documento_check;

ALTER TABLE public.documentos_arquivos
  DROP CONSTRAINT IF EXISTS documentos_arquivos_tipo_chk;

ALTER TABLE public.documentos_arquivos
  ADD CONSTRAINT documentos_arquivos_tipo_chk CHECK (tipo_documento IN (
    -- Contratos
    'contrato_prestacao_servicos','contrato_assessoria','contrato_social','alteracao_contratual',
    'contrato_gerado','contrato_assinado',
    -- Empresa
    'cartao_cnpj','qsa','atos_junta_comercial','nire','estatuto','procuracao',
    -- Sócios / Pessoal
    'documento_socio','rg','cpf','cnh','comprovante_residencia','comprovante_endereco',
    'imposto_renda','irpf','recibo_irpf',
    'certidao_casamento','averbacao_divorcio','certidao_obito',
    -- Certidões CNPJ
    'rating_bacen_cnpj','cenprot_cnpj','cnd_rfb_cnpj','cadin_cnpj','pgfn_cnpj',
    'scr_cnpj','ccs_cnpj','ccf_cnpj','consulta_serasa_cnpj','ccf_cnpj',
    -- Certidões CPF
    'rating_bacen_cpf','cenprot_cpf','cnd_rfb_cpf','cadin_cpf','pgfn_cpf',
    'scr_cpf','ccs_cpf','ccf_cpf','consulta_serasa_cpf',
    -- Fiscal / Tributário
    'simples_nacional','pgdas','pgmei','ecf',
    'recibo_ecf','recibo_pgdas','recibo_pgmei',
    'defis','dasn_simei','recibo_defis','recibo_dasn_simei',
    -- Financeiro
    'faturamento_12_meses','comprovante_faturamento','declaracao_faturamento',
    'extrato_bancario','balanco','dre','certidao',
    -- eCAC / Fotos
    'compartilhamento_ecac',
    'foto_fachada','foto_interna_1','foto_interna_2','foto_interna_3',
    -- Outros
    'outros'
  ));

COMMIT;


-- ============================================================
-- db/migrations/067_orcamentos_marca_aragao.sql
-- ============================================================

-- 067_orcamentos_marca_aragao.sql
-- Permite Aragão Serviços como empresa prestadora/marca em orçamentos.

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.orcamentos_timbrados'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%marca%'
  LOOP
    EXECUTE format('ALTER TABLE public.orcamentos_timbrados DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;
END $$;

ALTER TABLE public.orcamentos_timbrados
ADD CONSTRAINT orcamentos_timbrados_marca_check
CHECK (marca IN ('destrava', 'permupay', 'aragao'));

CREATE INDEX IF NOT EXISTS idx_orcamentos_timbrados_marca
ON public.orcamentos_timbrados (marca);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.orcamentos_timbrados TO destravadb;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.orcamentos_timbrados_anexos TO destravadb;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO destravadb;


-- ============================================================
-- db/migrations/068_imoveis_crm_completo.sql
-- ============================================================

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


-- ============================================================
-- db/migrations/069_contratos_avancados_imobiliarias.sql
-- ============================================================

-- ============================================================================
-- Migração 069 — Contratos avançados + Imobiliárias + Corretores + Vídeo
--
-- Adiciona os demais tipos de contrato usados no mercado imobiliário
-- (promessa de compra e venda, assessoria com/sem exclusividade, avaliação
-- de imóveis, aluguel) e a estrutura de configuração multi-imobiliária /
-- multi-corretor, preparando o sistema para operar com várias imobiliárias
-- no futuro. Por ora, o papel timbrado dos PDFs continua exclusivamente
-- Casa DF — esta migração cria apenas a base de dados/configuração.
--
-- Idempotente. Rode com: psql "$DATABASE_URL" -f db/migrations/069_contratos_avancados_imobiliarias.sql
-- ============================================================================

-- ── Novos tipos de contrato (ALTER TYPE ADD VALUE não pode rodar dentro de
--    transação em versões antigas do Postgres — statements isolados) ────────
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'promessa_compra_venda';
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'assessoria_venda_exclusiva';
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'assessoria_venda_sem_exclusiva';
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'avaliacao_imovel';
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'aluguel';

BEGIN;

-- ── Tabela: imobiliarias (multi-imobiliária, para uso futuro) ──────────────
CREATE TABLE IF NOT EXISTS imobiliarias (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome           VARCHAR(160) NOT NULL,
  cnpj           VARCHAR(20),
  creci_juridico VARCHAR(30),
  logo_url       VARCHAR(400),
  endereco       VARCHAR(220),
  cidade         VARCHAR(120) DEFAULT 'Brasília',
  uf             VARCHAR(2) DEFAULT 'DF',
  telefone       VARCHAR(30),
  whatsapp       VARCHAR(30),
  email          VARCHAR(160),
  site_url       VARCHAR(200),
  instagram_url  VARCHAR(200),
  cor_primaria   VARCHAR(9) DEFAULT '#b45309',
  rodape_texto   TEXT,
  padrao         BOOLEAN NOT NULL DEFAULT FALSE,     -- imobiliária usada como padrão do sistema
  ativa          BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_imobiliarias_unica_padrao ON imobiliarias(padrao) WHERE padrao = TRUE;

-- Seed: garante que a Casa DF exista como imobiliária padrão
INSERT INTO imobiliarias (nome, cnpj, endereco, cidade, uf, telefone, whatsapp, email, site_url, cor_primaria, padrao, ativa)
SELECT 'Casa DF — Gestão Imobiliária', NULL, 'QND 25 Lote 40 - Taguatinga Norte', 'Brasília', 'DF',
       '(61) 3526-8355', '(61) 3526-8355', 'contato@casadf.com.br', 'https://casadf.com.br', '#b45309', TRUE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM imobiliarias WHERE padrao = TRUE);

-- ── Tabela: corretores ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS corretores (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  imobiliaria_id UUID REFERENCES imobiliarias(id) ON DELETE SET NULL,
  usuario_id     UUID,                                 -- vincula a um usuário/colaborador do sistema, se aplicável
  nome           VARCHAR(160) NOT NULL,
  creci          VARCHAR(30),
  telefone       VARCHAR(30),
  whatsapp       VARCHAR(30),
  email          VARCHAR(160),
  foto_url       VARCHAR(400),
  ativo          BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_corretores_imobiliaria ON corretores(imobiliaria_id);

-- ── Vincula imóveis e contratos à imobiliária / corretor ────────────────────
ALTER TABLE imoveis ADD COLUMN IF NOT EXISTS imobiliaria_id UUID REFERENCES imobiliarias(id) ON DELETE SET NULL;
ALTER TABLE imoveis ADD COLUMN IF NOT EXISTS corretor_id    UUID REFERENCES corretores(id) ON DELETE SET NULL;
ALTER TABLE imoveis ADD COLUMN IF NOT EXISTS video_url      VARCHAR(400);
ALTER TABLE imoveis ADD COLUMN IF NOT EXISTS tour_virtual_url VARCHAR(400);

ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS imobiliaria_id UUID REFERENCES imobiliarias(id) ON DELETE SET NULL;
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS corretor_id    UUID REFERENCES corretores(id) ON DELETE SET NULL;

-- Campos específicos para os novos tipos de contrato (aluguel, avaliação, exclusividade)
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS prazo_vigencia_meses SMALLINT;
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS garantia_locaticia   VARCHAR(40); -- caucao, fianca, seguro_fianca, titulo_capitalizacao
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS valor_caucao         NUMERIC(14,2);
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS indice_reajuste      VARCHAR(20); -- IGP-M, IPCA...
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS metodologia_avaliacao TEXT;
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS valor_avaliacao      NUMERIC(14,2);

-- Preenche a imobiliária padrão nos contratos já existentes sem valor
UPDATE contratos_imobiliarios SET imobiliaria_id = (SELECT id FROM imobiliarias WHERE padrao = TRUE LIMIT 1)
WHERE imobiliaria_id IS NULL;

UPDATE imoveis SET imobiliaria_id = (SELECT id FROM imobiliarias WHERE padrao = TRUE LIMIT 1)
WHERE imobiliaria_id IS NULL;

COMMIT;
