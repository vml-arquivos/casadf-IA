import { useState, useEffect } from "react";
import { Search, TrendingUp, ArrowRight } from "lucide-react";
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
import { calcularLeadScore, buscarLeadScore, formatarMoeda } from "@/lib/api-imoveis";

interface Lead {
  id: string;
  nome_completo?: string;
  nome?: string;
  email?: string;
  telefone?: string;
  etapa_funil?: string;
  temperatura?: string;
  valor_solicitado?: number;
  empresa_id?: string;
}

interface ScoreResult {
  id: string;
  score: number;
  classificacao: string;
  fatores: Record<string, number>;
  detalhes: Record<string, any>;
  observacoes_ia?: string;
}

const classificacaoColors: Record<string, string> = {
  frio: "bg-blue-100 text-blue-800 border-blue-200",
  morno: "bg-yellow-100 text-yellow-800 border-yellow-200",
  quente: "bg-orange-100 text-orange-800 border-orange-200",
  urgente: "bg-red-100 text-red-800 border-red-200",
  vip: "bg-purple-100 text-purple-800 border-purple-200",
};

export default function IALeadScore() {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [selectedLead, setSelectedLead] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [scoreResult, setScoreResult] = useState<ScoreResult | null>(null);
  const [extraRenda, setExtraRenda] = useState("");
  const [extraBairro, setExtraBairro] = useState("");
  const [extraTipoImovel, setExtraTipoImovel] = useState("");
  const [extraValorDesejado, setExtraValorDesejado] = useState("");
  const [extraEntrada, setExtraEntrada] = useState("");
  const [extraUrgencia, setExtraUrgencia] = useState("");

  useEffect(() => {
    apiFetch("/api/leads?page=1&pageSize=100")
      .then((d) => setLeads(d.items || []))
      .catch(() => {});
  }, []);

  const handleCalculate = async () => {
    if (!selectedLead) return;
    setLoading(true);
    try {
      const result = await calcularLeadScore(selectedLead, {
        renda: extraRenda ? Number(extraRenda) : undefined,
        bairro_interesse: extraBairro || undefined,
        tipo_imovel: extraTipoImovel || undefined,
        valor_desejado: extraValorDesejado ? Number(extraValorDesejado) : undefined,
        entrada_disponivel: extraEntrada ? Number(extraEntrada) : undefined,
        urgencia: extraUrgencia || undefined,
      });
      setScoreResult(result);
    } catch (e: any) {
      alert(e.message || "Erro ao calcular score");
    } finally {
      setLoading(false);
    }
  };

  const selectedLeadData = leads.find((l) => l.id === selectedLead);

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gray-50/80">
        <div className="container py-8">
          <div className="flex items-center gap-3 mb-6">
            <Search className="h-8 w-8 text-emerald-500" />
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Lead Score IA</h1>
              <p className="text-sm text-gray-500">Qualificação automática de leads</p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Left: Seleção + Inputs */}
            <div className="lg:col-span-1 space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle className="text-base">Selecionar Lead</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <Label>Lead</Label>
                    <Select value={selectedLead} onValueChange={(v) => { setSelectedLead(v); setScoreResult(null); }}>
                      <SelectTrigger>
                        <SelectValue placeholder="Escolha um lead" />
                      </SelectTrigger>
                      <SelectContent>
                        {leads.map((l) => (
                          <SelectItem key={l.id} value={l.id}>
                            {l.nome_completo || l.nome || "Sem nome"} — {l.etapa_funil || "N/A"}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  {selectedLeadData && (
                    <div className="bg-gray-50 rounded-lg p-3 text-sm space-y-1">
                      <p><strong>Nome:</strong> {selectedLeadData.nome_completo || selectedLeadData.nome}</p>
                      <p><strong>Etapa:</strong> {selectedLeadData.etapa_funil || "—"}</p>
                      <p><strong>Temperatura:</strong> {selectedLeadData.temperatura || "—"}</p>
                      <p><strong>Valor:</strong> {formatarMoeda(selectedLeadData.valor_solicitado)}</p>
                    </div>
                  )}

                  <div className="border-t pt-4 space-y-3">
                    <p className="text-xs font-semibold text-gray-600 uppercase tracking-wide">Dados extras (opcional)</p>
                    <div>
                      <Label className="text-xs">Renda mensal estimada</Label>
                      <Input value={extraRenda} onChange={(e) => setExtraRenda(e.target.value)} placeholder="R$ 15.000" />
                    </div>
                    <div>
                      <Label className="text-xs">Bairro de interesse</Label>
                      <Input value={extraBairro} onChange={(e) => setExtraBairro(e.target.value)} placeholder="Asa Sul" />
                    </div>
                    <div>
                      <Label className="text-xs">Tipo de imóvel desejado</Label>
                      <Select value={extraTipoImovel} onValueChange={setExtraTipoImovel}>
                        <SelectTrigger><SelectValue placeholder="Qualquer" /></SelectTrigger>
                        <SelectContent>
                          {["casa", "apartamento", "cobertura", "terreno", "sala_comercial", "loja"].map((t) => (
                            <SelectItem key={t} value={t}>{t}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div>
                      <Label className="text-xs">Valor desejado</Label>
                      <Input value={extraValorDesejado} onChange={(e) => setExtraValorDesejado(e.target.value)} placeholder="R$ 800.000" />
                    </div>
                    <div>
                      <Label className="text-xs">Entrada disponível</Label>
                      <Input value={extraEntrada} onChange={(e) => setExtraEntrada(e.target.value)} placeholder="R$ 200.000" />
                    </div>
                    <div>
                      <Label className="text-xs">Urgência</Label>
                      <Select value={extraUrgencia} onValueChange={setExtraUrgencia}>
                        <SelectTrigger><SelectValue placeholder="Auto" /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="baixa">Baixa</SelectItem>
                          <SelectItem value="media">Média</SelectItem>
                          <SelectItem value="alta">Alta</SelectItem>
                          <SelectItem value="urgente">Urgente</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <Button className="w-full bg-emerald-600 hover:bg-emerald-700" onClick={handleCalculate} disabled={!selectedLead || loading}>
                    {loading ? "Calculando..." : (
                      <>
                        <TrendingUp className="h-4 w-4 mr-2" />
                        Calcular Lead Score
                      </>
                    )}
                  </Button>
                </CardContent>
              </Card>
            </div>

            {/* Right: Resultado */}
            <div className="lg:col-span-2">
              {!scoreResult ? (
                <Card className="h-64 flex items-center justify-center">
                  <CardContent>
                    <div className="text-center text-gray-400">
                      <Search className="h-12 w-12 mx-auto mb-3 opacity-50" />
                      <p>Selecione um lead e clique em "Calcular Lead Score"</p>
                    </div>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-4">
                  {/* Score Principal */}
                  <Card className="border-emerald-200">
                    <CardContent className="pt-6">
                      <div className="flex items-center gap-6">
                        <div className="relative">
                          <svg className="w-32 h-32" viewBox="0 0 120 120">
                            <circle cx="60" cy="60" r="52" fill="none" stroke="#e5e7eb" strokeWidth="8" />
                            <circle
                              cx="60" cy="60" r="52" fill="none"
                              stroke={scoreResult.score > 70 ? "#10b981" : scoreResult.score > 40 ? "#f59e0b" : "#ef4444"}
                              strokeWidth="8"
                              strokeDasharray={`${(scoreResult.score / 100) * 326.7} 326.7`}
                              strokeLinecap="round"
                              transform="rotate(-90 60 60)"
                            />
                          </svg>
                          <div className="absolute inset-0 flex items-center justify-center">
                            <span className="text-3xl font-bold text-gray-900">{Math.round(scoreResult.score)}</span>
                          </div>
                        </div>
                        <div>
                          <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium border ${classificacaoColors[scoreResult.classificacao] || classificacaoColors.morno}`}>
                            {scoreResult.classificacao.toUpperCase()}
                          </span>
                          <p className="text-sm text-gray-500 mt-2">{scoreResult.observacoes_ia}</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  {/* Fatores */}
                  <Card>
                    <CardHeader><CardTitle className="text-base">Fatores de Qualificação</CardTitle></CardHeader>
                    <CardContent>
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        {Object.entries(scoreResult.fatores).map(([key, value]) => (
                          <div key={key} className="text-center">
                            <p className="text-2xl font-bold text-gray-900">{typeof value === "number" ? (value * 100).toFixed(0) + "%" : value}</p>
                            <p className="text-xs text-gray-500 capitalize">{key}</p>
                          </div>
                        ))}
                      </div>
                    </CardContent>
                  </Card>

                  {/* Detalhes */}
                  <Card>
                    <CardHeader><CardTitle className="text-base">Detalhes</CardTitle></CardHeader>
                    <CardContent>
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        {Object.entries(scoreResult.detalhes).map(([key, val]) => (
                          <div key={key}>
                            <p className="text-gray-500 capitalize">{key}</p>
                            <p className="font-medium">{typeof val === "number" ? formatarMoeda(val) : String(val)}</p>
                          </div>
                        ))}
                      </div>
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
