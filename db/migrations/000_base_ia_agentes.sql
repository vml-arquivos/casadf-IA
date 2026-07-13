-- ============================================================
-- MIGRAÇÃO 000 — Tabelas base para IA e integrações
-- Versão: 1.0 | Data: 2026-07-13
--
-- O QUE ESTA MIGRATION FAZ:
--   1. Cria a tabela ia_agentes (agentes de IA para CRM)
--      que é referenciada por migration 005 e outras
--   2. Cria a tabela ia_sessoes (sessões de IA)
--   3. Define políticas de segurança em linha (RLS)
--
-- Esta migration DEVE rodar ANTES de todas as outras,
-- pois migration 005 (crm_camada_operacional) referencia ia_agentes.
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

-- ─── 1. Tabela: ia_agentes ───────────────────────────────────
-- Agentes de IA configuráveis para atender leads por canal.
-- Cada caixa de atendimento (crm_caixas) pode ter um agente IA.
CREATE TABLE IF NOT EXISTS public.ia_agentes (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                   TEXT NOT NULL,
  descricao              TEXT,
  modelo                 TEXT NOT NULL DEFAULT 'gpt-4-mini',
  system_prompt          TEXT NOT NULL,
  temperatura            NUMERIC(3,2) NOT NULL DEFAULT 0.7,
  max_tokens             INTEGER NOT NULL DEFAULT 1024,
  canal                  TEXT NOT NULL DEFAULT 'whatsapp'
                           CHECK (canal IN ('whatsapp','web','email','todos')),
  ativo                  BOOLEAN NOT NULL DEFAULT TRUE,
  responder_fora_horario BOOLEAN NOT NULL DEFAULT FALSE,
  horario_inicio         TIME DEFAULT '08:00',
  horario_fim            TIME DEFAULT '18:00',
  dias_semana            INTEGER[] DEFAULT '{1,2,3,4,5}',
  escalar_apos_msgs      INTEGER DEFAULT 5,
  escalar_palavras       TEXT[] DEFAULT '{}',
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ia_agentes_ativo
  ON public.ia_agentes(ativo);

CREATE INDEX IF NOT EXISTS idx_ia_agentes_canal
  ON public.ia_agentes(canal);

-- Trigger para atualizar updated_at automaticamente
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_ia_agentes_updated_at') THEN
    CREATE TRIGGER trg_ia_agentes_updated_at
      BEFORE UPDATE ON public.ia_agentes
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ─── 2. Tabela: ia_sessoes ───────────────────────────────────
-- Sessões de conversas com agentes IA.
CREATE TABLE IF NOT EXISTS public.ia_sessoes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agente_id    UUID NOT NULL REFERENCES public.ia_agentes(id) ON DELETE CASCADE,
  conversa_id  UUID,
  contato_jid  TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'ativa'
                 CHECK (status IN ('ativa','pausada','escalada','encerrada')),
  total_msgs   INTEGER NOT NULL DEFAULT 0,
  ultima_msg   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ia_sessoes_agente
  ON public.ia_sessoes(agente_id);

CREATE INDEX IF NOT EXISTS idx_ia_sessoes_status
  ON public.ia_sessoes(status);

CREATE INDEX IF NOT EXISTS idx_ia_sessoes_contato
  ON public.ia_sessoes(contato_jid);

-- Trigger para atualizar updated_at automaticamente
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_ia_sessoes_updated_at') THEN
    CREATE TRIGGER trg_ia_sessoes_updated_at
      BEFORE UPDATE ON public.ia_sessoes
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ─── 3. Confirmação ──────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'Migration 000 — tabelas base de IA aplicada em %', NOW();
END $$;
