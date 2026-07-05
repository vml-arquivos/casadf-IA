import pkg from 'pg';

const { Pool } = pkg;

type PoolOptions = {
  max?: number;
  idleTimeoutMillis?: number;
  connectionTimeoutMillis?: number;
};

export function databaseNeedsSsl(dbUrl = process.env.DATABASE_URL || ''): boolean {
  return (
    process.env.DATABASE_SSL === 'true' ||
    /supabase\.co|supabase\.com|amazonaws\.com|render\.com|neon\.tech|pooler\.supabase\.com/i.test(dbUrl)
  );
}

export function createPool(options: PoolOptions = {}) {
  const dbUrl = process.env.DATABASE_URL || '';
  return new Pool({
    connectionString: dbUrl,
    ssl: databaseNeedsSsl(dbUrl) ? { rejectUnauthorized: false } : false,
    max: options.max ?? 10,
    idleTimeoutMillis: options.idleTimeoutMillis ?? 30000,
    connectionTimeoutMillis: options.connectionTimeoutMillis ?? 5000,
  });
}

export default createPool;
