import { Router, Request, Response } from 'express';

// ─── Router de Fichas de Visita — Casa DF ────────────────────────────────────
// Agendamento de visitas a imóveis + geração de PDF da ficha de visita
// (reaproveita o layout timbrado já usado nos demais documentos do sistema).

function formatarMoeda(v: any): string {
  const n = Number(v);
  if (!Number.isFinite(n)) return '—';
  return n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

function formatarData(d: any): string {
  if (!d) return '—';
  const dt = new Date(d);
  if (Number.isNaN(dt.getTime())) return '—';
  return dt.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
}

export default function createVisitasRouter(
  pool: any,
  helpers: { auth?: any; gerarHtmlTimbrado: (body: string, titulo?: string) => string; gerarPdfDeHtml: (html: string) => Promise<Buffer> },
) {
  const router = Router();
  const { auth, gerarHtmlTimbrado, gerarPdfDeHtml } = helpers;
  if (auth) router.use(auth);

  // ── GET /api/imovel-visitas — lista com filtros ──────────────────────────
  router.get('/', async (req: Request, res: Response) => {
    try {
      const { imovel_id, status, page = '1', pageSize = '20' } = req.query as Record<string, string>;
      const where: string[] = [];
      const params: any[] = [];
      let i = 1;
      if (imovel_id) { where.push(`v.imovel_id = $${i++}`); params.push(imovel_id); }
      if (status) { where.push(`v.status = $${i++}`); params.push(status); }
      const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

      const limit = Math.min(Math.max(Number(pageSize) || 20, 1), 100);
      const offset = (Math.max(Number(page) || 1, 1) - 1) * limit;

      const totalQ = await pool.query(`SELECT COUNT(*)::int AS total FROM imovel_visitas v ${whereSql}`, params);
      const dataQ = await pool.query(
        `SELECT v.*, i.titulo AS imovel_titulo, i.codigo AS imovel_codigo, i.endereco AS imovel_endereco
         FROM imovel_visitas v
         JOIN imoveis i ON i.id = v.imovel_id
         ${whereSql}
         ORDER BY v.data_visita DESC
         LIMIT $${i} OFFSET $${i + 1}`,
        [...params, limit, offset],
      );
      res.json({ items: dataQ.rows, total: totalQ.rows[0].total, page: Number(page) || 1, pageSize: limit });
    } catch (err) {
      console.error('[GET /api/imovel-visitas]', err);
      res.status(500).json({ error: 'Erro ao listar visitas' });
    }
  });

  // ── POST /api/imovel-visitas — agenda/registra visita ────────────────────
  router.post('/', async (req: Request, res: Response) => {
    try {
      const b = req.body || {};
      if (!b.imovel_id || !b.visitante_nome) {
        res.status(400).json({ error: 'imovel_id e visitante_nome são obrigatórios' });
        return;
      }
      const criadoPor = (req as any).user?.id || null;
      const r = await pool.query(
        `INSERT INTO imovel_visitas (
           imovel_id, visitante_nome, visitante_telefone, visitante_email, visitante_cpf,
           corretor_id, corretor_nome, data_visita, origem_lead, interesse_nivel,
           observacoes, status, criado_por
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,COALESCE($8, NOW()),$9,$10,$11,COALESCE($12,'agendada'),$13)
         RETURNING *`,
        [
          b.imovel_id, b.visitante_nome, b.visitante_telefone || null, b.visitante_email || null, b.visitante_cpf || null,
          b.corretor_id || null, b.corretor_nome || null, b.data_visita || null, b.origem_lead || null, b.interesse_nivel || 'medio',
          b.observacoes || null, b.status || null, criadoPor,
        ],
      );
      res.status(201).json(r.rows[0]);
    } catch (err) {
      console.error('[POST /api/imovel-visitas]', err);
      res.status(500).json({ error: 'Erro ao registrar visita' });
    }
  });

  // ── PUT /api/imovel-visitas/:id — atualizar (feedback, status, etc.) ────
  router.put('/:id', async (req: Request, res: Response) => {
    try {
      const permitido = [
        'visitante_nome', 'visitante_telefone', 'visitante_email', 'visitante_cpf',
        'corretor_id', 'corretor_nome', 'data_visita', 'origem_lead', 'interesse_nivel',
        'observacoes', 'feedback_visitante', 'proximos_passos', 'status',
        'assinatura_visitante_nome', 'assinatura_corretor_nome',
      ];
      const dados: Record<string, any> = {};
      for (const campo of permitido) if (req.body?.[campo] !== undefined) dados[campo] = req.body[campo];
      const campos = Object.keys(dados);
      if (campos.length === 0) {
        res.status(400).json({ error: 'Nenhum campo para atualizar' });
        return;
      }
      const sets = campos.map((c, idx) => `${c} = $${idx + 2}`).join(', ');
      const r = await pool.query(
        `UPDATE imovel_visitas SET ${sets}, atualizado_em = NOW() WHERE id = $1 RETURNING *`,
        [req.params.id, ...Object.values(dados)],
      );
      if (r.rows.length === 0) {
        res.status(404).json({ error: 'Visita não encontrada' });
        return;
      }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[PUT /api/imovel-visitas/:id]', err);
      res.status(500).json({ error: 'Erro ao atualizar visita' });
    }
  });

  // ── GET /api/imovel-visitas/:id/pdf — gera a ficha de visita em PDF ──────
  router.get('/:id/pdf', async (req: Request, res: Response) => {
    try {
      const r = await pool.query(
        `SELECT v.*, i.titulo AS imovel_titulo, i.codigo AS imovel_codigo, i.endereco AS imovel_endereco,
                i.bairro AS imovel_bairro, i.cidade AS imovel_cidade, i.uf AS imovel_uf,
                i.valor_venda, i.valor_locacao, i.tipo AS imovel_tipo
         FROM imovel_visitas v JOIN imoveis i ON i.id = v.imovel_id WHERE v.id = $1`,
        [req.params.id],
      );
      if (r.rows.length === 0) {
        res.status(404).json({ error: 'Visita não encontrada' });
        return;
      }
      const v = r.rows[0];

      const body = `
        <h1 style="font-size:16pt;margin-bottom:4px;">Ficha de Visita a Imóvel</h1>
        <p style="color:#64748b;font-size:9pt;margin-bottom:18px;">Imóvel ${v.imovel_codigo || ''} — gerada em ${formatarData(new Date())}</p>

        <h2 style="font-size:11pt;border-bottom:1px solid #e2e8f0;padding-bottom:4px;">Dados do Imóvel</h2>
        <table style="width:100%;font-size:9.5pt;margin-bottom:16px;">
          <tr><td style="width:30%;padding:3px 0;color:#475569;">Código / Título</td><td>${v.imovel_codigo || ''} — ${v.imovel_titulo || ''}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">Endereço</td><td>${v.imovel_endereco || ''} — ${v.imovel_bairro || ''}, ${v.imovel_cidade || ''}/${v.imovel_uf || ''}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">Valor</td><td>${v.valor_venda ? 'Venda: ' + formatarMoeda(v.valor_venda) : ''} ${v.valor_locacao ? ' Locação: ' + formatarMoeda(v.valor_locacao) : ''}</td></tr>
        </table>

        <h2 style="font-size:11pt;border-bottom:1px solid #e2e8f0;padding-bottom:4px;">Dados do Visitante</h2>
        <table style="width:100%;font-size:9.5pt;margin-bottom:16px;">
          <tr><td style="width:30%;padding:3px 0;color:#475569;">Nome</td><td>${v.visitante_nome || ''}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">Telefone</td><td>${v.visitante_telefone || '—'}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">E-mail</td><td>${v.visitante_email || '—'}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">CPF</td><td>${v.visitante_cpf || '—'}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">Data/hora da visita</td><td>${formatarData(v.data_visita)}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">Corretor(a) responsável</td><td>${v.corretor_nome || '—'}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">Origem do contato</td><td>${v.origem_lead || '—'}</td></tr>
          <tr><td style="padding:3px 0;color:#475569;">Nível de interesse</td><td>${(v.interesse_nivel || 'medio').toUpperCase()}</td></tr>
        </table>

        <h2 style="font-size:11pt;border-bottom:1px solid #e2e8f0;padding-bottom:4px;">Observações e Feedback</h2>
        <p style="font-size:9.5pt;white-space:pre-wrap;min-height:40px;">${v.observacoes || v.feedback_visitante || '—'}</p>
        <p style="font-size:9.5pt;white-space:pre-wrap;">${v.proximos_passos ? '<strong>Próximos passos:</strong> ' + v.proximos_passos : ''}</p>

        <div style="display:flex;justify-content:space-between;margin-top:60px;">
          <div style="width:45%;text-align:center;">
            <div style="border-top:1px solid #1e293b;margin-bottom:6px;"></div>
            <p style="font-size:9pt;">${v.assinatura_visitante_nome || v.visitante_nome || 'Visitante'}</p>
          </div>
          <div style="width:45%;text-align:center;">
            <div style="border-top:1px solid #1e293b;margin-bottom:6px;"></div>
            <p style="font-size:9pt;">${v.assinatura_corretor_nome || v.corretor_nome || 'Corretor(a)'}</p>
          </div>
        </div>
      `;

      const html = gerarHtmlTimbrado(body, 'Ficha de Visita');
      const pdfBuffer = await gerarPdfDeHtml(html);

      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `inline; filename="ficha-visita-${v.imovel_codigo || v.id}.pdf"`);
      res.send(pdfBuffer);
    } catch (err) {
      console.error('[GET /api/imovel-visitas/:id/pdf]', err);
      res.status(500).json({ error: 'Erro ao gerar PDF da ficha de visita' });
    }
  });

  return router;
}
