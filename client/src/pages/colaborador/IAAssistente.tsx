import { useState, useRef, useEffect } from "react";
import { MessageSquare, Send, Bot, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import ProtectedRoute from "@/components/ProtectedRoute";
import { assistenteEnviar, buscarSessaoAssistente } from "@/lib/api-imoveis";

interface Message {
  id: string;
  session_id: string;
  role: string;
  content: string;
  criado_em: string;
}

export default function IAAssistente() {
  const [sessionId, setSessionId] = useState("public");
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    buscarSessaoAssistente(sessionId)
      .then((d) => {
        if (d.messages) setMessages(d.messages);
      })
      .catch(() => {});
  }, [sessionId]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim()) return;
    const userMsg: Message = {
      id: `temp-${Date.now()}`,
      session_id: sessionId,
      role: "user",
      content: input.trim(),
      criado_em: new Date().toISOString(),
    };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setLoading(true);

    try {
      const result = await assistenteEnviar(sessionId, userMsg.content);
      const botMsg: Message = {
        id: `temp-${Date.now() + 1}`,
        session_id: result.session_id,
        role: "assistant",
        content: result.resposta,
        criado_em: new Date().toISOString(),
      };
      setMessages((prev) => [...prev, botMsg]);
      setSessionId(result.session_id);
    } catch (e: any) {
      const errMsg: Message = {
        id: `temp-${Date.now() + 2}`,
        session_id: sessionId,
        role: "assistant",
        content: "Desculpe, ocorreu um erro. Tente novamente.",
        criado_em: new Date().toISOString(),
      };
      setMessages((prev) => [...prev, errMsg]);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gray-50/80">
        <div className="container py-8 max-w-3xl mx-auto">
          <div className="flex items-center gap-3 mb-6">
            <MessageSquare className="h-8 w-8 text-purple-500" />
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Assistente IA</h1>
              <p className="text-sm text-gray-500">Chat inteligente para dúvidas imobiliárias</p>
            </div>
          </div>

          <Card className="h-[600px] flex flex-col">
            {/* Messages */}
            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              {messages.length === 0 ? (
                <div className="flex flex-col items-center justify-center h-full text-gray-400">
                  <Bot className="h-16 w-16 mb-4 opacity-30" />
                  <p className="text-center">
                    Converse com o Assistente da Casa DF<br />
                    <span className="text-xs">Tire dúvidas sobre imóveis, financiamento, contratos e mais</span>
                  </p>
                  <div className="mt-4 grid grid-cols-1 gap-2 w-full max-w-sm">
                    {[
                      "Quais imóveis de 3 quartos estão disponíveis?",
                      "Como funciona a simulação de financiamento?",
                      "O que preciso para dar entrada em um imóvel?",
                      "Qual banco tem a menor taxa de juros?",
                    ].map((sug) => (
                      <button
                        key={sug}
                        onClick={() => { setInput(sug); handleSend(); }}
                        className="text-left text-xs bg-gray-50 hover:bg-gray-100 border border-gray-200 rounded-lg px-3 py-2 transition-colors"
                      >
                        {sug}
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                messages.map((msg) => (
                  <div
                    key={msg.id}
                    className={`flex gap-3 ${msg.role === "user" ? "flex-row-reverse" : ""}`}
                  >
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                      msg.role === "user" ? "bg-blue-500" : "bg-purple-500"
                    }`}>
                      {msg.role === "user" ? (
                        <User className="h-4 w-4 text-white" />
                      ) : (
                        <Bot className="h-4 w-4 text-white" />
                      )}
                    </div>
                    <div className={`max-w-[75%] px-4 py-3 rounded-2xl text-sm ${
                      msg.role === "user"
                        ? "bg-blue-500 text-white rounded-tr-sm"
                        : "bg-white border border-gray-200 text-gray-800 rounded-tl-sm"
                    }`}>
                      {msg.content.split("\n").map((line, i) => (
                        <p key={i} className={i > 0 ? "mt-1" : ""}>{line}</p>
                      ))}
                    </div>
                  </div>
                ))
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Input */}
            <div className="border-t p-4">
              <div className="flex gap-2">
                <Input
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={handleKeyDown}
                  placeholder="Digite sua mensagem..."
                  disabled={loading}
                />
                <Button
                  onClick={handleSend}
                  disabled={loading || !input.trim()}
                  className="bg-purple-600 hover:bg-purple-700 flex-shrink-0"
                >
                  <Send className="h-4 w-4" />
                </Button>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </ProtectedRoute>
  );
}
