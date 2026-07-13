-- ============================================================
-- MIGRAÇÃO 071 — Adicionar FK para ia_agentes
-- Versão: 1.0 | Data: 2026-07-13
--
-- O QUE ESTA MIGRATION FAZ:
--   Adiciona a constraint de foreign key para ia_agente_id
--   em crm_caixas, que foi criada sem FK em migration 005.
--   Isso garante que a FK só existe após ia_agentes ser criada
--   em migration 000.
--
-- Idempotente: seguro para reexecutar.
-- ============================================================

-- ─── Adicionar FK para ia_agente_id em crm_caixas ───────────
ALTER TABLE public.crm_caixas
  ADD CONSTRAINT fk_crm_caixas_ia_agente_id
    FOREIGN KEY (ia_agente_id) REFERENCES public.ia_agentes(id) ON DELETE SET NULL;

-- ─── Confirmação ─────────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'Migration 071 — FK para ia_agentes adicionada em %', NOW();
END $$;
