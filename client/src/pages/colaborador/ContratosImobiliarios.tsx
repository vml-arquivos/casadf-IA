import { useEffect, useState } from "react";
import Layout from "./Layout";
import { toast } from "sonner";
import { Plus, FileDown, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  listarContratos, criarContrato, atualizarContrato, urlPdfContrato,
  listarImoveis, ContratoImobiliario, Imovel, TIPOS_CONTRATO, GARANTIAS_LOCATICIAS,
} from "@/lib/api-imoveis";
import { getToken } from "@/lib/api";

const STATUS_LABEL: Record<string, string> = {
  rascunho: "Rascunho", gerado: "Gerado", assinado: "Assinado", cancelado: "Cancelado",
};
const STATUS_COR: Record<string, string> = {
  rascunho: "bg-slate-200 text-slate-700 border-slate-300",
  gerado: "bg-blue-100 text-blue-800 border-blue-200",
  assinado: "bg-emerald-100 text-emerald-800 border-emerald-200",
  cancelado: "bg-red-100 text-red-800 border-red-200",
};

const VAZIO: Partial<ContratoImobiliario> = {
  tipo: "compra_venda",
  parte1_nome: "", parte2_nome: "", cidade_foro: "Brasília",
};

export default function ContratosImobiliarios() {
  const [contratos, setContratos] = useState<ContratoImobiliario[]>([]);
  const [imoveis, setImoveis] = useState<Imovel[]>([]);
  const [loading, setLoading] = useState(true);
  const [mostrarForm, setMostrarForm] = useState(false);
  const [salvando, setSalvando] = useState(false);
  const [dados, setDados] = useState<Partial<ContratoImobiliario>>(VAZIO);

  async function carregar() {
    setLoading(true);
    try {
      const [resContratos, resImoveis] = await Promise.all([
        listarContratos({ pageSize: 50 }),
        listarImoveis({ admin: true, pageSize: 100 }),
      ]);
      setContratos(resContratos.items);
      setImoveis(resImoveis.items);
    } catch (e: any) {
      toast.error(e?.message || "Erro ao carregar contratos");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { carregar(); }, []);

  function set<K extends keyof ContratoImobiliario>(campo: K, valor: ContratoImobiliario[K]) {
    setDados((d) => ({ ...d, [campo]: valor }));
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault();
    if (!dados.parte1_nome || !dados.parte2_nome) {
      toast.error("Informe o nome das duas partes do contrato.");
      return;
    }
    setSalvando(true);
    try {
      await criarContrato(dados);
      toast.success("Contrato criado. Gere o PDF para revisar a minuta.");
      setMostrarForm(false);
      setDados(VAZIO);
      carregar();
    } catch (e: any) {
      toast.error(e?.message || "Erro ao criar contrato");
    } finally {
      setSalvando(false);
    }
  }

  async function mudarStatus(id: string, status: string) {
    try {
      await atualizarContrato(id, { status: status as any });
      setContratos((c) => c.map((item) => (item.id === id ? { ...item, status } as any : item)));
    } catch (e: any) {
      toast.error(e?.message || "Erro ao atualizar status");
    }
  }

  async function baixarPdf(id: string, numero: string) {
    try {
      const res = await fetch(urlPdfContrato(id), { headers: { Authorization: `Bearer ${getToken()}` } });
      if (!res.ok) throw new Error("Erro ao gerar PDF");
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      window.open(url, "_blank");
    } catch (e: any) {
      toast.error(e?.message || `Erro ao gerar PDF do contrato ${numero}`);
    }
  }

  const rotulosPorTipo: Record<string, { p1: string; p2: string }> = {
    compra_venda: { p1: "Vendedor(a)", p2: "Comprador(a)" },
    promessa_compra_venda: { p1: "Promitente Vendedor(a)", p2: "Promitente Comprador(a)" },
    prestacao_servico: { p1: "Contratante", p2: "Contratada(o) / Corretor(a)" },
    assessoria_venda_exclusiva: { p1: "Contratante (Proprietário)", p2: "Contratada (Imobiliária)" },
    assessoria_venda_sem_exclusiva: { p1: "Contratante (Proprietário)", p2: "Contratada (Imobiliária)" },
    avaliacao_imovel: { p1: "Contratante", p2: "Contratada(o) — Avaliador(a)" },
    aluguel: { p1: "Locador(a)", p2: "Locatário(a)" },
    cessao_direitos: { p1: "Cedente", p2: "Cessionário(a)" },
  };
  const rotulos = rotulosPorTipo[dados.tipo || "compra_venda"] || { p1: "Parte 1", p2: "Parte 2" };

  return (
    <Layout>
      <div className="p-6 max-w-5xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold">Contratos Imobiliários</h1>
            <p className="text-muted-foreground text-sm">
              Compra e venda, prestação de serviço (corretagem) e cessão de direitos.
            </p>
          </div>
          {!mostrarForm && (
            <Button className="gap-2" onClick={() => setMostrarForm(true)}><Plus className="size-4" /> Novo contrato</Button>
          )}
        </div>

        {mostrarForm && (
          <Card className="mb-6">
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle>Novo contrato</CardTitle>
              <Button variant="ghost" size="sm" onClick={() => setMostrarForm(false)}><X className="size-4" /></Button>
            </CardHeader>
            <CardContent>
              <form onSubmit={salvar} className="flex flex-col gap-4">
                <div className="grid md:grid-cols-2 gap-4">
                  <div>
                    <Label>Tipo de contrato</Label>
                    <Select value={dados.tipo || "compra_venda"} onValueChange={(v) => set("tipo", v as any)}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>{TIPOS_CONTRATO.map((t) => <SelectItem key={t.value} value={t.value}>{t.label}</SelectItem>)}</SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Imóvel relacionado (opcional)</Label>
                    <Select value={dados.imovel_id || "nenhum"} onValueChange={(v) => set("imovel_id", v === "nenhum" ? undefined as any : v)}>
                      <SelectTrigger><SelectValue placeholder="Selecione um imóvel" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="nenhum">Nenhum / objeto descrito manualmente</SelectItem>
                        {imoveis.map((im) => <SelectItem key={im.id} value={im.id}>{im.codigo} — {im.titulo}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <div className="grid md:grid-cols-2 gap-4 border-t pt-4">
                  <div className="flex flex-col gap-2">
                    <p className="font-medium text-sm">{rotulos.p1}</p>
                    <Input placeholder="Nome completo *" value={dados.parte1_nome || ""} onChange={(e) => set("parte1_nome", e.target.value)} required />
                    <Input placeholder="CPF/CNPJ" value={dados.parte1_cpf_cnpj || ""} onChange={(e) => set("parte1_cpf_cnpj", e.target.value)} />
                    <Input placeholder="Endereço" value={dados.parte1_endereco || ""} onChange={(e) => set("parte1_endereco", e.target.value)} />
                    <Input placeholder="Estado civil" value={dados.parte1_estado_civil || ""} onChange={(e) => set("parte1_estado_civil", e.target.value)} />
                  </div>
                  <div className="flex flex-col gap-2">
                    <p className="font-medium text-sm">{rotulos.p2}</p>
                    <Input placeholder="Nome completo *" value={dados.parte2_nome || ""} onChange={(e) => set("parte2_nome", e.target.value)} required />
                    <Input placeholder="CPF/CNPJ" value={dados.parte2_cpf_cnpj || ""} onChange={(e) => set("parte2_cpf_cnpj", e.target.value)} />
                    <Input placeholder="Endereço" value={dados.parte2_endereco || ""} onChange={(e) => set("parte2_endereco", e.target.value)} />
                    <Input placeholder="Estado civil" value={dados.parte2_estado_civil || ""} onChange={(e) => set("parte2_estado_civil", e.target.value)} />
                  </div>
                </div>

                <div className="grid md:grid-cols-3 gap-4 border-t pt-4">
                  <div>
                    <Label>Valor total (R$)</Label>
                    <Input type="number" step="0.01" value={dados.valor_total ?? ""} onChange={(e) => set("valor_total", e.target.value ? Number(e.target.value) : undefined as any)} />
                  </div>
                  {dados.tipo === "compra_venda" && (
                    <>
                      <div>
                        <Label>Valor de entrada (R$)</Label>
                        <Input type="number" step="0.01" value={dados.valor_entrada ?? ""} onChange={(e) => set("valor_entrada", e.target.value ? Number(e.target.value) : undefined as any)} />
                      </div>
                      <div>
                        <Label>Nº de parcelas</Label>
                        <Input type="number" value={dados.numero_parcelas ?? ""} onChange={(e) => set("numero_parcelas", e.target.value ? Number(e.target.value) : undefined as any)} />
                      </div>
                    </>
                  )}
                  {dados.tipo === "prestacao_servico" && (
                    <div>
                      <Label>Comissão (%)</Label>
                      <Input type="number" step="0.01" value={dados.percentual_comissao ?? ""} onChange={(e) => set("percentual_comissao", e.target.value ? Number(e.target.value) : undefined as any)} />
                    </div>
                  )}
                  {(dados.tipo === "assessoria_venda_exclusiva" || dados.tipo === "assessoria_venda_sem_exclusiva") && (
                    <>
                      <div>
                        <Label>Comissão (%)</Label>
                        <Input type="number" step="0.01" value={dados.percentual_comissao ?? ""} onChange={(e) => set("percentual_comissao", e.target.value ? Number(e.target.value) : undefined as any)} />
                      </div>
                      <div>
                        <Label>Prazo de vigência (meses)</Label>
                        <Input type="number" value={dados.prazo_vigencia_meses ?? ""} onChange={(e) => set("prazo_vigencia_meses", e.target.value ? Number(e.target.value) : undefined as any)} />
                      </div>
                    </>
                  )}
                  {dados.tipo === "avaliacao_imovel" && (
                    <>
                      <div>
                        <Label>Valor de mercado apurado (R$)</Label>
                        <Input type="number" step="0.01" value={dados.valor_avaliacao ?? ""} onChange={(e) => set("valor_avaliacao", e.target.value ? Number(e.target.value) : undefined as any)} />
                      </div>
                      <div>
                        <Label>Prazo de entrega (dias)</Label>
                        <Input type="number" value={dados.prazo_vigencia_meses ?? ""} onChange={(e) => set("prazo_vigencia_meses", e.target.value ? Number(e.target.value) : undefined as any)} />
                      </div>
                    </>
                  )}
                  {dados.tipo === "aluguel" && (
                    <>
                      <div>
                        <Label>Prazo da locação (meses)</Label>
                        <Input type="number" value={dados.prazo_vigencia_meses ?? ""} onChange={(e) => set("prazo_vigencia_meses", e.target.value ? Number(e.target.value) : undefined as any)} />
                      </div>
                      <div>
                        <Label>Índice de reajuste</Label>
                        <Input placeholder="IGP-M, IPCA..." value={dados.indice_reajuste || ""} onChange={(e) => set("indice_reajuste", e.target.value)} />
                      </div>
                      <div>
                        <Label>Garantia locatícia</Label>
                        <Select value={dados.garantia_locaticia || "caucao"} onValueChange={(v) => set("garantia_locaticia", v)}>
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>{GARANTIAS_LOCATICIAS.map((g) => <SelectItem key={g.value} value={g.value}>{g.label}</SelectItem>)}</SelectContent>
                        </Select>
                      </div>
                      <div>
                        <Label>Valor da caução (R$, se aplicável)</Label>
                        <Input type="number" step="0.01" value={dados.valor_caucao ?? ""} onChange={(e) => set("valor_caucao", e.target.value ? Number(e.target.value) : undefined as any)} />
                      </div>
                    </>
                  )}
                  <div>
                    <Label>Forma de pagamento</Label>
                    <Input value={dados.forma_pagamento || ""} onChange={(e) => set("forma_pagamento", e.target.value)} />
                  </div>
                </div>

                {dados.tipo === "avaliacao_imovel" && (
                  <div>
                    <Label>Metodologia de avaliação (opcional)</Label>
                    <Textarea rows={2} value={dados.metodologia_avaliacao || ""} onChange={(e) => set("metodologia_avaliacao", e.target.value)} />
                  </div>
                )}

                <div>
                  <Label>Objeto / descrição adicional {dados.imovel_id ? "(opcional — o endereço do imóvel já será incluído automaticamente)" : ""}</Label>
                  <Textarea rows={2} value={dados.objeto_descricao || ""} onChange={(e) => set("objeto_descricao", e.target.value)} />
                </div>
                <div>
                  <Label>Cláusulas adicionais (opcional)</Label>
                  <Textarea rows={2} value={dados.clausulas_extra || ""} onChange={(e) => set("clausulas_extra", e.target.value)} />
                </div>

                <div className="grid md:grid-cols-3 gap-4">
                  <div>
                    <Label>Data de assinatura</Label>
                    <Input type="date" value={dados.data_assinatura || ""} onChange={(e) => set("data_assinatura", e.target.value)} />
                  </div>
                  <div>
                    <Label>Cidade / foro</Label>
                    <Input value={dados.cidade_foro || "Brasília"} onChange={(e) => set("cidade_foro", e.target.value)} />
                  </div>
                </div>

                <div className="flex justify-end gap-2 pt-2">
                  <Button type="button" variant="outline" onClick={() => setMostrarForm(false)}>Cancelar</Button>
                  <Button type="submit" disabled={salvando}>{salvando ? "Criando..." : "Criar contrato"}</Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        {loading && <p className="text-center text-muted-foreground py-10">Carregando...</p>}
        {!loading && contratos.length === 0 && !mostrarForm && (
          <p className="text-center text-muted-foreground py-10">Nenhum contrato cadastrado ainda.</p>
        )}

        <div className="flex flex-col gap-3">
          {contratos.map((c) => (
            <Card key={c.id}>
              <CardContent className="pt-6 flex flex-wrap items-center justify-between gap-3">
                <div>
                  <p className="text-xs text-muted-foreground">{c.numero} — {TIPOS_CONTRATO.find((t) => t.value === c.tipo)?.label}</p>
                  <p className="font-medium">{c.parte1_nome} <span className="text-muted-foreground">×</span> {c.parte2_nome}</p>
                  {c.imovel_titulo && <p className="text-xs text-muted-foreground">{c.imovel_codigo} — {c.imovel_titulo}</p>}
                </div>
                <div className="flex items-center gap-2">
                  <Badge className={`border ${STATUS_COR[c.status] || ""}`}>{STATUS_LABEL[c.status] || c.status}</Badge>
                  <Select value={c.status} onValueChange={(s) => mudarStatus(c.id, s)}>
                    <SelectTrigger className="w-36 h-8 text-xs"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {Object.entries(STATUS_LABEL).map(([v, l]) => <SelectItem key={v} value={v}>{l}</SelectItem>)}
                    </SelectContent>
                  </Select>
                  <Button size="sm" variant="outline" className="gap-1" onClick={() => baixarPdf(c.id, c.numero)}>
                    <FileDown className="size-3.5" /> PDF
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </Layout>
  );
}
