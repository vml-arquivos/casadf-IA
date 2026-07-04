import { Router, Request, Response } from 'express';

// ─── Router de Contratos Imobiliários — Casa DF ─────────────────────────────
// Gera e gerencia contratos de: Compra e Venda, Prestação de Serviço (corretagem)
// e Cessão de Direitos. Reaproveita o layout timbrado padrão do sistema.
//
// IMPORTANTE: as minutas abaixo são modelos de referência para agilizar o
// trabalho da equipe — todo contrato antes de assinado deve passar por
// revisão jurídica, especialmente cláusulas de multa, foro e condições
// suspensivas específicas de cada negociação.

function formatarMoeda(v: any): string {
  const n = Number(v);
  if (!Number.isFinite(n)) return '—';
  return n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

function formatarDataExtenso(d: any): string {
  const dt = d ? new Date(d) : new Date();
  if (Number.isNaN(dt.getTime())) return '—';
  return dt.toLocaleDateString('pt-BR', { day: '2-digit', month: 'long', year: 'numeric' });
}

async function gerarNumeroContrato(pool: any, tipo: string): Promise<string> {
  const prefixos: Record<string, string> = {
    compra_venda: 'CV',
    promessa_compra_venda: 'PCV',
    prestacao_servico: 'PS',
    assessoria_venda_exclusiva: 'AVE',
    assessoria_venda_sem_exclusiva: 'AVS',
    avaliacao_imovel: 'AV',
    aluguel: 'AL',
    cessao_direitos: 'CD',
  };
  const prefixo = prefixos[tipo] || 'CT';
  const { rows } = await pool.query("SELECT nextval('contratos_imobiliarios_numero_seq') AS n");
  const ano = new Date().getFullYear();
  return `${prefixo}-${ano}-${String(Number(rows[0].n)).padStart(4, '0')}`;
}

const CAMPOS_CONTRATO = [
  'tipo', 'status', 'imovel_id', 'imobiliaria_id', 'corretor_id',
  'parte1_nome', 'parte1_cpf_cnpj', 'parte1_endereco', 'parte1_email', 'parte1_telefone', 'parte1_estado_civil',
  'parte2_nome', 'parte2_cpf_cnpj', 'parte2_endereco', 'parte2_email', 'parte2_telefone', 'parte2_estado_civil',
  'valor_total', 'valor_entrada', 'forma_pagamento', 'numero_parcelas', 'valor_parcela', 'vencimento_dia',
  'percentual_comissao', 'objeto_descricao', 'clausulas_extra', 'data_assinatura', 'cidade_foro',
  'testemunha_1_nome', 'testemunha_1_cpf', 'testemunha_2_nome', 'testemunha_2_cpf',
  'prazo_vigencia_meses', 'garantia_locaticia', 'valor_caucao', 'indice_reajuste',
  'metodologia_avaliacao', 'valor_avaliacao',
];

function somenteCamposValidos(body: Record<string, any>): Record<string, any> {
  const out: Record<string, any> = {};
  for (const campo of CAMPOS_CONTRATO) if (body[campo] !== undefined) out[campo] = body[campo];
  return out;
}

function blocoTestemunhas(c: any): string {
  return `
    <div style="display:flex;justify-content:space-between;margin-top:50px;">
      <div style="width:45%;text-align:center;">
        <div style="border-top:1px solid #1e293b;margin-bottom:6px;"></div>
        <p style="font-size:8.5pt;">${c.testemunha_1_nome || 'Testemunha 1'}${c.testemunha_1_cpf ? ' — CPF ' + c.testemunha_1_cpf : ''}</p>
      </div>
      <div style="width:45%;text-align:center;">
        <div style="border-top:1px solid #1e293b;margin-bottom:6px;"></div>
        <p style="font-size:8.5pt;">${c.testemunha_2_nome || 'Testemunha 2'}${c.testemunha_2_cpf ? ' — CPF ' + c.testemunha_2_cpf : ''}</p>
      </div>
    </div>`;
}

function blocoAssinaturas(c: any, rotulo1: string, rotulo2: string): string {
  return `
    <div style="display:flex;justify-content:space-between;margin-top:40px;">
      <div style="width:45%;text-align:center;">
        <div style="border-top:1px solid #1e293b;margin-bottom:6px;"></div>
        <p style="font-size:9pt;font-weight:600;">${c.parte1_nome}</p>
        <p style="font-size:8pt;color:#64748b;">${rotulo1}</p>
      </div>
      <div style="width:45%;text-align:center;">
        <div style="border-top:1px solid #1e293b;margin-bottom:6px;"></div>
        <p style="font-size:9pt;font-weight:600;">${c.parte2_nome}</p>
        <p style="font-size:8pt;color:#64748b;">${rotulo2}</p>
      </div>
    </div>`;
}

function montarCorpoImovel(imovel: any): string {
  if (!imovel) return '';
  return `imóvel situado em ${imovel.endereco || ''}${imovel.numero ? ', nº ' + imovel.numero : ''}${imovel.complemento ? ', ' + imovel.complemento : ''}, bairro ${imovel.bairro || ''}, ${imovel.cidade || ''}/${imovel.uf || ''}, CEP ${imovel.cep || ''}${imovel.matricula_imovel ? ', matrícula nº ' + imovel.matricula_imovel : ''}`;
}

function gerarCorpoCompraVenda(c: any, imovel: any): string {
  const objeto = imovel ? montarCorpoImovel(imovel) : (c.objeto_descricao || '[objeto do imóvel]');
  return `
    <h1 style="font-size:14pt;text-align:center;margin-bottom:4px;">CONTRATO PARTICULAR DE COMPRA E VENDA DE IMÓVEL</h1>
    <p style="text-align:center;color:#64748b;font-size:9pt;margin-bottom:20px;">Contrato nº ${c.numero}</p>

    <p style="font-size:9.5pt;text-align:justify;margin-bottom:10px;">
      <strong>VENDEDOR(A):</strong> ${c.parte1_nome}, ${c.parte1_estado_civil || ''}, portador(a) do CPF/CNPJ nº ${c.parte1_cpf_cnpj || '________'},
      residente e domiciliado(a) em ${c.parte1_endereco || '________'}.
    </p>
    <p style="font-size:9.5pt;text-align:justify;margin-bottom:16px;">
      <strong>COMPRADOR(A):</strong> ${c.parte2_nome}, ${c.parte2_estado_civil || ''}, portador(a) do CPF/CNPJ nº ${c.parte2_cpf_cnpj || '________'},
      residente e domiciliado(a) em ${c.parte2_endereco || '________'}.
    </p>

    <p style="font-size:9.5pt;text-align:justify;margin-bottom:12px;">
      As partes acima qualificadas têm entre si justo e acertado o presente Contrato de Compra e Venda,
      que se regerá pelas cláusulas seguintes:
    </p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 1ª — DO OBJETO.</strong> É objeto do presente contrato o ${objeto}.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 2ª — DO PREÇO E FORMA DE PAGAMENTO.</strong>
      O valor total da presente compra e venda é de ${formatarMoeda(c.valor_total)},
      ${c.valor_entrada ? `sendo ${formatarMoeda(c.valor_entrada)} pagos a título de entrada/sinal, ` : ''}
      ${c.numero_parcelas ? `e o saldo remanescente em ${c.numero_parcelas} parcela(s) de ${formatarMoeda(c.valor_parcela)}, com vencimento todo dia ${c.vencimento_dia || '__'} de cada mês, ` : ''}
      por meio de ${c.forma_pagamento || 'forma a ser acordada entre as partes'}.
    </p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 3ª — DA TRADIÇÃO E POSSE.</strong> A posse do imóvel será transmitida ao COMPRADOR(A)
      após a quitação integral do preço ajustado e cumprimento das obrigações aqui pactuadas, mediante entrega das chaves.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 4ª — DA ESCRITURA DEFINITIVA.</strong> Quitado o preço, as partes se obrigam a outorgar a
      escritura pública definitiva de compra e venda, correndo as despesas de escritura e registro por conta do(a) COMPRADOR(A), salvo disposição em contrário.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 5ª — DA MULTA E RESCISÃO.</strong> O descumprimento de qualquer cláusula deste contrato por
      qualquer das partes sujeitará o infrator ao pagamento de multa equivalente a 10% (dez por cento) do valor total do
      contrato, sem prejuízo de eventuais perdas e danos apurados.</p>

    ${c.clausulas_extra ? `<p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA(S) ADICIONAL(IS).</strong> ${c.clausulas_extra}</p>` : ''}

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 6ª — DO FORO.</strong> Fica eleito o foro da comarca de ${c.cidade_foro || 'Brasília'} para dirimir
      quaisquer dúvidas oriundas do presente contrato.</p>

    <p style="font-size:9.5pt;margin-top:20px;">${c.cidade_foro || 'Brasília'}, ${formatarDataExtenso(c.data_assinatura)}.</p>

    ${blocoAssinaturas(c, 'VENDEDOR(A)', 'COMPRADOR(A)')}
    ${blocoTestemunhas(c)}
  `;
}

function gerarCorpoPrestacaoServico(c: any, imovel: any): string {
  const objeto = imovel ? montarCorpoImovel(imovel) : (c.objeto_descricao || '[descrição do serviço/imóvel]');
  return `
    <h1 style="font-size:14pt;text-align:center;margin-bottom:4px;">CONTRATO DE PRESTAÇÃO DE SERVIÇOS DE CORRETAGEM IMOBILIÁRIA</h1>
    <p style="text-align:center;color:#64748b;font-size:9pt;margin-bottom:20px;">Contrato nº ${c.numero}</p>

    <p style="font-size:9.5pt;text-align:justify;margin-bottom:10px;">
      <strong>CONTRATANTE:</strong> ${c.parte1_nome}, CPF/CNPJ nº ${c.parte1_cpf_cnpj || '________'}, com endereço em ${c.parte1_endereco || '________'}.
    </p>
    <p style="font-size:9.5pt;text-align:justify;margin-bottom:16px;">
      <strong>CONTRATADA(O):</strong> ${c.parte2_nome}, CPF/CNPJ nº ${c.parte2_cpf_cnpj || '________'}, com endereço em ${c.parte2_endereco || '________'}.
    </p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 1ª — DO OBJETO.</strong> A CONTRATADA prestará serviços de intermediação e corretagem
      imobiliária relativos ao ${objeto}, incluindo divulgação, prospecção de interessados, acompanhamento de visitas e
      auxílio na negociação até a efetiva conclusão do negócio.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 2ª — DA COMISSÃO.</strong> Pela prestação dos serviços, será devida à CONTRATADA
      comissão de corretagem equivalente a ${c.percentual_comissao ? c.percentual_comissao + '%' : '[percentual]'} sobre o valor
      efetivamente negociado${c.valor_total ? `, estimado em ${formatarMoeda(c.valor_total)}` : ''}, a ser paga na
      efetivação do negócio (assinatura de contrato de compra e venda, locação ou cessão).</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 3ª — DAS OBRIGAÇÕES DA CONTRATADA.</strong> Atuar com diligência, zelo e boa-fé,
      fornecendo informações verídicas sobre o imóvel e mantendo o CONTRATANTE informado sobre o andamento das negociações.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 4ª — DA VIGÊNCIA.</strong> O presente contrato vigerá por prazo indeterminado, podendo
      ser rescindido por qualquer das partes mediante aviso prévio de 30 (trinta) dias, ressalvado o direito à comissão
      já devida por negócios em andamento.</p>

    ${c.clausulas_extra ? `<p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA(S) ADICIONAL(IS).</strong> ${c.clausulas_extra}</p>` : ''}

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 5ª — DO FORO.</strong> Fica eleito o foro da comarca de ${c.cidade_foro || 'Brasília'}.</p>

    <p style="font-size:9.5pt;margin-top:20px;">${c.cidade_foro || 'Brasília'}, ${formatarDataExtenso(c.data_assinatura)}.</p>

    ${blocoAssinaturas(c, 'CONTRATANTE', 'CONTRATADA(O) — CORRETOR(A)')}
    ${blocoTestemunhas(c)}
  `;
}

function gerarCorpoCessaoDireitos(c: any, imovel: any): string {
  const objeto = imovel ? montarCorpoImovel(imovel) : (c.objeto_descricao || '[descrição dos direitos cedidos]');
  return `
    <h1 style="font-size:14pt;text-align:center;margin-bottom:4px;">CONTRATO DE CESSÃO DE DIREITOS</h1>
    <p style="text-align:center;color:#64748b;font-size:9pt;margin-bottom:20px;">Contrato nº ${c.numero}</p>

    <p style="font-size:9.5pt;text-align:justify;margin-bottom:10px;">
      <strong>CEDENTE:</strong> ${c.parte1_nome}, ${c.parte1_estado_civil || ''}, CPF/CNPJ nº ${c.parte1_cpf_cnpj || '________'},
      residente em ${c.parte1_endereco || '________'}.
    </p>
    <p style="font-size:9.5pt;text-align:justify;margin-bottom:16px;">
      <strong>CESSIONÁRIO(A):</strong> ${c.parte2_nome}, ${c.parte2_estado_civil || ''}, CPF/CNPJ nº ${c.parte2_cpf_cnpj || '________'},
      residente em ${c.parte2_endereco || '________'}.
    </p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 1ª — DO OBJETO.</strong> O CEDENTE cede e transfere ao CESSIONÁRIO, em caráter irrevogável
      e irretratável, todos os direitos que possui sobre o ${objeto}${c.objeto_descricao ? ' — ' + c.objeto_descricao : ''}.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 2ª — DO VALOR DA CESSÃO.</strong> Pela presente cessão, o CESSIONÁRIO pagará ao CEDENTE
      o valor de ${formatarMoeda(c.valor_total)}${c.forma_pagamento ? `, por meio de ${c.forma_pagamento}` : ''}${c.numero_parcelas ? `, em ${c.numero_parcelas} parcela(s) de ${formatarMoeda(c.valor_parcela)}` : ''}.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 3ª — DA SUB-ROGAÇÃO.</strong> A partir da assinatura deste instrumento, o CESSIONÁRIO
      sub-roga-se em todos os direitos e obrigações do CEDENTE relativos ao objeto cedido, isentando o CEDENTE de
      responsabilidades futuras a ele vinculadas.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 4ª — DA GARANTIA.</strong> O CEDENTE declara, sob as penas da lei, que os direitos cedidos
      encontram-se livres e desembaraçados de quaisquer ônus, dívidas ou pendências judiciais não informadas neste contrato.</p>

    ${c.clausulas_extra ? `<p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA(S) ADICIONAL(IS).</strong> ${c.clausulas_extra}</p>` : ''}

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 5ª — DO FORO.</strong> Fica eleito o foro da comarca de ${c.cidade_foro || 'Brasília'}.</p>

    <p style="font-size:9.5pt;margin-top:20px;">${c.cidade_foro || 'Brasília'}, ${formatarDataExtenso(c.data_assinatura)}.</p>

    ${blocoAssinaturas(c, 'CEDENTE', 'CESSIONÁRIO(A)')}
    ${blocoTestemunhas(c)}
  `;
}

function gerarCorpoPromessaCompraVenda(c: any, imovel: any): string {
  const objeto = imovel ? montarCorpoImovel(imovel) : (c.objeto_descricao || '[objeto do imóvel]');
  return `
    <h1 style="font-size:14pt;text-align:center;margin-bottom:4px;">CONTRATO PARTICULAR DE PROMESSA DE COMPRA E VENDA DE IMÓVEL</h1>
    <p style="text-align:center;color:#64748b;font-size:9pt;margin-bottom:20px;">Contrato nº ${c.numero}</p>

    <p style="font-size:9.5pt;text-align:justify;margin-bottom:10px;">
      <strong>PROMITENTE VENDEDOR(A):</strong> ${c.parte1_nome}, ${c.parte1_estado_civil || ''}, CPF/CNPJ nº ${c.parte1_cpf_cnpj || '________'},
      residente em ${c.parte1_endereco || '________'}.
    </p>
    <p style="font-size:9.5pt;text-align:justify;margin-bottom:16px;">
      <strong>PROMITENTE COMPRADOR(A):</strong> ${c.parte2_nome}, ${c.parte2_estado_civil || ''}, CPF/CNPJ nº ${c.parte2_cpf_cnpj || '________'},
      residente em ${c.parte2_endereco || '________'}.
    </p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 1ª — DO OBJETO.</strong> O PROMITENTE VENDEDOR promete vender, e o PROMITENTE COMPRADOR
      promete comprar, o ${objeto}, nas condições estabelecidas neste instrumento.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 2ª — DO PREÇO E CONDIÇÕES.</strong> O preço ajustado é de ${formatarMoeda(c.valor_total)},
      ${c.valor_entrada ? `sendo ${formatarMoeda(c.valor_entrada)} pagos a título de sinal e princípio de pagamento, ` : ''}
      ${c.numero_parcelas ? `e o saldo em ${c.numero_parcelas} parcela(s) de ${formatarMoeda(c.valor_parcela)}, com vencimento todo dia ${c.vencimento_dia || '__'}, ` : ''}
      por meio de ${c.forma_pagamento || 'forma a ser acordada entre as partes'}.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 3ª — DA ESCRITURA DEFINITIVA.</strong> Cumpridas as obrigações aqui assumidas e quitado
      integralmente o preço, as partes outorgarão a escritura definitiva de compra e venda no prazo de até 30 (trinta) dias,
      correndo as despesas cartorárias por conta do PROMITENTE COMPRADOR, salvo disposição em contrário.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 4ª — DA IRREVOGABILIDADE.</strong> A presente promessa é firmada em carater irrevogável e
      irretratável, obrigando as partes e seus herdeiros e sucessores ao seu integral cumprimento.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 5ª — DA MULTA E RESCISÃO.</strong> O descumprimento de qualquer cláusula sujeitará o
      infrator ao pagamento de multa equivalente a 10% (dez por cento) do valor total do contrato, sem prejuízo de perdas e danos.</p>

    ${c.clausulas_extra ? `<p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA(S) ADICIONAL(IS).</strong> ${c.clausulas_extra}</p>` : ''}

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 6ª — DO FORO.</strong> Fica eleito o foro da comarca de ${c.cidade_foro || 'Brasília'}.</p>

    <p style="font-size:9.5pt;margin-top:20px;">${c.cidade_foro || 'Brasília'}, ${formatarDataExtenso(c.data_assinatura)}.</p>

    ${blocoAssinaturas(c, 'PROMITENTE VENDEDOR(A)', 'PROMITENTE COMPRADOR(A)')}
    ${blocoTestemunhas(c)}
  `;
}

function gerarCorpoAssessoriaVenda(c: any, imovel: any, exclusiva: boolean): string {
  const objeto = imovel ? montarCorpoImovel(imovel) : (c.objeto_descricao || '[descrição do imóvel]');
  const tituloExclusividade = exclusiva ? 'COM EXCLUSIVIDADE' : 'SEM EXCLUSIVIDADE';
  return `
    <h1 style="font-size:14pt;text-align:center;margin-bottom:4px;">CONTRATO DE ASSESSORIA IMOBILIÁRIA PARA VENDA ${tituloExclusividade}</h1>
    <p style="text-align:center;color:#64748b;font-size:9pt;margin-bottom:20px;">Contrato nº ${c.numero}</p>

    <p style="font-size:9.5pt;text-align:justify;margin-bottom:10px;">
      <strong>CONTRATANTE (Proprietário):</strong> ${c.parte1_nome}, CPF/CNPJ nº ${c.parte1_cpf_cnpj || '________'},
      residente/sediado em ${c.parte1_endereco || '________'}.
    </p>
    <p style="font-size:9.5pt;text-align:justify;margin-bottom:16px;">
      <strong>CONTRATADA (Imobiliária/Corretor):</strong> ${c.parte2_nome}, CPF/CNPJ nº ${c.parte2_cpf_cnpj || '________'},
      com sede/endereço em ${c.parte2_endereco || '________'}.
    </p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 1ª — DO OBJETO.</strong> A CONTRATADA prestará serviços de assessoria e intermediação
      imobiliária para venda do ${objeto}.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 2ª — DA EXCLUSIVIDADE.</strong> ${
      exclusiva
        ? 'O presente contrato é firmado EM CARÁTER EXCLUSIVO, comprometendo-se o CONTRATANTE a não contratar outra imobiliária ou corretor(a) para a venda do imóvel durante a vigência deste instrumento, sob pena de ser devida a comissão integral à CONTRATADA mesmo em caso de venda realizada por terceiros ou pelo próprio CONTRATANTE.'
        : 'O presente contrato é firmado SEM EXCLUSIVIDADE, podendo o CONTRATANTE contratar simultaneamente outras imobiliárias ou corretores para a venda do mesmo imóvel, sendo devida comissão à CONTRATADA apenas em caso de venda efetivada por sua intermediação direta.'
    }</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 3ª — DA VIGÊNCIA.</strong> O presente contrato terá vigência de
      ${c.prazo_vigencia_meses ? c.prazo_vigencia_meses + ' meses' : '[prazo]'} a partir da data de assinatura, renovável por acordo entre as partes.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 4ª — DA COMISSÃO.</strong> Em caso de venda efetivada dentro da vigência deste
      contrato, será devida à CONTRATADA comissão de ${c.percentual_comissao ? c.percentual_comissao + '%' : '[percentual]'} sobre o valor da venda${c.valor_total ? `, estimado em ${formatarMoeda(c.valor_total)}` : ''},
      a ser paga na assinatura do contrato de compra e venda ou na efetiva quitação do negócio.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 5ª — DAS OBRIGAÇÕES DA CONTRATADA.</strong> Divulgar o imóvel nos canais adequados,
      acompanhar visitas, prestar informações verídicas e atuar com zelo e boa-fé na negociação.</p>

    ${c.clausulas_extra ? `<p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA(S) ADICIONAL(IS).</strong> ${c.clausulas_extra}</p>` : ''}

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 6ª — DO FORO.</strong> Fica eleito o foro da comarca de ${c.cidade_foro || 'Brasília'}.</p>

    <p style="font-size:9.5pt;margin-top:20px;">${c.cidade_foro || 'Brasília'}, ${formatarDataExtenso(c.data_assinatura)}.</p>

    ${blocoAssinaturas(c, 'CONTRATANTE', 'CONTRATADA')}
    ${blocoTestemunhas(c)}
  `;
}

function gerarCorpoAvaliacaoImovel(c: any, imovel: any): string {
  const objeto = imovel ? montarCorpoImovel(imovel) : (c.objeto_descricao || '[descrição do imóvel]');
  return `
    <h1 style="font-size:14pt;text-align:center;margin-bottom:4px;">CONTRATO DE PRESTAÇÃO DE SERVIÇOS DE AVALIAÇÃO DE IMÓVEL</h1>
    <p style="text-align:center;color:#64748b;font-size:9pt;margin-bottom:20px;">Contrato nº ${c.numero}</p>

    <p style="font-size:9.5pt;text-align:justify;margin-bottom:10px;">
      <strong>CONTRATANTE:</strong> ${c.parte1_nome}, CPF/CNPJ nº ${c.parte1_cpf_cnpj || '________'}, endereço em ${c.parte1_endereco || '________'}.
    </p>
    <p style="font-size:9.5pt;text-align:justify;margin-bottom:16px;">
      <strong>CONTRATADA(O) — Avaliador(a)/Imobiliária:</strong> ${c.parte2_nome}, CPF/CNPJ nº ${c.parte2_cpf_cnpj || '________'}, endereço em ${c.parte2_endereco || '________'}.
    </p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 1ª — DO OBJETO.</strong> A CONTRATADA realizará avaliação técnica de valor de mercado
      do ${objeto}, com emissão de laudo/parecer de avaliação.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 2ª — DA METODOLOGIA.</strong> ${c.metodologia_avaliacao || 'A avaliação será realizada com base em pesquisa de mercado comparativa, análise de características físicas e de localização do imóvel, seguindo boas práticas de mercado.'}</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 3ª — DO VALOR E FORMA DE PAGAMENTO.</strong> Pelos serviços prestados, o CONTRATANTE pagará
      à CONTRATADA o valor de ${formatarMoeda(c.valor_total)}${c.forma_pagamento ? `, por meio de ${c.forma_pagamento}` : ''}.
      ${c.valor_avaliacao ? `O valor de mercado apurado na avaliação foi de ${formatarMoeda(c.valor_avaliacao)}.` : ''}</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 4ª — DO PRAZO DE ENTREGA.</strong> O laudo de avaliação será entregue em até
      ${c.prazo_vigencia_meses ? c.prazo_vigencia_meses + ' dia(s)' : '[prazo]'} a contar da assinatura deste contrato e do acesso ao imóvel.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 5ª — DA NATUREZA DO SERVIÇO.</strong> O laudo de avaliação tem caráter estimativo e
      opinativo, não constituindo garantia de venda pelo valor apurado, tampouco substituindo avaliação judicial quando exigida por lei.</p>

    ${c.clausulas_extra ? `<p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA(S) ADICIONAL(IS).</strong> ${c.clausulas_extra}</p>` : ''}

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 6ª — DO FORO.</strong> Fica eleito o foro da comarca de ${c.cidade_foro || 'Brasília'}.</p>

    <p style="font-size:9.5pt;margin-top:20px;">${c.cidade_foro || 'Brasília'}, ${formatarDataExtenso(c.data_assinatura)}.</p>

    ${blocoAssinaturas(c, 'CONTRATANTE', 'CONTRATADA(O)')}
    ${blocoTestemunhas(c)}
  `;
}

function gerarCorpoAluguel(c: any, imovel: any): string {
  const objeto = imovel ? montarCorpoImovel(imovel) : (c.objeto_descricao || '[objeto do imóvel]');
  const garantiaLabel: Record<string, string> = {
    caucao: 'caução em dinheiro',
    fianca: 'fiança pessoal',
    seguro_fianca: 'seguro-fiança',
    titulo_capitalizacao: 'título de capitalização',
  };
  return `
    <h1 style="font-size:14pt;text-align:center;margin-bottom:4px;">CONTRATO DE LOCAÇÃO DE IMÓVEL</h1>
    <p style="text-align:center;color:#64748b;font-size:9pt;margin-bottom:20px;">Contrato nº ${c.numero}</p>

    <p style="font-size:9.5pt;text-align:justify;margin-bottom:10px;">
      <strong>LOCADOR(A):</strong> ${c.parte1_nome}, ${c.parte1_estado_civil || ''}, CPF/CNPJ nº ${c.parte1_cpf_cnpj || '________'},
      residente em ${c.parte1_endereco || '________'}.
    </p>
    <p style="font-size:9.5pt;text-align:justify;margin-bottom:16px;">
      <strong>LOCATÁRIO(A):</strong> ${c.parte2_nome}, ${c.parte2_estado_civil || ''}, CPF/CNPJ nº ${c.parte2_cpf_cnpj || '________'},
      residente em ${c.parte2_endereco || '________'}.
    </p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 1ª — DO OBJETO.</strong> O LOCADOR dá em locação ao LOCATÁRIO o ${objeto},
      destinado a fins ${c.objeto_descricao || 'residenciais'}.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 2ª — DO PRAZO.</strong> A locação vigerá por
      ${c.prazo_vigencia_meses ? c.prazo_vigencia_meses + ' meses' : '[prazo]'}, a contar da data de assinatura, podendo ser renovada por
      acordo entre as partes ou nos termos da Lei do Inquilinato (Lei nº 8.245/1991).</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 3ª — DO ALUGUEL E REAJUSTE.</strong> O valor do aluguel mensal é de
      ${formatarMoeda(c.valor_total)}, com vencimento todo dia ${c.vencimento_dia || '__'} de cada mês, reajustado anualmente pelo índice
      ${c.indice_reajuste || 'IGP-M'} ou outro que vier a substituí-lo.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 4ª — DA GARANTIA LOCATÍCIA.</strong> Como garantia do cumprimento das obrigações
      assumidas, o LOCATÁRIO oferece ${garantiaLabel[c.garantia_locaticia] || 'garantia a ser definida entre as partes'}${c.valor_caucao ? `, no valor de ${formatarMoeda(c.valor_caucao)}` : ''}.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 5ª — DAS DESPESAS.</strong> Correrão por conta do LOCATÁRIO as despesas de consumo
      (água, luz, gás, condomínio quando aplicável) e, por conta do LOCADOR, o IPTU, salvo disposição diversa entre as partes.</p>

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 6ª — DA DEVOLUÇÃO DO IMÓVEL.</strong> Ao término da locação, o imóvel deverá ser
      devolvido nas mesmas condições em que foi recebido, ressalvado o desgaste natural pelo uso regular.</p>

    ${c.clausulas_extra ? `<p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA(S) ADICIONAL(IS).</strong> ${c.clausulas_extra}</p>` : ''}

    <p style="font-size:9.5pt;text-align:justify;"><strong>CLÁUSULA 7ª — DO FORO.</strong> Fica eleito o foro da comarca de ${c.cidade_foro || 'Brasília'}.</p>

    <p style="font-size:9.5pt;margin-top:20px;">${c.cidade_foro || 'Brasília'}, ${formatarDataExtenso(c.data_assinatura)}.</p>

    ${blocoAssinaturas(c, 'LOCADOR(A)', 'LOCATÁRIO(A)')}
    ${blocoTestemunhas(c)}
  `;
}

export default function createContratosImobiliariosRouter(
  pool: any,
  helpers: { auth?: any; gerarHtmlTimbrado: (body: string, titulo?: string) => string; gerarPdfDeHtml: (html: string) => Promise<Buffer> },
) {
  const router = Router();
  const { auth, gerarHtmlTimbrado, gerarPdfDeHtml } = helpers;
  if (auth) router.use(auth);

  // ── GET /api/contratos-imobiliarios — lista ──────────────────────────────
  router.get('/', async (req: Request, res: Response) => {
    try {
      const { tipo, status, imovel_id, page = '1', pageSize = '20' } = req.query as Record<string, string>;
      const where: string[] = [];
      const params: any[] = [];
      let i = 1;
      if (tipo) { where.push(`c.tipo = $${i++}`); params.push(tipo); }
      if (status) { where.push(`c.status = $${i++}`); params.push(status); }
      if (imovel_id) { where.push(`c.imovel_id = $${i++}`); params.push(imovel_id); }
      const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
      const limit = Math.min(Math.max(Number(pageSize) || 20, 1), 100);
      const offset = (Math.max(Number(page) || 1, 1) - 1) * limit;

      const totalQ = await pool.query(`SELECT COUNT(*)::int AS total FROM contratos_imobiliarios c ${whereSql}`, params);
      const dataQ = await pool.query(
        `SELECT c.*, i.titulo AS imovel_titulo, i.codigo AS imovel_codigo
         FROM contratos_imobiliarios c
         LEFT JOIN imoveis i ON i.id = c.imovel_id
         ${whereSql}
         ORDER BY c.criado_em DESC
         LIMIT $${i} OFFSET $${i + 1}`,
        [...params, limit, offset],
      );
      res.json({ items: dataQ.rows, total: totalQ.rows[0].total, page: Number(page) || 1, pageSize: limit });
    } catch (err) {
      console.error('[GET /api/contratos-imobiliarios]', err);
      res.status(500).json({ error: 'Erro ao listar contratos' });
    }
  });

  // ── GET /api/contratos-imobiliarios/:id ───────────────────────────────────
  router.get('/:id', async (req: Request, res: Response) => {
    try {
      const r = await pool.query(
        `SELECT c.*, i.titulo AS imovel_titulo, i.codigo AS imovel_codigo
         FROM contratos_imobiliarios c LEFT JOIN imoveis i ON i.id = c.imovel_id WHERE c.id = $1`,
        [req.params.id],
      );
      if (r.rows.length === 0) { res.status(404).json({ error: 'Contrato não encontrado' }); return; }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[GET /api/contratos-imobiliarios/:id]', err);
      res.status(500).json({ error: 'Erro ao buscar contrato' });
    }
  });

  // ── POST /api/contratos-imobiliarios — cria contrato (rascunho) ─────────
  router.post('/', async (req: Request, res: Response) => {
    try {
      const dados = somenteCamposValidos(req.body || {});
      if (!dados.tipo || !dados.parte1_nome || !dados.parte2_nome) {
        res.status(400).json({ error: 'tipo, parte1_nome e parte2_nome são obrigatórios' });
        return;
      }
      const numero = await gerarNumeroContrato(pool, dados.tipo);
      const criadoPor = (req as any).user?.id || null;
      const campos = Object.keys(dados);
      const valores = Object.values(dados);
      const placeholders = campos.map((_, idx) => `$${idx + 3}`).join(', ');

      const r = await pool.query(
        `INSERT INTO contratos_imobiliarios (numero, criado_por, ${campos.join(', ')})
         VALUES ($1, $2, ${placeholders})
         RETURNING *`,
        [numero, criadoPor, ...valores],
      );
      res.status(201).json(r.rows[0]);
    } catch (err) {
      console.error('[POST /api/contratos-imobiliarios]', err);
      res.status(500).json({ error: 'Erro ao criar contrato' });
    }
  });

  // ── PUT /api/contratos-imobiliarios/:id ───────────────────────────────────
  router.put('/:id', async (req: Request, res: Response) => {
    try {
      const dados = somenteCamposValidos(req.body || {});
      const campos = Object.keys(dados);
      if (campos.length === 0) { res.status(400).json({ error: 'Nenhum campo para atualizar' }); return; }
      const sets = campos.map((c, idx) => `${c} = $${idx + 2}`).join(', ');
      const r = await pool.query(
        `UPDATE contratos_imobiliarios SET ${sets}, atualizado_em = NOW() WHERE id = $1 RETURNING *`,
        [req.params.id, ...Object.values(dados)],
      );
      if (r.rows.length === 0) { res.status(404).json({ error: 'Contrato não encontrado' }); return; }
      res.json(r.rows[0]);
    } catch (err) {
      console.error('[PUT /api/contratos-imobiliarios/:id]', err);
      res.status(500).json({ error: 'Erro ao atualizar contrato' });
    }
  });

  // ── GET /api/contratos-imobiliarios/:id/pdf — gera a minuta em PDF ──────
  router.get('/:id/pdf', async (req: Request, res: Response) => {
    try {
      const r = await pool.query(
        `SELECT c.*,
                i.endereco, i.numero, i.complemento, i.bairro, i.cidade, i.uf, i.cep, i.matricula_imovel
         FROM contratos_imobiliarios c LEFT JOIN imoveis i ON i.id = c.imovel_id WHERE c.id = $1`,
        [req.params.id],
      );
      if (r.rows.length === 0) { res.status(404).json({ error: 'Contrato não encontrado' }); return; }
      const c = r.rows[0];
      const imovel = c.imovel_id ? c : null;

      let corpo: string;
      if (c.tipo === 'compra_venda') corpo = gerarCorpoCompraVenda(c, imovel);
      else if (c.tipo === 'promessa_compra_venda') corpo = gerarCorpoPromessaCompraVenda(c, imovel);
      else if (c.tipo === 'prestacao_servico') corpo = gerarCorpoPrestacaoServico(c, imovel);
      else if (c.tipo === 'assessoria_venda_exclusiva') corpo = gerarCorpoAssessoriaVenda(c, imovel, true);
      else if (c.tipo === 'assessoria_venda_sem_exclusiva') corpo = gerarCorpoAssessoriaVenda(c, imovel, false);
      else if (c.tipo === 'avaliacao_imovel') corpo = gerarCorpoAvaliacaoImovel(c, imovel);
      else if (c.tipo === 'aluguel') corpo = gerarCorpoAluguel(c, imovel);
      else corpo = gerarCorpoCessaoDireitos(c, imovel);

      const html = gerarHtmlTimbrado(corpo, 'Contrato Imobiliário');
      const pdfBuffer = await gerarPdfDeHtml(html);

      await pool.query(
        `UPDATE contratos_imobiliarios SET status = CASE WHEN status = 'rascunho' THEN 'gerado' ELSE status END WHERE id = $1`,
        [req.params.id],
      );

      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `inline; filename="contrato-${c.numero}.pdf"`);
      res.send(pdfBuffer);
    } catch (err) {
      console.error('[GET /api/contratos-imobiliarios/:id/pdf]', err);
      res.status(500).json({ error: 'Erro ao gerar PDF do contrato' });
    }
  });

  return router;
}
