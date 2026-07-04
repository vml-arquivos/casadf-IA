import { Router, Request, Response } from 'express';
import multer from 'multer';
import fs from 'fs';
import path from 'path';

// ─── Router de Imóveis — Casa DF Gestão Imobiliária ─────────────────────────
// Público: vitrine (listagem com filtros) e página individual do imóvel.
// Admin (autenticado): CRUD completo, upload de fotos, fichas de visita.
//
// Segue o mesmo padrão dos demais routers do projeto: função-fábrica que
// recebe o pool de conexão e retorna um Router configurado.

function slugify(text: string): string {
  return String(text || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 180);
}

async function gerarSlugUnico(pool: any, titulo: string, cidade?: string): Promise<string> {
  const base = slugify(`${titulo}-${cidade || ''}`) || `imovel-${Date.now()}`;
  let slug = base;
  let tentativa = 1;
  while (true) {
    const { rows } = await pool.query('SELECT 1 FROM imoveis WHERE slug = $1', [slug]);
    if (rows.length === 0) return slug;
    tentativa += 1;
    slug = `${base}-${tentativa}`;
  }
}

async function gerarCodigo(pool: any): Promise<string> {
  const { rows } = await pool.query("SELECT nextval('imoveis_codigo_seq') AS n");
  const n = Number(rows[0].n);
  return `CDF-${String(n).padStart(4, '0')}`;
}

const CAMPOS_IMOVEL = [
  'titulo', 'descricao', 'tipo', 'finalidade', 'status',
  'valor_venda', 'valor_locacao', 'valor_condominio', 'valor_iptu',
  'aceita_permuta', 'aceita_financiamento',
  'endereco', 'numero', 'complemento', 'bairro', 'cidade', 'uf', 'cep', 'latitude', 'longitude',
  'area_privativa', 'area_total', 'quartos', 'suites', 'banheiros', 'vagas_garagem',
  'andar', 'ano_construcao', 'mobiliado', 'comodidades',
  'proprietario_nome', 'proprietario_telefone', 'proprietario_email', 'proprietario_cpf_cnpj',
  'matricula_imovel', 'observacoes_internas',
  'destaque', 'meta_titulo', 'meta_descricao', 'responsavel_id',
  'imobiliaria_id', 'corretor_id', 'video_url', 'tour_virtual_url',
];

function somenteCamposValidos(body: Record<string, any>): Record<string, any> {
  const out: Record<string, any> = {};
  for (const campo of CAMPOS_IMOVEL) {
    if (body[campo] !== undefined) out[campo] = body[campo];
  }
  return out;
}

