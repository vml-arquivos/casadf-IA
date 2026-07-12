import { useState, useEffect } from "react";
import { Scale, AlertTriangle, CheckCircle2, AlertCircle, FileText } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import ProtectedRoute from "@/components/ProtectedRoute";
import { apiFetch } from "@/lib/api";
import { analisarJuridico, buscarAnalisesJuridicasImovel, formatarMoeda } from "@/lib/api-imoveis";

interface Imovel {
  id: string;
  codigo: string;
  titulo: string;
  valor_venda?: number;
  valor_locacao?: number;
  bairro?: string;
  cidade?: string;
  matricula_imovel?: string;
}

interface AnaliseJuridica {
  id: string;
  imovel_id?: string;
  tipo_documento?: string;
  riscos_identificados: { tipo: string; descricao: string; nivel: string }[];
  pendencias: { descricao: string; acao_requerida: string }[];
  recomendacoes: { descricao: string; prioridade: string }[];
  necessidade_revisao: boolean;
  analise_ia?: string;
  resumo_executivo?: string;
  criado_em: string;
}

const nivelColors: Record<string, string> = {
  baixo: "bg-blue-100 text-blue-800",
  medio: "bg-yellow-100 text-yellow-800",
  alto: "bg-orange-100 text-orange-800",
  critico: "bg-red-100 text-red-800",
};

