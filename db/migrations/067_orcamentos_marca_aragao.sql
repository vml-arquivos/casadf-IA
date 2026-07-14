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

-- GRANT condicional: 'destravadb' e o usuario/role de producao especifico
-- deste projeto. Em bancos novos (Supabase, outra VPS) essa role pode nao
-- existir, o que quebrava a migracao inteira. Agora so concede se existir.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'destravadb') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.orcamentos_timbrados TO destravadb;
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.orcamentos_timbrados_anexos TO destravadb;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO destravadb;
  END IF;
END $$;