export default function createImoveisRouter(pool: any, opts?: { auth?: any }) {
  const router = Router();
  const auth = opts?.auth;

  const uploadFotos = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 15 * 1024 * 1024 },
    fileFilter: (_req: any, file: any, cb: any) => {
      const allowed = ['image/jpeg', 'image/png', 'image/webp'];
      if (allowed.includes(file.mimetype)) cb(null, true);
      else cb(new Error(`Tipo de arquivo não permitido: ${file.mimetype}`));
    },
  });

  // ── PÚBLICO: GET /api/imoveis — vitrine com filtros e paginação ──────────
  router.get('/', async (req: Request, res: Response) => {
    try {
      const {
        finalidade, tipo, bairro, cidade,
        preco_min, preco_max, quartos_min, vagas_min,
        destaque, busca,
        page = '1', pageSize = '12',
        admin,
      } = req.query as Record<string, string>;

      const where: string[] = [];
      const params: any[] = [];
      let i = 1;

      // Vitrine pública só mostra disponíveis; painel admin (?admin=1) vê tudo
      if (admin !== '1') {
        where.push(`status = 'disponivel'`);
      } else if (req.query.status) {
        where.push(`status = $${i++}`);
        params.push(req.query.status);
      }

      if (finalidade) { where.push(`finalidade = $${i++}`); params.push(finalidade); }
      if (tipo) { where.push(`tipo = $${i++}`); params.push(tipo); }
      if (bairro) { where.push(`bairro ILIKE $${i++}`); params.push(`%${bairro}%`); }
      if (cidade) { where.push(`cidade ILIKE $${i++}`); params.push(`%${cidade}%`); }
      if (preco_min) { where.push(`COALESCE(valor_venda, valor_locacao) >= $${i++}`); params.push(Number(preco_min)); }
      if (preco_max) { where.push(`COALESCE(valor_venda, valor_locacao) <= $${i++}`); params.push(Number(preco_max)); }
      if (quartos_min) { where.push(`quartos >= $${i++}`); params.push(Number(quartos_min)); }
      if (vagas_min) { where.push(`vagas_garagem >= $${i++}`); params.push(Number(vagas_min)); }
      if (destaque === '1') { where.push(`destaque = TRUE`); }
      if (busca) {
        where.push(`(titulo ILIKE $${i} OR descricao ILIKE $${i} OR bairro ILIKE $${i} OR codigo ILIKE $${i})`);
        params.push(`%${busca}%`);
        i++;
      }

      const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
      const limit = Math.min(Math.max(Number(pageSize) || 12, 1), 60);
      const offset = (Math.max(Number(page) || 1, 1) - 1) * limit;

      const totalQ = await pool.query(`SELECT COUNT(*)::int AS total FROM imoveis ${whereSql}`, params);
      const dataQ = await pool.query(
        `SELECT id, codigo, slug, titulo, tipo, finalidade, status,
                valor_venda, valor_locacao, valor_condominio,
                bairro, cidade, uf, area_privativa, quartos, suites, banheiros, vagas_garagem,
                destaque, foto_capa_url, criado_em
         FROM imoveis ${whereSql}
         ORDER BY destaque DESC, criado_em DESC
         LIMIT $${i} OFFSET $${i + 1}`,
        [...params, limit, offset],
      );

      res.json({
        items: dataQ.rows,
        total: totalQ.rows[0].total,
        page: Number(page) || 1,
        pageSize: limit,
        totalPages: Math.max(Math.ceil(totalQ.rows[0].total / limit), 1),
      });
    } catch (err) {
      console.error('[GET /api/imoveis]', err);
      res.status(500).json({ error: 'Erro ao listar imóveis' });
    }
  });

  // ── PÚBLICO: GET /api/imoveis/filtros/opcoes — opções dinâmicas de filtro ──
  router.get('/filtros/opcoes', async (_req: Request, res: Response) => {
    try {
      const bairrosQ = await pool.query(
        `SELECT DISTINCT bairro FROM imoveis WHERE status = 'disponivel' AND bairro IS NOT NULL AND bairro <> '' ORDER BY bairro ASC`,
      );
      const cidadesQ = await pool.query(
        `SELECT DISTINCT cidade FROM imoveis WHERE status = 'disponivel' AND cidade IS NOT NULL AND cidade <> '' ORDER BY cidade ASC`,
      );
      const precoQ = await pool.query(
        `SELECT MIN(COALESCE(valor_venda, valor_locacao)) AS min, MAX(COALESCE(valor_venda, valor_locacao)) AS max
         FROM imoveis WHERE status = 'disponivel'`,
      );
      res.json({
        bairros: bairrosQ.rows.map((r: any) => r.bairro),
        cidades: cidadesQ.rows.map((r: any) => r.cidade),
        precoMin: Number(precoQ.rows[0]?.min) || 0,
        precoMax: Number(precoQ.rows[0]?.max) || 0,
      });
    } catch (err) {
      console.error('[GET /api/imoveis/filtros/opcoes]', err);
      res.status(500).json({ error: 'Erro ao buscar opções de filtro' });
    }
  });

  // ── PÚBLICO: GET /api/imoveis/:idOrSlug — detalhe (aceita UUID ou slug) ──
  router.get('/:idOrSlug', async (req: Request, res: Response) => {
    try {
      const { idOrSlug } = req.params;
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug);

      const imovelQ = await pool.query(
        `SELECT * FROM imoveis WHERE ${isUuid ? 'id' : 'slug'} = $1`,
        [idOrSlug],
      );
      if (imovelQ.rows.length === 0) {
        res.status(404).json({ error: 'Imóvel não encontrado' });
        return;
      }
      const imovel = imovelQ.rows[0];

      const fotosQ = await pool.query(
        'SELECT id, url, legenda, ordem, capa FROM imovel_fotos WHERE imovel_id = $1 ORDER BY ordem ASC, criado_em ASC',
        [imovel.id],
      );

      // Contabiliza visualização apenas em acesso público (sem admin=1)
      if (req.query.admin !== '1') {
        pool.query('UPDATE imoveis SET visualizacoes = visualizacoes + 1 WHERE id = $1', [imovel.id]).catch(() => {});
      }

      res.json({ ...imovel, fotos: fotosQ.rows });
    } catch (err) {
      console.error('[GET /api/imoveis/:idOrSlug]', err);
      res.status(500).json({ error: 'Erro ao buscar imóvel' });
    }
  });

  // A partir daqui, todas as rotas exigem autenticação (CRM/admin)
  if (auth) router.use(auth);

  // ── ADMIN: POST /api/imoveis — cadastrar imóvel ──────────────────────────
  router.post('/', async (req: Request, res: Response) => {
    try {
      const dados = somenteCamposValidos(req.body || {});
      if (!dados.titulo) {
        res.status(400).json({ error: 'Título é obrigatório' });
        return;
      }

      const codigo = await gerarCodigo(pool);
      const slug = await gerarSlugUnico(pool, dados.titulo, dados.cidade);
      const criadoPor = (req as any).user?.id || null;

      const campos = Object.keys(dados);
      const valores = Object.values(dados);
      const placeholders = campos.map((_, idx) => `$${idx + 4}`).join(', ');

      const r = await pool.query(
        `INSERT INTO imoveis (codigo, slug, criado_por, ${campos.join(', ')})
         VALUES ($1, $2, $3, ${placeholders})
         RETURNING *`,
        [codigo, slug, criadoPor, ...valores],
      );
      res.status(201).json(r.rows[0]);
    } catch (err) {
      console.error('[POST /api/imoveis]', err);
      res.status(500).json({ error: 'Erro ao cadastrar imóvel' });
    }
  });

  // ── ADMIN: PUT /api/imoveis/:id — atualizar imóvel ───────────────────────
  router.put('/:id', async (req: Request, res: Response) => {
    try {
      const dados = somenteCamposValidos(req.body || {});
      const campos = Object.keys(dados);
      if (campos.length === 0) {
        res.status(400).json({ error: 'Nenhum campo para atualizar' });
        return;
      }
      const sets = campos.map((c, idx) => `${c} = $${idx + 2}`).join(', ');
      const valores = Object.values(dados);

      const r = await pool.query(
        `UPDATE imoveis SET ${sets}, atualizado_em = NOW() WHERE id = $1 RETURNING *`,
        [req.params.id, ...valores],
      );
      if (r.rows.length === 0) {
        res.status(404).json({ error: 'Imóvel não encontrado' });
        return;
      }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[PUT /api/imoveis/:id]', err);
      res.status(500).json({ error: 'Erro ao atualizar imóvel' });
    }
  });

  // ── ADMIN: DELETE /api/imoveis/:id ────────────────────────────────────────
  router.delete('/:id', async (req: Request, res: Response) => {
    try {
      const r = await pool.query('DELETE FROM imoveis WHERE id = $1 RETURNING id', [req.params.id]);
      if (r.rows.length === 0) {
        res.status(404).json({ error: 'Imóvel não encontrado' });
        return;
      }
      res.json({ ok: true });
    } catch (err) {
      console.error('[DELETE /api/imoveis/:id]', err);
      res.status(500).json({ error: 'Erro ao excluir imóvel' });
    }
  });

  // ── ADMIN: POST /api/imoveis/:id/fotos — upload de fotos ────────────────
  router.post('/:id/fotos', uploadFotos.array('fotos', 20), async (req: Request, res: Response) => {
    try {
      const files = (req.files as any[]) || [];
      if (files.length === 0) {
        res.status(400).json({ error: 'Nenhuma foto enviada' });
        return;
      }

      const dataDir = process.env.DATA_DIR || '/data';
      const uploadDir = path.join(dataDir, 'uploads', 'imoveis', req.params.id);
      await fs.promises.mkdir(uploadDir, { recursive: true });

      const { rows: existentes } = await pool.query(
        'SELECT COALESCE(MAX(ordem), -1) AS max_ordem FROM imovel_fotos WHERE imovel_id = $1',
        [req.params.id],
      );
      let ordem = Number(existentes[0].max_ordem) + 1;

      const inseridas: any[] = [];
      for (const file of files) {
        const ext = path.extname(file.originalname || '.jpg') || '.jpg';
        const nomeArq = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}${ext}`;
        await fs.promises.writeFile(path.join(uploadDir, nomeArq), file.buffer);
        const url = `/uploads/imoveis/${req.params.id}/${nomeArq}`;

        const r = await pool.query(
          `INSERT INTO imovel_fotos (imovel_id, url, ordem, capa) VALUES ($1,$2,$3,$4) RETURNING *`,
          [req.params.id, url, ordem, ordem === 0],
        );
        inseridas.push(r.rows[0]);
        ordem += 1;
      }

      // Se ainda não houver foto de capa definida no imóvel, define a primeira enviada
      await pool.query(
        `UPDATE imoveis SET foto_capa_url = COALESCE(foto_capa_url, $2) WHERE id = $1`,
        [req.params.id, inseridas[0].url],
      );

      res.status(201).json(inseridas);
    } catch (err) {
      console.error('[POST /api/imoveis/:id/fotos]', err);
      res.status(500).json({ error: 'Erro ao enviar fotos' });
    }
  });

  // ── ADMIN: DELETE /api/imoveis/:id/fotos/:fotoId ─────────────────────────
  router.delete('/:id/fotos/:fotoId', async (req: Request, res: Response) => {
    try {
      await pool.query('DELETE FROM imovel_fotos WHERE id = $1 AND imovel_id = $2', [req.params.fotoId, req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error('[DELETE /api/imoveis/:id/fotos/:fotoId]', err);
      res.status(500).json({ error: 'Erro ao excluir foto' });
    }
  });

  // ── ADMIN: PUT /api/imoveis/:id/fotos/:fotoId/capa — definir capa ───────
  router.put('/:id/fotos/:fotoId/capa', async (req: Request, res: Response) => {
    try {
      await pool.query('UPDATE imovel_fotos SET capa = FALSE WHERE imovel_id = $1', [req.params.id]);
      const r = await pool.query(
        'UPDATE imovel_fotos SET capa = TRUE WHERE id = $1 AND imovel_id = $2 RETURNING url',
        [req.params.fotoId, req.params.id],
      );
      if (r.rows.length) {
        await pool.query('UPDATE imoveis SET foto_capa_url = $2 WHERE id = $1', [req.params.id, r.rows[0].url]);
      }
      res.json({ ok: true });
    } catch (err) {
      console.error('[PUT /api/imoveis/:id/fotos/:fotoId/capa]', err);
      res.status(500).json({ error: 'Erro ao definir capa' });
    }
  });

  return router;
}
