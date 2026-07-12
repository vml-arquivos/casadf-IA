import { useState, useEffect } from "react";
import { TrendingUp, DollarSign, Shield, AlertTriangle, CheckCircle2 } from "lucide-react";
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
import { analisarFinanceiro, buscarAnalisesFinanceiras, formatarMoeda } from "@/lib/api-imoveis";

interface Lead {
  id: string;
  nome_completo?: string;
  nome?: string;
  etapa_funil?: string;
  valor_solicitado?: number;
}

interface AnaliseFinanceira {
  id: string;
  renda_mensal?: number;
  capacidade_compra: number;
  comprometimento_renda: number;
  entrada_necessaria: number;
  prazo_ideal_meses: number;
  risco_aprovacao: string;
  perfil_financeiro: Record<string, any>;
  recomendacao_ia?: string;
  criado_em: string;
}

const riscoColors: Record<string, string> = {
  baixo: "bg-emerald-100 text-emerald-800",
  medio: "bg-yellow-100 text-yellow-800",
  alto: "bg-orange-100 text-orange-800",
  muito_alto: "bg-red-100 text-red-800",
};

export default function IAAnaliseFinanceira() {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [selectedLead, setSelectedLead] = useState("");
  const [renda, setRenda] = useState("");
  const [compromissos, setCompromissos] = useState("");
  const [loading, setLoading] = useState(false);
  const [analise, setAnalise] = useState<AnaliseFinanceira | null>(null);
  const [historico, setHistorico] = useState<AnaliseFinanceira[]>([]);

  useEffect(() => {
    apiFetch("/api/leads?page=1&pageSize=100")
      .then((d) => setLeads(d.items || []))
      .catch(() => {});
  }, []);

  const handleAnalisar = async () => {
    if (!selectedLead) return;
    setLoading(true);
    try {
      const result = await analisarFinanceiro({
        lead_id: selectedLead,
        renda_mensal: renda ? Number(renda) : undefined,
        compromissos_mensais: compromissos ? Number(compromissos) : undefined,
      });
      setAnalise(result);
      const hist = await buscarAnalisesFinanceiras(selectedLead);
      setHistorico(hist.analises || []);
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
            <TrendingUp className="h-8 w-8 text-cyan-500" />
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Análise Financeira IA</h1>
              <p className="text-sm text-gray-500">Capacidade de compra e risco de aprovação</p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Inputs */}
            <div className="lg:col-span-1">
              <Card>
                <CardHeader><CardTitle className="text-base">Dados Financeiros</CardTitle></CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <Label>Lead</Label>
                    <Select value={selectedLead} onValueChange={(v) => { setSelectedLead(v); setAnalise(null); }}>
                      <SelectTrigger><SelectValue placeholder="Escolha um lead" /></SelectTrigger>
                      <SelectContent>
                        {leads.map((l) => (
                          <SelectItem key={l.id} value={l.id}>
                            {l.nome_completo || l.nome || "Sem nome"}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Renda mensal (R$)</Label>
                    <Input type="number" value={renda} onChange={(e) => setRenda(e.target.value)} placeholder="15000" />
                  </div>
                  <div>
                    <Label>Compromissos mensais (R$)</Label>
                    <Input type="number" value={compromissos} onChange={(e) => setCompromissos(e.target.value)} placeholder="3000" />
                  </div>
                  <Button className="w-full bg-cyan-600 hover:bg-cyan-700" onClick={handleAnalisar} disabled={!selectedLead || loading}>
                    {loading ? "Analisando..." : (
                      <>
                        <DollarSign className="h-4 w-4 mr-2" />
                        Analisar Financeiro
                      </>
                    )}
                  </Button>
                </CardContent>
              </Card>

              {/* Histórico */}
              {historico.length > 0 && (
                <Card className="mt-4">
                  <CardHeader><CardTitle className="text-sm">Histórico ({historico.length})</CardTitle></CardHeader>
                  <CardContent>
                    <div className="space-y-2">
                      {historico.slice(0, 5).map((h) => (
                        <div key={h.id} className="flex items-center justify-between text-xs">
                          <span className="text-gray-500">{new Date(h.criado_em).toLocaleDateString("pt-BR")}</span>
                          <span className={`px-2 py-0.5 rounded-full ${riscoColors[h.risco_aprovacao] || ""}`}>
                            {h.risco_aprovacao}
                          </span>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>

            {/* Resultado */}
            <div className="lg:col-span-2">
              {!analise ? (
                <Card className="h-64 flex items-center justify-center">
                  <CardContent>
                    <div className="text-center text-gray-400">
                      <TrendingUp className="h-12 w-12 mx-auto mb-3 opacity-50" />
                      <p>Selecione um lead e clique em "Analisar Financeiro"</p>
                    </div>
                  </CardContent>
                </Card>
              ) : (
                <div className="space-y-4">
                  {/* Cards de métrica */}
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                    {[
                      { label: "Capacidade de Compra", value: formatarMoeda(analise.capacidade_compra), icon: DollarSign, color: "text-emerald-600" },
                      { label: "Comprometimento", value: `${analise.comprometimento_renda}%`, icon: TrendingUp, color: "text-blue-600" },
                      { label: "Entrada Necessária", value: formatarMoeda(analise.entrada_necessaria), icon: Shield, color: "text-amber-600" },
                      { label: "Prazo Ideal", value: `${analise.prazo_ideal_meses} meses`, icon: TrendingUp, color: "text-purple-600" },
                    ].map((m) => (
                      <Card key={m.label}>
                        <CardContent className="pt-4 text-center">
                          <m.icon className={`h-6 w-6 mx-auto mb-2 ${m.color}`} />
                          <p className="text-lg font-bold text-gray-900">{m.value}</p>
                          <p className="text-xs text-gray-500">{m.label}</p>
                        </CardContent>
                      </Card>
                    ))}
                  </div>

                  {/* Risco */}
                  <Card className="border-l-4" style={{ borderLeftColor: analise.risco_aprovacao === "baixo" ? "#10b981" : analise.risco_aprovacao === "medio" ? "#f59e0b" : "#ef4444" }}>
                    <CardContent className="pt-4">
                      <div className="flex items-center gap-3">
                        <span className={`px-3 py-1 rounded-full text-sm font-medium ${riscoColors[analise.risco_aprovacao] || ""}`}>
                          Risco: {analise.risco_aprovacao}
                        </span>
                        {analise.risco_aprovacao === "baixo" && <CheckCircle2 className="h-5 w-5 text-emerald-500" />}
                        {analise.risco_aprovacao === "medio" && <Shield className="h-5 w-5 text-yellow-500" />}
                        {(analise.risco_aprovacao === "alto" || analise.risco_aprovacao === "muito_alto") && <AlertTriangle className="h-5 w-5 text-red-500" />}
                      </div>
                    </CardContent>
                  </Card>

                  {/* Perfil */}
                  <Card>
                    <CardHeader><CardTitle className="text-base">Perfil Financeiro</CardTitle></CardHeader>
                    <CardContent>
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        {Object.entries(analise.perfil_financeiro).map(([k, v]) => (
                          <div key={k}>
                            <p className="text-gray-500 capitalize">{k}</p>
                            <p className="font-medium text-gray-900">{String(v)}</p>
                          </div>
                        ))}
                      </div>
                    </CardContent>
                  </Card>

                  {/* Recomendação */}
                  {analise.recomendacao_ia && (
                    <Card className="bg-emerald-50/50 border-emerald-200">
                      <CardContent className="pt-4">
                        <p className="text-sm text-emerald-800">
                          <CheckCircle2 className="h-4 w-4 inline mr-1" />
                          {analise.recomendacao_ia}
                        </p>
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
