import { Router, Request, Response } from 'express';
import multer from 'multer';
import fs from 'fs';
import path from 'path';

// ─── Router de Corretores — Configurações (Casa DF) ─────────────────────────

export default function createCorretoresRouter(pool: any, opts?: { auth?: any }) {
  const router = Router();
  if (opts?.auth) router.use(opts.auth);

  const uploadFoto = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (_req: any, file: any, cb: any) => {
      const allowed = ['image/jpeg', 'image/png', 'image/webp'];
      if (allowed.includes(file.mimetype)) cb(null, true);
      else cb(new Error(`Tipo de arquivo não permitido: ${file.mimetype}`));
    },
  });

  const CAMPOS = ['imobiliaria_id', 'usuario_id', 'nome', 'creci', 'telefone', 'whatsapp', 'email', 'ativo'];

  function somenteValidos(body: Record<string, any>) {
    const out: Record<string, any> = {};
    for (const c of CAMPOS) if (body[c] !== undefined) out[c] = body[c];
    return out;
  }

  router.get('/', async (req: Request, res: Response) => {
    try {
      const { imobiliaria_id } = req.query as Record<string, string>;
      const where = imobiliaria_id ? 'WHERE c.imobiliaria_id = $1' : '';
      const params = imobiliaria_id ? [imobiliaria_id] : [];
      const r = await pool.query(
        `SELECT c.*, i.nome AS imobiliaria_nome FROM corretores c
         LEFT JOIN imobiliarias i ON i.id = c.imobiliaria_id ${where} ORDER BY c.nome ASC`,
        params,
      );
      res.json(r.rows);
    } catch (err) {
      console.error('[GET /api/corretores]', err);
      res.status(500).json({ error: 'Erro ao listar corretores' });
    }
  });

  router.post('/', async (req: Request, res: Response) => {
    try {
      const dados = somenteValidos(req.body || {});
      if (!dados.nome) { res.status(400).json({ error: 'Nome é obrigatório' }); return; }
      const campos = Object.keys(dados);
      const placeholders = campos.map((_, i) => `$${i + 1}`).join(', ');
      const r = await pool.query(
        `INSERT INTO corretores (${campos.join(', ')}) VALUES (${placeholders}) RETURNING *`,
        Object.values(dados),
      );
      res.status(201).json(r.rows[0]);
    } catch (err) {
      console.error('[POST /api/corretores]', err);
      res.status(500).json({ error: 'Erro ao cadastrar corretor(a)' });
    }
  });

  router.put('/:id', async (req: Request, res: Response) => {
    try {
      const dados = somenteValidos(req.body || {});
      const campos = Object.keys(dados);
      if (campos.length === 0) { res.status(400).json({ error: 'Nenhum campo para atualizar' }); return; }
      const sets = campos.map((c, i) => `${c} = $${i + 2}`).join(', ');
      const r = await pool.query(
        `UPDATE corretores SET ${sets}, atualizado_em = NOW() WHERE id = $1 RETURNING *`,
        [req.params.id, ...Object.values(dados)],
      );
      if (r.rows.length === 0) { res.status(404).json({ error: 'Corretor(a) não encontrado(a)' }); return; }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[PUT /api/corretores/:id]', err);
      res.status(500).json({ error: 'Erro ao atualizar corretor(a)' });
    }
  });

  router.delete('/:id', async (req: Request, res: Response) => {
    try {
      await pool.query('DELETE FROM corretores WHERE id = $1', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error('[DELETE /api/corretores/:id]', err);
      res.status(500).json({ error: 'Erro ao excluir corretor(a)' });
    }
  });

  router.post('/:id/foto', uploadFoto.single('foto'), async (req: Request, res: Response) => {
    try {
      const file = req.file as any;
      if (!file) { res.status(400).json({ error: 'Nenhum arquivo enviado' }); return; }
      const dataDir = process.env.DATA_DIR || '/data';
      const uploadDir = path.join(dataDir, 'uploads', 'corretores');
      await fs.promises.mkdir(uploadDir, { recursive: true });
      const ext = path.extname(file.originalname || '.jpg') || '.jpg';
      const nomeArq = `${req.params.id}_${Date.now()}${ext}`;
      await fs.promises.writeFile(path.join(uploadDir, nomeArq), file.buffer);
      const url = `/uploads/corretores/${nomeArq}`;
      const r = await pool.query(
        'UPDATE corretores SET foto_url = $2, atualizado_em = NOW() WHERE id = $1 RETURNING *',
        [req.params.id, url],
      );
      if (r.rows.length === 0) { res.status(404).json({ error: 'Corretor(a) não encontrado(a)' }); return; }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[POST /api/corretores/:id/foto]', err);
      res.status(500).json({ error: 'Erro ao enviar foto' });
    }
  });

  return router;
}