export default function IAAnaliseJuridica() {
  const [imoveis, setImoveis] = useState<Imovel[]>([]);
  const [selectedImovel, setSelectedImovel] = useState("");
  const [tipoDoc, setTipoDoc] = useState("");
  const [conteudo, setConteudo] = useState("");
  const [loading, setLoading] = useState(false);
  const [analise, setAnalise] = useState<AnaliseJuridica | null>(null);
  const [historico, setHistorico] = useState<AnaliseJuridica[]>([]);

  useEffect(() => {
    apiFetch("/api/imoveis?page=1&pageSize=100")
      .then((d) => setImoveis(d.items || []))
      .catch(() => {});
  }, []);

  const handleAnalisar = async () => {
    setLoading(true);
    try {
      const result = await analisarJuridico({
        imovel_id: selectedImovel || undefined,
        tipo_documento: tipoDoc || undefined,
        conteudo: conteudo || undefined,
      });
      setAnalise(result);
      if (selectedImovel) {
        const hist = await buscarAnalisesJuridicasImovel(selectedImovel);
        setHistorico(hist.analises || []);
      }
    } catch (e: any) {
      alert(e.message || "Erro na análise");
    } finally {
      setLoading(false);
    }
  };

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gray-50/80">
        <div className="container py-8">
          <div className="flex items-center gap-3 mb-6">
            <Scale className="h-8 w-8 text-rose-500" />
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Análise Jurídica IA</h1>
              <p className="text-sm text-gray-500">Verificação de documentos, ônus e gravames</p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Inputs */}
            <div className="lg:col-span-1">
              <Card>
                <CardHeader><CardTitle className="text-base">Dados para Análise</CardTitle></CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <Label>Imóvel (opcional)</Label>
                    <Select value={selectedImovel} onValueChange={(v) => setSelectedImovel(v)}>
                      <SelectTrigger><SelectValue placeholder="Qualquer imóvel" /></SelectTrigger>
                      <SelectContent>
                        {imoveis.map((im) => (
                          <SelectItem key={im.id} value={im.id}>
                            {im.codigo} — {im.titulo}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Tipo de documento</Label>
                    <Select value={tipoDoc} onValueChange={setTipoDoc}>
                      <SelectTrigger><SelectValue placeholder="Selecione" /></SelectTrigger>
                      <SelectContent>
                        {["matricula", "escritura", "contrato_compra_venda", "certidao_negativa", "certidao_onus_reais", "contrato_locacao", "outro"].map((t) => (
                          <SelectItem key={t} value={t}>{t}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Conteúdo / Observações</Label>
                    <textarea
                      className="w-full h-32 px-3 py-2 text-sm border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-rose-200"
                      value={conteudo}
                      onChange={(e) => setConteudo(e.target.value)}
                      placeholder="Cole o conteúdo do documento ou observações..."
                    />
                  </div>
                  <Button className="w-full bg-rose-600 hover:bg-rose-700" onClick={handleAnalisar} disabled={loading}>
                    {loading ? "Analisando..." : (
                      <>
                        <Scale className="h-4 w-4 mr-2" />
                        Analisar Documento
                      </>
                    )}
                  </Button>
                </CardContent>
              </Card>
            </div>

            {/* Resultado */}
            <div className="lg:col-span-2">
              {!analise ? (
                <Card className="h-64 flex items-center justify-center">
                  <CardContent>
                    <div className="text-center text-gray-400">
                      <Scale className="h-12 w-12 mx-auto mb-3 opacity-50" />
                      <p>Preencha os dados e clique em "Analisar Documento"</p>
                    </div>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-4">
                  {/* Resumo Executivo */}
                  {analise.resumo_executivo && (
                    <Card className="border-rose-200 bg-rose-50/30">
                      <CardContent className="pt-4">
                        <p className="text-sm text-rose-800"><FileText className="h-4 w-4 inline mr-1" /> {analise.resumo_executivo}</p>
                      </CardContent>
                    </Card>
                  )}

                  {/* Riscos */}
                  <Card>
                    <CardHeader><CardTitle className="text-base flex items-center gap-2">
                      <AlertTriangle className="h-5 w-5 text-amber-500" /> Riscos Identificados
                    </CardTitle></CardHeader>
                    <CardContent>
                      {analise.riscos_identificados.length === 0 ? (
                        <p className="text-sm text-gray-500">Nenhum risco identificado.</p>
                      ) : (
                        <div className="space-y-2">
                          {analise.riscos_identificados.map((r, i) => (
                            <div key={i} className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg">
                              <span className={`text-xs px-2 py-1 rounded-full font-medium ${nivelColors[r.nivel] || nivelColors.baixo}`}>
                                {r.nivel}
                              </span>
                              <div>
                                <p className="text-sm font-medium text-gray-900">{r.tipo}</p>
                                <p className="text-xs text-gray-600">{r.descricao}</p>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </CardContent>
                  </Card>

                  {/* Pendências */}
                  <Card>
                    <CardHeader><CardTitle className="text-base flex items-center gap-2">
                      <AlertCircle className="h-5 w-5 text-blue-500" /> Pendências
                    </CardTitle></CardHeader>
                    <CardContent>
                      {analise.pendencias.length === 0 ? (
                        <p className="text-sm text-gray-500 flex items-center gap-1"><CheckCircle2 className="h-4 w-4 text-emerald-500" /> Nenhuma pendência.</p>
                      ) : (
                        <div className="space-y-2">
                          {analise.pendencias.map((p, i) => (
                            <div key={i} className="p-3 bg-blue-50 rounded-lg">
                              <p className="text-sm text-blue-800"><strong>Pendência:</strong> {p.descricao}</p>
                              <p className="text-xs text-blue-600"><strong>Ação:</strong> {p.acao_requerida}</p>
                            </div>
                          ))}
                        </div>
                      )}
                    </CardContent>
                  </Card>

                  {/* Recomendações */}
                  <Card>
                    <CardHeader><CardTitle className="text-base flex items-center gap-2">
                      <CheckCircle2 className="h-5 w-5 text-emerald-500" /> Recomendações
                    </CardTitle></CardHeader>
                    <CardContent>
                      <div className="space-y-2">
                        {analise.recomendacoes.map((r, i) => (
                          <div key={i} className="flex items-start gap-2">
                            <span className="text-xs text-emerald-600 font-medium mt-0.5">{r.prioridade}</span>
                            <p className="text-sm text-gray-700">{r.descricao}</p>
                          </div>
                        ))}
                      </div>
                      {analise.necessidade_revisao && (
                        <div className="mt-4 p-3 bg-amber-50 border border-amber-200 rounded-lg">
                          <p className="text-sm text-amber-800">
                            <AlertTriangle className="h-4 w-4 inline mr-1" />
                            <strong>Revisão humana necessária</strong> — Encaminhe para um advogado verificar esta análise.
                          </p>
                        </div>
                      )}
                    </CardContent>
                  </Card>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}
