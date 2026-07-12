import { useState, useEffect } from "react";
import { Target, MapPin, Bed, Maximize2, Building2, ArrowRight } from "lucide-react";
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
import { encontrarMatches, formatarMoeda } from "@/lib/api-imoveis";

interface Lead {
  id: string;
  nome_completo?: string;
  nome?: string;
  etapa_funil?: string;
}

interface MatchResult {
  id: string;
  lead_id: string;
  imovel_id: string;
  score_compatibilidade: number;
  razoes: string[];
  fatores_match: Record<string, number>;
  posicao_ranking: number;
  codigo?: string;
  titulo?: string;
  tipo?: string;
  valor_venda?: number;
  valor_locacao?: number;
  bairro?: string;
  cidade?: string;
  area_privativa?: number;
  quartos?: number;
  foto_capa_url?: string;
}

const rankingColors = ["bg-yellow-400", "bg-gray-300", "bg-amber-600", "bg-blue-500", "bg-blue-600", "bg-blue-700", "bg-blue-800", "bg-blue-900", "bg-slate-500", "bg-slate-600"];

export default function IAMatchImovel() {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [selectedLead, setSelectedLead] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [matches, setMatches] = useState<MatchResult[]>([]);

  useEffect(() => {
    apiFetch("/api/leads?page=1&pageSize=100")
      .then((d) => setLeads(d.items || []))
      .catch(() => {});
  }, []);

  const handleMatch = async () => {
    if (!selectedLead) return;
    setLoading(true);
    try {
      const result = await encontrarMatches(selectedLead, 10);
      setMatches(result.matches || []);
    } catch (e: any) {
      alert(e.message || "Erro ao buscar matches");
    } finally {
      setLoading(false);
    }
  };

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gray-50/80">
        <div className="container py-8">
          <div className="flex items-center gap-3 mb-6">
            <Target className="h-8 w-8 text-blue-500" />
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Match Imóvel</h1>
              <p className="text-sm text-gray-500">Recomendação inteligente de imóveis compatíveis</p>
            </div>
          </div>

          {/* Seleção */}
          <Card className="mb-6">
            <CardContent className="pt-6">
              <div className="flex flex-col md:flex-row items-end gap-4">
                <div className="flex-1 w-full">
                  <label className="text-sm font-medium text-gray-700 mb-1 block">Lead</label>
                  <Select value={selectedLead} onValueChange={(v) => { setSelectedLead(v); setMatches([]); }}>
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
                <Button className="bg-blue-600 hover:bg-blue-700" onClick={handleMatch} disabled={!selectedLead || loading}>
                  {loading ? "Buscando matches..." : (
                    <>
                      <Target className="h-4 w-4 mr-2" />
                      Encontrar Matches
                    </>
                  )}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Resultados */}
          {matches.length === 0 && !loading ? (
            <Card className="h-48 flex items-center justify-center">
              <CardContent>
                <div className="text-center text-gray-400">
                  <Target className="h-12 w-12 mx-auto mb-3 opacity-50" />
                  <p>Selecione um lead e clique em "Encontrar Matches"</p>
                </div>
              </CardContent>
            </Card>
          ) : loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-2 border-blue-600 border-t-transparent" />
            </div>
          ) : (
            <div className="space-y-3">
              {matches.map((m, i) => (
                <Card key={m.id} className="hover:shadow-md transition-shadow">
                  <CardContent className="pt-5">
                    <div className="flex flex-col md:flex-row items-start gap-4">
                      {/* Ranking badge */}
                      <div className={`w-10 h-10 rounded-lg ${rankingColors[i] || "bg-gray-500"} flex items-center justify-center text-white font-bold flex-shrink-0`}>
                        #{m.posicao_ranking || i + 1}
                      </div>

                      {/* Score */}
                      <div className="flex-shrink-0 text-center">
                        <div className="relative">
                          <svg className="w-16 h-16" viewBox="0 0 120 120">
                            <circle cx="60" cy="60" r="52" fill="none" stroke="#e5e7eb" strokeWidth="8" />
                            <circle
                              cx="60" cy="60" r="52" fill="none"
                              stroke={m.score_compatibilidade > 70 ? "#10b981" : m.score_compatibilidade > 40 ? "#f59e0b" : "#ef4444"}
                              strokeWidth="8"
                              strokeDasharray={`${(m.score_compatibilidade / 100) * 326.7} 326.7`}
                              strokeLinecap="round"
                              transform="rotate(-90 60 60)"
                            />
                          </svg>
                          <div className="absolute inset-0 flex items-center justify-center">
                            <span className="text-sm font-bold">{Math.round(m.score_compatibilidade)}%</span>
                          </div>
                        </div>
                      </div>

                      {/* Dados do imóvel */}
                      <div className="flex-1">
                        {m.foto_capa_url && (
                          <img src={m.foto_capa_url} alt={m.titulo} className="w-full h-32 object-cover rounded-lg mb-3" />
                        )}
                        <div className="flex items-center gap-2 mb-1">
                          <h3 className="font-semibold text-gray-900">{m.titulo || "Imóvel"}</h3>
                          <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded">{m.codigo}</span>
                        </div>
                        <div className="flex flex-wrap gap-3 text-sm text-gray-500 mb-2">
                          <span className="flex items-center gap-1"><Building2 className="h-3.5 w-3.5" /> {m.tipo}</span>
                          <span className="flex items-center gap-1"><MapPin className="h-3.5 w-3.5" /> {m.bairro}, {m.cidade}</span>
                          {m.quartos && <span className="flex items-center gap-1"><Bed className="h-3.5 w-3.5" /> {m.quartos}q</span>}
                          {m.area_privativa && <span className="flex items-center gap-1"><Maximize2 className="h-3.5 w-3.5" /> {m.area_privativa}m²</span>}
                        </div>
                        <p className="font-bold text-gray-900">
                          {formatarMoeda(m.valor_venda || m.valor_locacao)}
                        </p>
                      </div>

                      {/* Razões */}
                      <div className="md:w-64">
                        <p className="text-xs font-semibold text-gray-600 uppercase tracking-wide mb-2">Compatibilidade</p>
                        <ul className="space-y-1">
                          {m.razoes?.slice(0, 3).map((r, ri) => (
                            <li key={ri} className="text-xs text-gray-600 flex items-start gap-1">
                              <ArrowRight className="h-3 w-3 mt-0.5 text-green-500 flex-shrink-0" />
                              {r}
                            </li>
                          ))}
                        </ul>
                        <div className="mt-3 flex flex-wrap gap-1">
                          {Object.entries(m.fatores_match || {}).slice(0, 3).map(([k, v]) => (
                            <span key={k} className="text-xs bg-blue-50 text-blue-700 px-2 py-0.5 rounded-full">
                              {k}: {(Number(v) * 100).toFixed(0)}%
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </div>
      </div>
    </ProtectedRoute>
  );
}
