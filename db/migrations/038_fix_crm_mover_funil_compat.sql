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
  WHERE etapa_de IS NULL OR etapa_para IS NULL;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS origem_ia BOOLEAN DEFAULT FALSE;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS concluido BOOLEAN DEFAULT TRUE;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
UPDATE public.crm_atividades SET titulo = COALESCE(titulo, descricao, tipo, 'Atividade') WHERE titulo IS NULL;
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
CREATE INDEX IF NOT EXISTS idx_crm_historico_funil_lead_data
  ON public.crm_historico_funil (lead_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_crm_atividades_lead_data
  ON public.crm_atividades (lead_id, created_at DESC);
