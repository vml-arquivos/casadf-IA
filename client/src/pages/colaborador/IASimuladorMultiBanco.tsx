import { useState } from "react";
import { Calculator, TrendingDown, TrendingUp, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import ProtectedRoute from "@/components/ProtectedRoute";
import { simularMultiBanco, formatarMoeda } from "@/lib/api-imoveis";

interface SimulacaoResultado {
  banco: string;
  chave: string;
  cor: string;
  sistema: string;
  taxa_juros_mensal: number;
  taxa_seguro: number;
  taxa_sf: number;
  valor_financiamento: number;
  parcela_mensal: number;
  total_juros: number;
  total_seguro: number;
  total_pago: number;
}

export default function IASimuladorMultiBanco() {
  const [valorImovel, setValorImovel] = useState("");
  const [entrada, setEntrada] = useState("");
  const [prazoMeses, setPrazoMeses] = useState("360");
  const [loading, setLoading] = useState(false);
  const [resultados, setResultados] = useState<Record<string, SimulacaoResultado>>({});
  const [recomendacao, setRecomendacao] = useState<any>(null);

  const handleSimular = async () => {
    if (!valorImovel || !prazoMeses) return;
    setLoading(true);
    try {
      const result = await simularMultiBanco({
        valor_imovel: Number(valorImovel),
        entrada: Number(entrada) || 0,
        prazo_meses: Number(prazoMeses),
      });
      setResultados(result.resultados || {});
      setRecomendacao(result.recomendacao || null);
    } catch (e: any) {
      alert(e.message || "Erro na simulação");
    } finally {
      setLoading(false);
    }
  };

  const entries = Object.entries(resultados);
  const melhorParcela = entries.reduce((acc, [, v]) => (!acc || v.parcela_mensal < acc.parcela_mensal ? v : acc), entries[0]?.[1] || null);
  const melhorCusto = entries.reduce((acc, [, v]) => (!acc || v.total_pago < acc.total_pago ? v : acc), entries[0]?.[1] || null);

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gray-50/80">
        <div className="container py-8">
          <div className="flex items-center gap-3 mb-6">
            <Calculator className="h-8 w-8 text-amber-500" />
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Simulador Multi-Banco</h1>
              <p className="text-sm text-gray-500">Compare financiamentos em 6 bancos simultaneamente</p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Inputs */}
            <div className="lg:col-span-1">
              <Card>
                <CardHeader><CardTitle className="text-base">Dados da Simulação</CardTitle></CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <Label>Valor do imóvel (R$)</Label>
                    <Input type="number" value={valorImovel} onChange={(e) => setValorImovel(e.target.value)} placeholder="800000" />
                  </div>
                  <div>
                    <Label>Entrada (R$)</Label>
                    <Input type="number" value={entrada} onChange={(e) => setEntrada(e.target.value)} placeholder="200000" />
                  </div>
                  <div>
                    <Label>Prazo (meses)</Label>
                    <Input type="number" value={prazoMeses} onChange={(e) => setPrazoMeses(e.target.value)} placeholder="360" />
                  </div>
                  <Button className="w-full bg-amber-600 hover:bg-amber-700" onClick={handleSimular} disabled={loading}>
                    {loading ? "Simulando..." : (
                      <>
                        <Calculator className="h-4 w-4 mr-2" />
                        Simular Todos os Bancos
                      </>
                    )}
                  </Button>
                </CardContent>
              </Card>

              {recomendacao && (
                <Card className="mt-4 border-amber-200 bg-amber-50/50">
                  <CardHeader><CardTitle className="text-sm">Recomendação IA</CardTitle></CardHeader>
                  <CardContent>
                    <p className="text-sm text-amber-800">{recomendacao.recomendacao}</p>
                    {recomendacao.observacoes && (
                      <p className="text-xs text-amber-600 mt-2">{recomendacao.observacoes}</p>
                    )}
                  </CardContent>
                </Card>
              )}
            </div>

            {/* Resultados */}
            <div className="lg:col-span-2">
              {entries.length === 0 ? (
                <Card className="h-64 flex items-center justify-center">
                  <CardContent>
                    <div className="text-center text-gray-400">
                      <Calculator className="h-12 w-12 mx-auto mb-3 opacity-50" />
                      <p>Preencha os dados e clique em "Simular"</p>
                    </div>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-3">
                  {entries.map(([key, sim]) => {
                    const isBestParcela = sim.chave === melhorParcela?.chave;
                    const isBestCusto = sim.chave === melhorCusto?.chave;
                    return (
                      <Card key={key} className={`border-l-4 ${isBestCusto ? "border-l-emerald-500" : "border-l-gray-200"} transition-shadow hover:shadow-md`}>
                        <CardContent className="pt-4">
                          <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
                            <div className="flex items-center gap-3">
                              <div className="w-10 h-10 rounded-lg flex items-center justify-center text-white text-xs font-bold" style={{ backgroundColor: sim.cor }}>
                                {sim.banco.slice(0, 3).toUpperCase()}
                              </div>
                              <div>
                                <p className="font-semibold text-gray-900">{sim.banco}</p>
                                <p className="text-xs text-gray-500">{sim.sistema} · {sim.taxa_juros_mensal.toFixed(3)}% a.m.</p>
                              </div>
                              {isBestCusto && <CheckCircle2 className="h-5 w-5 text-emerald-500" />}
                            </div>
                            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                              <div>
                                <p className="text-gray-500">Parcela</p>
                                <p className={`font-bold ${isBestParcela ? "text-emerald-600" : "text-gray-900"}`}>
                                  {formatarMoeda(sim.parcela_mensal)}
                                </p>
                              </div>
                              <div>
                                <p className="text-gray-500">Total Juros</p>
                                <p className="font-bold text-gray-900">{formatarMoeda(sim.total_juros)}</p>
                              </div>
                              <div>
                                <p className="text-gray-500">Total Seguro</p>
                                <p className="font-bold text-gray-900">{formatarMoeda(sim.total_seguro)}</p>
                              </div>
                              <div>
                                <p className="text-gray-500">Total Pago</p>
                                <p className={`font-bold ${isBestCusto ? "text-emerald-600" : "text-gray-900"}`}>
                                  {formatarMoeda(sim.total_pago)}
                                </p>
                              </div>
                            </div>
                          </div>
                        </CardContent>
                      </Card>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}
