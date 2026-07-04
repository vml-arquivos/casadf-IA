import { Router, Request, Response } from 'express';
import multer from 'multer';
import fs from 'fs';
import path from 'path';

// ─── Router de Imobiliárias — Configurações (Casa DF) ───────────────────────
// Cadastro de imobiliárias parceiras/futuras: logo, dados de contato e texto
// de rodapé. Hoje o sistema opera com uma única imobiliária (Casa DF) nos
// documentos gerados, mas a estrutura já suporta múltiplas.

export default function createImobiliariasRouter(pool: any, opts?: { auth?: any }) {
  const router = Router();
  if (opts?.auth) router.use(opts.auth);

  const uploadLogo = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (_req: any, file: any, cb: any) => {
      const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'];
      if (allowed.includes(file.mimetype)) cb(null, true);
      else cb(new Error(`Tipo de arquivo não permitido: ${file.mimetype}`));
    },
  });

  const CAMPOS = [
    'nome', 'cnpj', 'creci_juridico', 'endereco', 'cidade', 'uf', 'telefone',
    'whatsapp', 'email', 'site_url', 'instagram_url', 'cor_primaria', 'rodape_texto', 'ativa',
  ];

  function somenteValidos(body: Record<string, any>) {
    const out: Record<string, any> = {};
    for (const c of CAMPOS) if (body[c] !== undefined) out[c] = body[c];
    return out;
  }

  router.get('/', async (_req: Request, res: Response) => {
    try {
      const r = await pool.query('SELECT * FROM imobiliarias ORDER BY padrao DESC, nome ASC');
      res.json(r.rows);
    } catch (err) {
      console.error('[GET /api/imobiliarias]', err);
      res.status(500).json({ error: 'Erro ao listar imobiliárias' });
    }
  });

  router.post('/', async (req: Request, res: Response) => {
    try {
      const dados = somenteValidos(req.body || {});
      if (!dados.nome) { res.status(400).json({ error: 'Nome é obrigatório' }); return; }
      const campos = Object.keys(dados);
      const placeholders = campos.map((_, i) => `$${i + 1}`).join(', ');
      const r = await pool.query(
        `INSERT INTO imobiliarias (${campos.join(', ')}) VALUES (${placeholders}) RETURNING *`,
        Object.values(dados),
      );
      res.status(201).json(r.rows[0]);
    } catch (err) {
      console.error('[POST /api/imobiliarias]', err);
      res.status(500).json({ error: 'Erro ao cadastrar imobiliária' });
    }
  });

  router.put('/:id', async (req: Request, res: Response) => {
    try {
      const dados = somenteValidos(req.body || {});
      const campos = Object.keys(dados);
      if (campos.length === 0) { res.status(400).json({ error: 'Nenhum campo para atualizar' }); return; }
      const sets = campos.map((c, i) => `${c} = $${i + 2}`).join(', ');
      const r = await pool.query(
        `UPDATE imobiliarias SET ${sets}, atualizado_em = NOW() WHERE id = $1 RETURNING *`,
        [req.params.id, ...Object.values(dados)],
      );
      if (r.rows.length === 0) { res.status(404).json({ error: 'Imobiliária não encontrada' }); return; }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[PUT /api/imobiliarias/:id]', err);
      res.status(500).json({ error: 'Erro ao atualizar imobiliária' });
    }
  });

  // ── Define a imobiliária padrão (usada como referência principal) ────────
  router.put('/:id/padrao', async (req: Request, res: Response) => {
    try {
      await pool.query('UPDATE imobiliarias SET padrao = FALSE');
      const r = await pool.query('UPDATE imobiliarias SET padrao = TRUE WHERE id = $1 RETURNING *', [req.params.id]);
      if (r.rows.length === 0) { res.status(404).json({ error: 'Imobiliária não encontrada' }); return; }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[PUT /api/imobiliarias/:id/padrao]', err);
      res.status(500).json({ error: 'Erro ao definir imobiliária padrão' });
    }
  });

  router.delete('/:id', async (req: Request, res: Response) => {
    try {
      const r = await pool.query('DELETE FROM imobiliarias WHERE id = $1 AND padrao = FALSE RETURNING id', [req.params.id]);
      if (r.rows.length === 0) {
        res.status(400).json({ error: 'Não é possível excluir a imobiliária padrão ou ela não existe.' });
        return;
      }
      res.json({ ok: true });
    } catch (err) {
      console.error('[DELETE /api/imobiliarias/:id]', err);
      res.status(500).json({ error: 'Erro ao excluir imobiliária' });
    }
  });

  // ── Upload de logo ────────────────────────────────────────────────────────
  router.post('/:id/logo', uploadLogo.single('logo'), async (req: Request, res: Response) => {
    try {
      const file = req.file as any;
      if (!file) { res.status(400).json({ error: 'Nenhum arquivo enviado' }); return; }

      const dataDir = process.env.DATA_DIR || '/data';
      const uploadDir = path.join(dataDir, 'uploads', 'imobiliarias');
      await fs.promises.mkdir(uploadDir, { recursive: true });

      const ext = path.extname(file.originalname || '.png') || '.png';
      const nomeArq = `${req.params.id}_${Date.now()}${ext}`;
      await fs.promises.writeFile(path.join(uploadDir, nomeArq), file.buffer);
      const url = `/uploads/imobiliarias/${nomeArq}`;

      const r = await pool.query(
        'UPDATE imobiliarias SET logo_url = $2, atualizado_em = NOW() WHERE id = $1 RETURNING *',
        [req.params.id, url],
      );
      if (r.rows.length === 0) { res.status(404).json({ error: 'Imobiliária não encontrada' }); return; }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[POST /api/imobiliarias/:id/logo]', err);
      res.status(500).json({ error: 'Erro ao enviar logo' });
    }
  });

  return router;
}
