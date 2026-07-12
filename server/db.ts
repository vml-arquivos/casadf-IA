import pkg from 'pg';

const { Pool } = pkg;

type PoolOptions = {
  max?: number;
  idleTimeoutMillis?: number;
  connectionTimeoutMillis?: number;
};

/**
 * Detecta se a conexão precisa de SSL.
 * - Supabase, AWS RDS, Neon, Render → SSL automático
 * - Coolify (postgres interno) → sem SSL (rede interna Docker)
 * - Forçável via DATABASE_SSL=true
 */
export function databaseNeedsSsl(dbUrl = process.env.DATABASE_URL || ''): boolean {
  // Se forçado explicitamente
  if (process.env.DATABASE_SSL === 'true') return true;

  // Se explicitamente desligado (Coolify internal, Docker internal, etc.)
  if (process.env.DATABASE_SSL === 'false') return false;

  // Detecta provedores que exigem SSL
  if (
    /supabase\.co|supabase\.com|amazonaws\.com|render\.com|neon\.tech|pooler\.supabase\.com/i.test(dbUrl)
  ) {
    return true;
  }

  // Hostnames internos do Coolify/Docker não precisam de SSL
  if (/postgres|coolify|docker|internal|localhost/i.test(dbUrl)) {
    return false;
  }

  // Padrão: sem SSL (adequado para Coolify postgres interno na mesma VPS)
  return false;
}

/**
 * Cria o pool de conexões PostgreSQL.
 * - Em produção (Coolify): pool maior (15 conexões) para suportar IA + CRM + uploads
 * - Variável POOL_MAX permite ajuste sem redeploy
 */
export function createPool(options: PoolOptions = {}) {
  const dbUrl = process.env.DATABASE_URL || '';
  return new Pool({
    connectionString: dbUrl,
    ssl: databaseNeedsSsl(dbUrl) ? { rejectUnauthorized: false } : false,
    max: options.max ?? Number(process.env.POOL_MAX || 15),
    idleTimeoutMillis: options.idleTimeoutMillis ?? Number(process.env.POOL_IDLE_TIMEOUT || 30000),
    connectionTimeoutMillis: options.connectionTimeoutMillis ?? Number(process.env.POOL_CONNECTION_TIMEOUT || 5000),
  });
}

export default createPool;
