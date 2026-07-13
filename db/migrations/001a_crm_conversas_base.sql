-- ============================================================
-- MIGRAÇÃO 001 — Tabelas base de conversas CRM
-- Versão: 1.0 | Data: 2026-07-13
--
-- O QUE ESTA MIGRATION FAZ:
--   1. Tabela crm_conversas: conversas canônicas entre leads e empresa
--   2. Tabela crm_mensagens: mensagens de conversas
--   3. Tabela crm_eventos_webhook: eventos de webhook para auditoria
--   4. Índices para performance
--   5. Triggers para auditoria e sincronização
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

-- ─── 1. Tabela: crm_eventos_webhook ──────────────────────────
-- Eventos de webhook com trilha auditável e idempotência
CREATE TABLE IF NOT EXISTS public.crm_eventos_webhook (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id            TEXT UNIQUE NOT NULL,
  origem              TEXT NOT NULL,
  tipo_evento         TEXT NOT NULL,
  payload             JSONB NOT NULL,
  status_processamento TEXT NOT NULL DEFAULT 'pendente'
                        CHECK (status_processamento IN ('pendente', 'processado', 'erro', 'ignorado')),
  erro_detalhe        TEXT,
  processado_em       TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_eventos_status ON public.crm_eventos_webhook(status_processamento);
CREATE INDEX IF NOT EXISTS idx_crm_eventos_created ON public.crm_eventos_webhook(created_at DESC);

-- ─── 2. Tabela: crm_conversas ────────────────────────────────
-- Conversas canônicas entre leads e empresa
CREATE TABLE IF NOT EXISTS public.crm_conversas (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id             UUID REFERENCES public.leads(id) ON DELETE CASCADE,
  canal               TEXT NOT NULL,
  canal_id_externo    TEXT UNIQUE NOT NULL,
  status              TEXT NOT NULL DEFAULT 'aberta'
                        CHECK (status IN ('aberta', 'fechada', 'pendente_ia', 'escalada_humano')),
  resumo_contexto     TEXT,
  iniciada_em         TIMESTAMPTZ DEFAULT NOW(),
  ultima_interacao_em TIMESTAMPTZ DEFAULT NOW(),
  fechada_em          TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_conversas_lead ON public.crm_conversas(lead_id);
CREATE INDEX IF NOT EXISTS idx_crm_conversas_status ON public.crm_conversas(status);
CREATE INDEX IF NOT EXISTS idx_crm_conversas_ultima_int ON public.crm_conversas(ultima_interacao_em DESC);

-- ─── 3. Tabela: crm_mensagens ────────────────────────────────
-- Mensagens canônicas de conversas
CREATE TABLE IF NOT EXISTS public.crm_mensagens (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversa_id         UUID NOT NULL REFERENCES public.crm_conversas(id) ON DELETE CASCADE,
  message_id_externo  TEXT UNIQUE NOT NULL,
  direcao             TEXT NOT NULL CHECK (direcao IN ('inbound', 'outbound')),
  remetente_tipo      TEXT NOT NULL CHECK (remetente_tipo IN ('cliente', 'ia', 'humano', 'sistema')),
  remetente_id        TEXT,
  tipo_conteudo       TEXT NOT NULL DEFAULT 'texto'
                        CHECK (tipo_conteudo IN ('texto', 'audio', 'imagem', 'documento', 'template', 'outro')),
  conteudo            TEXT,
  metadados           JSONB,
  status_envio        TEXT CHECK (status_envio IN ('enviado', 'entregue', 'lido', 'falha')),
  evento_id           UUID REFERENCES public.crm_eventos_webhook(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_mensagens_conversa ON public.crm_mensagens(conversa_id);
CREATE INDEX IF NOT EXISTS idx_crm_mensagens_direcao ON public.crm_mensagens(direcao);
CREATE INDEX IF NOT EXISTS idx_crm_mensagens_created ON public.crm_mensagens(created_at DESC);

-- ─── 4. Triggers para auditoria ──────────────────────────────
-- Atualizar updated_at da conversa
CREATE OR REPLACE FUNCTION public.trg_update_conversa_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_crm_conversas_updated_at') THEN
    CREATE TRIGGER trg_crm_conversas_updated_at
      BEFORE UPDATE ON public.crm_conversas
      FOR EACH ROW EXECUTE FUNCTION public.trg_update_conversa_timestamp();
  END IF;
END $$;

-- Atualizar ultima_interacao_em da conversa ao inserir mensagem
CREATE OR REPLACE FUNCTION public.trg_update_conversa_ultima_interacao()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.crm_conversas 
  SET ultima_interacao_em = NEW.created_at 
  WHERE id = NEW.conversa_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_crm_mensagens_interacao') THEN
    CREATE TRIGGER trg_crm_mensagens_interacao
      AFTER INSERT ON public.crm_mensagens
      FOR EACH ROW EXECUTE FUNCTION public.trg_update_conversa_ultima_interacao();
  END IF;
END $$;

-- ─── 5. Confirmação ──────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'Migration 001 — tabelas base de conversas CRM aplicada em %', NOW();
END $$;
