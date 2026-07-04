/**
 * CASA DF — Executor de migração completa (banco novo / Supabase)
 * ─────────────────────────────────────────────────────────────────
 * Roda o schema base (db/migrate.sql) seguido de TODAS as migrações
 * numeradas em db/migrations/*.sql, em ordem, em um banco novo/vazio
 * (ex: um projeto Supabase recém-criado).
 *
 * Idempotente: se você já rodou algumas migrações antes e algo falhar
 * porque já existe, pode rodar de novo — a maioria dos arquivos usa
 * "IF NOT EXISTS". Se uma migração específica der erro real, o script
 * para e mostra qual arquivo falhou, para você olhar antes de continuar.
 *
 * Uso:
 *   DATABASE_URL="postgresql://..." node scripts/migrate-all.mjs
 *
 * Para pular o schema base (se o banco já tiver as tabelas iniciais):
 *   DATABASE_URL="..." node scripts/migrate-all.mjs --skip-base
 */
import pkg from "pg";
import { readFileSync, readdirSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const { Pool } = pkg;
const __dirname = dirname(fileURLToPath(import.meta.url));
const skipBase = process.argv.includes("--skip-base");

const dbUrl = process.env.DATABASE_URL || "";
if (!dbUrl) {
  console.error("❌ Defina DATABASE_URL antes de rodar este script.");
  process.exit(1);
}

const exigeSSL =
  process.env.DATABASE_SSL === "true" ||
  /supabase\.co|amazonaws\.com|render\.com|neon\.tech/i.test(dbUrl);

const pool = new Pool({
  connectionString: dbUrl,
  ssl: exigeSSL ? { rejectUnauthorized: false } : false,
});

async function rodarArquivo(client, caminho, nome) {
  const sql = readFileSync(caminho, "utf8");
  // Alguns arquivos (como os que usam ALTER TYPE ... ADD VALUE) não podem
  // rodar dentro de uma transação. Detecta esse caso e roda sem BEGIN/COMMIT.
  const precisaAutocommit = /ALTER TYPE .* ADD VALUE/i.test(sql);

  try {
    if (precisaAutocommit) {
      // Executa statement a statement fora de transação explícita
      const statements = sql
        .split(/;\s*(?:\n|$)/)
        .map((s) => s.trim())
        .filter(Boolean);
      for (const stmt of statements) {
        await client.query(stmt);
      }
    } else {
      await client.query("BEGIN");
      await client.query(sql);
      await client.query("COMMIT");
    }
    console.log(`✅ ${nome}`);
  } catch (err) {
    try { await client.query("ROLLBACK"); } catch {}
    console.error(`❌ Falhou em ${nome}:`);
    console.error(`   ${err.message}`);
    if (err.detail) console.error(`   ${err.detail}`);
    throw err;
  }
}

async function main() {
  console.log("\n🗄️  Casa DF — Migração completa do banco\n");
  const client = await pool.connect();

  try {
    if (!skipBase) {
      await rodarArquivo(client, join(__dirname, "..", "db", "migrate.sql"), "db/migrate.sql (schema base)");
    } else {
      console.log("⏭️  Pulando db/migrate.sql (--skip-base)");
    }

    const migDir = join(__dirname, "..", "db", "migrations");
    const arquivos = readdirSync(migDir)
      .filter((f) => f.endsWith(".sql") && !/rollback/i.test(f))
      .sort();

    for (const arquivo of arquivos) {
      await rodarArquivo(client, join(migDir, arquivo), arquivo);
    }

    console.log("\n🎉 Migração completa concluída com sucesso!\n");
  } catch (err) {
    console.error("\n🛑 Migração interrompida. Corrija o erro acima e rode novamente.\n");
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

main();
