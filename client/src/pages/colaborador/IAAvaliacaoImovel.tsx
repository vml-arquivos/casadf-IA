import { useState, useEffect } from "react";
import { Home, TrendingUp, Minus, Plus, MapPin } from "lucide-react";
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
import { apiFetch } from "@/lib/api";
import { avaliarImovelApi, buscarAvaliacoesImovel, formatarMoeda } from "@/lib/api-imoveis";

interface Imovel {
  id: string;
  codigo: string;
  titulo: string;
  valor_venda?: number;
  valor_locacao?: number;
  area_privativa?: number;
  quartos?: number;
  bairro?: string;
  cidade?: string;
}

interface Avaliacao {
  id: string;
  valor_estimado: number;
  valor_minimo?: number;
  valor_maximo?: number;
  metodo?: string;
  fatores_avaliacao: Record<string, number>;
  imoveis_comparaveis: { endereco: string; valor: number; diferenca_percentual: number }[];
  metodologia_descricao?: string;
  margem_confianca?: number;
  criado_em: string;
}

export default function IAAvaliacaoImovel() {
  const [imoveis, setImoveis] = useState<Imovel[]>([]);
  const [selectedImovel, setSelectedImovel] = useState("");
  const [loading, setLoading] = useState(false);
  const [avaliacao, setAvaliacao] = useState<Avaliacao | null>(null);
  const [historico, setHistorico] = useState<Avaliacao[]>([]);

  useEffect(() => {
    apiFetch("/api/imoveis?page=1&pageSize=100")
      .then((d) => setImoveis(d.items || []))
      .catch(() => {});
  }, []);

  const handleAvaliar = async () => {
    if (!selectedImovel) return;
    setLoading(true);
    try {
      const result = await avaliarImovelApi(selectedImovel);
      setAvaliacao(result);
      const hist = await buscarAvaliacoesImovel(selectedImovel);
      setHistorico(hist.avaliacoes || []);
    } catch (e: any) {
      alert(e.message || "Erro na avaliação");
    } finally {
      setLoading(false);
    }
  };

  const selectedImovelData = imoveis.find((im) => im.id === selectedImovel);

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gray-50/80">
        <div className="container py-8">
          <div className="flex items-center gap-3 mb-6">
            <Home className="h-8 w-8 text-pink-500" />
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Avaliação de Imóveis IA</h1>
              <p className="text-sm text-gray-500">Valor estimado com método comparativo</p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Inputs */}
            <div className="lg:col-span-1">
              <Card>
                <CardHeader><CardTitle className="text-base">Selecionar Imóvel</CardTitle></CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <Select value={selectedImovel} onValueChange={(v) => { setSelectedImovel(v); setAvaliacao(null); }}>
                      <SelectTrigger><SelectValue placeholder="Escolha um imóvel" /></SelectTrigger>
                      <SelectContent>
                        {imoveis.map((im) => (
                          <SelectItem key={im.id} value={im.id}>
                            {im.codigo} — {im.titulo}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  {selectedImovelData && (
                    <div className="bg-gray-50 rounded-lg p-3 text-sm space-y-1">
                      <p><strong>{selectedImovelData.titulo}</strong></p>
                      <p className="text-gray-500">{selectedImovelData.bairro}, {selectedImovelData.cidade}</p>
                      <p className="text-gray-500">{selectedImovelData.area_privativa}m² · {selectedImovelData.quartos} quartos</p>
                      <p className="font-bold text-gray-900">{formatarMoeda(selectedImovelData.valor_venda)}</p>
                    </div>
                  )}

                  <Button className="w-full bg-pink-600 hover:bg-pink-700" onClick={handleAvaliar} disabled={!selectedImovel || loading}>
                    {loading ? "Avaliando..." : (
                      <>
                        <Home className="h-4 w-4 mr-2" />
                        Avaliar Imóvel
                      </>
                    )}
                  </Button>
                </CardContent>
              </Card>

              {/* Histórico */}
              {historico.length > 0 && (
                <Card className="mt-4">
                  <CardHeader><CardTitle className="text-sm">Avaliações anteriores</CardTitle></CardHeader>
                  <CardContent>
                    <div className="space-y-2">
                      {historico.slice(0, 5).map((h) => (
                        <div key={h.id} className="flex justify-between text-xs">
                          <span className="text-gray-500">{new Date(h.criado_em).toLocaleDateString("pt-BR")}</span>
                          <span className="font-medium">{formatarMoeda(h.valor_estimado)}</span>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>

            {/* Resultado */}
            <div className="lg:col-span-2">
              {!avaliacao ? (
                <Card className="h-64 flex items-center justify-center">
                  <CardContent>
                    <div className="text-center text-gray-400">
                      <Home className="h-12 w-12 mx-auto mb-3 opacity-50" />
                      <p>Selecione um imóvel e clique em "Avaliar Imóvel"</p>
                    </div>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-4">
                  {/* Valor estimado */}
                  <Card className="border-pink-200">
                    <CardContent className="pt-6">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm text-gray-500">Valor Estimado</p>
                          <p className="text-3xl font-bold text-gray-900">{formatarMoeda(avaliacao.valor_estimado)}</p>
                        </div>
                        <div className="text-right">
                          <div className="flex items-center gap-2 text-sm">
                            <Minus className="h-4 w-4 text-red-500" />
                            <span className="text-gray-500">{formatarMoeda(avaliacao.valor_minimo)}</span>
                          </div>
                          <div className="flex items-center gap-2 text-sm mt-1">
                            <Plus className="h-4 w-4 text-emerald-500" />
                            <span className="text-gray-500">{formatarMoeda(avaliacao.valor_maximo)}</span>
                          </div>
                        </div>
                      </div>
                      <div className="mt-4 flex items-center gap-3">
                        <div className="relative flex-1">
                          <div className="h-3 bg-gray-200 rounded-full overflow-hidden">
                            <div
                              className="h-full bg-gradient-to-r from-pink-400 to-pink-600 rounded-full"
                              style={{ width: `${avaliacao.margem_confianca || 70}%` }}
                            />
                          </div>
                        </div>
                        <span className="text-xs text-gray-500">{avaliacao.margem_confianca}% confiança</span>
                      </div>
                    </CardContent>
                  </Card>

                  {/* Método */}
                  <Card>
                    <CardHeader><CardTitle className="text-base">Metodologia: {avaliacao.metodo}</CardTitle></CardHeader>
                    <CardContent>
                      <p className="text-sm text-gray-600">{avaliacao.metodologia_descricao}</p>
                    </CardContent>
                  </Card>

                  {/* Fatores */}
                  <Card>
                    <CardHeader><CardTitle className="text-base">Fatores de Avaliação</CardTitle></CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        {Object.entries(avaliacao.fatores_avaliacao).map(([key, value]) => (
                          <div key={key}>
                            <div className="flex justify-between text-sm mb-1">
                              <span className="capitalize text-gray-600">{key}</span>
                              <span className="font-medium">{typeof value === "number" ? (value * 100).toFixed(0) + "%" : value}</span>
                            </div>
                            <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
                              <div
                                className="h-full bg-pink-500 rounded-full"
                                style={{ width: `${typeof value === "number" ? value * 100 : 50}%` }}
                              />
                            </div>
                          </div>
                        ))}
                      </div>
                    </CardContent>
                  </Card>

                  {/* Comparáveis */}
                  {avaliacao.imoveis_comparaveis.length > 0 && (
                    <Card>
                      <CardHeader><CardTitle className="text-base">Imóveis Comparáveis</CardTitle></CardHeader>
                      <CardContent>
                        <div className="space-y-2">
                          {avaliacao.imoveis_comparaveis.map((comp, i) => (
                            <div key={i} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg text-sm">
                              <div className="flex items-center gap-2">
                                <MapPin className="h-4 w-4 text-gray-400" />
                                <span className="text-gray-700">{comp.endereco}</span>
                              </div>
                              <div className="text-right">
                                <p className="font-medium">{formatarMoeda(comp.valor)}</p>
                                <p className={`text-xs ${comp.diferenca_percentual > 0 ? "text-emerald-600" : "text-red-600"}`}>
                                  {comp.diferenca_percentual > 0 ? "+" : ""}{comp.diferenca_percentual}%
                                </p>
                              </div>
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
        </div>
      </div>
    </ProtectedRoute>
  );
}
