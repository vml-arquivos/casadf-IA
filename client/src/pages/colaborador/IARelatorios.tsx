import { useState } from "react";
import { BarChart3, Lightbulb, Sparkles, Download } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import ProtectedRoute from "@/components/ProtectedRoute";
import { gerarRelatorioInteligente } from "@/lib/api-imoveis";

interface Insight {
  titulo: string;
  descricao: string;
  impacto: string;
}

interface Recomendacao {
  descricao: string;
  prioridade: string;
}

const tiposRelatorio = [
  { value: "funil", label: "Funil de Vendas" },
  { value: "leads", label: "Análise de Leads" },
  { value: "imoveis", label: "Catálogo de Imóveis" },
  { value: "vendas", label: "Performance de Vendas" },
  { value: "financeiro", label: "Financeiro" },
];

export default function IARelatorios() {
  const [tipo, setTipo] = useState("funil");
  const [periodoInicio, setPeriodoInicio] = useState("");
  const [periodoFim, setPeriodoFim] = useState("");
  const [loading, setLoading] = useState(false);
  const [relatorio, setRelatorio] = useState<any>(null);
  const [insights, setInsights] = useState<Insight[]>([]);
  const [recomendacoes, setRecomendacoes] = useState<Recomendacao[]>([]);

  const handleGerar = async () => {
    setLoading(true);
    try {
      const result = await gerarRelatorioInteligente(tipo, periodoInicio || undefined, periodoFim || undefined);
      setRelatorio(result.relatorio);
      setInsights(result.insights || []);
      setRecomendacoes(result.recomendacoes || []);
    } catch (e: any) {
      alert(e.message || "Erro ao gerar relatório");
    } finally {
      setLoading(false);
    }
  };

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gray-50/80">
        <div className="container py-8">
          <div className="flex items-center gap-3 mb-6">
            <BarChart3 className="h-8 w-8 text-green-500" />
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Relatórios Inteligentes</h1>
              <p className="text-sm text-gray-500">Dashboards com insights e recomendações de IA</p>
            </div>
          </div>

          {/* Configuração */}
          <Card className="mb-6">
            <CardContent className="pt-6">
              <div className="flex flex-col md:flex-row items-end gap-4">
                <div className="flex-1 w-full">
                  <label className="text-sm font-medium text-gray-700 mb-1 block">Tipo de relatório</label>
                  <Select value={tipo} onValueChange={setTipo}>
                    <SelectTrigger><SelectValue placeholder="Selecione" /></SelectTrigger>
                    <SelectContent>
                      {tiposRelatorio.map((t) => (
                        <SelectItem key={t.value} value={t.value}>{t.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700 mb-1 block">Início</label>
                  <input
                    type="date"
                    value={periodoInicio}
                    onChange={(e) => setPeriodoInicio(e.target.value)}
                    className="px-3 py-2 text-sm border border-gray-200 rounded-md"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700 mb-1 block">Fim</label>
                  <input
                    type="date"
                    value={periodoFim}
                    onChange={(e) => setPeriodoFim(e.target.value)}
                    className="px-3 py-2 text-sm border border-gray-200 rounded-md"
                  />
                </div>
                <Button className="bg-green-600 hover:bg-green-700" onClick={handleGerar} disabled={loading}>
                  {loading ? "Gerando..." : (
                    <>
                      <Sparkles className="h-4 w-4 mr-2" />
                      Gerar Relatório
                    </>
                  )}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Resultados */}
          {!relatorio ? (
            <Card className="h-48 flex items-center justify-center">
              <CardContent>
                <div className="text-center text-gray-400">
                  <BarChart3 className="h-12 w-12 mx-auto mb-3 opacity-50" />
                  <p>Selecione um tipo e clique em "Gerar Relatório"</p>
                </div>
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-6">
              {/* Dados do relatório */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-base flex items-center gap-2">
                    <BarChart3 className="h-5 w-5 text-green-500" />
                    Dados — {tiposRelatorio.find((t) => t.value === tipo)?.label}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <pre className="text-xs bg-gray-50 p-4 rounded-lg overflow-auto max-h-48">
                    {JSON.stringify(relatorio.dados, null, 2)}
                  </pre>
                </CardContent>
              </Card>

              {/* Insights */}
              {insights.length > 0 && (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base flex items-center gap-2">
                      <Lightbulb className="h-5 w-5 text-yellow-500" /> Insights
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-3">
                      {insights.map((ins, i) => (
                        <div key={i} className="p-4 bg-yellow-50 rounded-lg border border-yellow-200">
                          <div className="flex items-center justify-between mb-2">
                            <h4 className="font-semibold text-gray-900 text-sm">{ins.titulo}</h4>
                            <span className={`text-xs px-2 py-0.5 rounded-full ${
                              ins.impacto === "alto" ? "bg-red-100 text-red-700" :
                              ins.impacto === "medio" ? "bg-yellow-100 text-yellow-700" :
                              "bg-green-100 text-green-700"
                            }`}>
                              {ins.impacto}
                            </span>
                          </div>
                          <p className="text-sm text-gray-600">{ins.descricao}</p>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              )}

              {/* Recomendações */}
              {recomendacoes.length > 0 && (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base flex items-center gap-2">
                      <Sparkles className="h-5 w-5 text-purple-500" /> Recomendações
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-2">
                      {recomendacoes.map((rec, i) => (
                        <div key={i} className="flex items-start gap-3 p-3 bg-purple-50 rounded-lg">
                          <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                            rec.prioridade === "alta" ? "bg-red-100 text-red-700" :
                            rec.prioridade === "media" ? "bg-yellow-100 text-yellow-700" :
                            "bg-green-100 text-green-700"
                          }`}>
                            {rec.prioridade}
                          </span>
                          <p className="text-sm text-gray-700">{rec.descricao}</p>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>
          )}
        </div>
      </div>
    </ProtectedRoute>
  );
}
