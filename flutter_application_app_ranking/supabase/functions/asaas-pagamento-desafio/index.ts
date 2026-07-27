import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// ============================================================
// Configuração Asaas (Detecta Sandbox ou Produção automaticamente)
// ============================================================
const ASAAS_API_KEY_SANDBOX = Deno.env.get("ASAAS_API_KEY_SANDBOX");
const ASAAS_API_KEY = ASAAS_API_KEY_SANDBOX ?? Deno.env.get("ASAAS_API_KEY") ?? "";

if (!ASAAS_API_KEY) {
  throw new Error("A variável de ambiente contendo a API KEY do Asaas é obrigatória.");
}

const IS_SANDBOX =
  ASAAS_API_KEY_SANDBOX !== undefined ||
  ASAAS_API_KEY.startsWith("$aact_hmlg_");

const ASAAS_API_BASE = IS_SANDBOX
  ? "https://api-sandbox.asaas.com/v3"
  : "https://api.asaas.com/v3";

function headersAsaas(): Record<string, string> {
  return {
    "Content-Type": "application/json",
    access_token: ASAAS_API_KEY,
  };
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function normalizarCpf(cpf: unknown): string {
  const somenteDigitos = String(cpf ?? "").replace(/\D/g, "");

  if (!somenteDigitos || somenteDigitos.length > 11) {
    throw new Error("CPF inválido. Informe um CPF com 11 dígitos.");
  }

  const cpfNormalizado = somenteDigitos.padStart(11, "0");
  if (!cpfValido(cpfNormalizado)) {
    throw new Error("CPF inválido. Confira os números informados.");
  }

  return cpfNormalizado;
}

function cpfValido(cpf: string): boolean {
  if (!/^\d{11}$/.test(cpf) || /^(\d)\1{10}$/.test(cpf)) return false;

  for (let posicao = 9; posicao <= 10; posicao++) {
    let soma = 0;
    for (let indice = 0; indice < posicao; indice++) {
      soma += Number(cpf[indice]) * (posicao + 1 - indice);
    }

    const resto = (soma * 10) % 11;
    const verificador = resto === 10 ? 0 : resto;
    if (verificador !== Number(cpf[posicao])) return false;
  }

  return true;
}

function mensagemErroAsaas(data: Record<string, any>, fallback: string): string {
  return data.errors?.[0]?.description ?? data.message ?? fallback;
}

// ============================================================
// Busca ou Criação Automática do Cliente
// ============================================================
async function buscarOuCriarCliente(nome: string, email: string, cpf: string): Promise<string> {
  let nomeCompleto = nome.trim();
  if (!nomeCompleto.includes(" ")) {
    nomeCompleto = `${nomeCompleto} Silva`;
  }

  const response = await fetch(
    `${ASAAS_API_BASE}/customers?cpfCnpj=${encodeURIComponent(cpf)}`,
    { headers: headersAsaas() },
  );
  const data = await response.json();

  if (!response.ok) {
    throw new Error(
      mensagemErroAsaas(data, "Não foi possível consultar o cliente no Asaas."),
    );
  }

  if (data.data && data.data.length > 0) return data.data[0].id;

  const createResponse = await fetch(`${ASAAS_API_BASE}/customers`, {
    method: "POST",
    headers: headersAsaas(),
    body: JSON.stringify({
      name: nomeCompleto,
      email: email || "atleta@circuitofitness.app",
      cpfCnpj: cpf,
      notificationDisabled: true,
    }),
  });
  const createData = await createResponse.json();

  if (!createResponse.ok || !createData.id) {
    throw new Error(
      mensagemErroAsaas(createData, "Não foi possível criar o cliente no Asaas."),
    );
  }

  return createData.id;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();

    if (!body.usuarioId || !body.inscricaoId || !body.valorDesafio || !body.formaPagamento || !body.cpfCnpjCliente || !body.nomeCliente) {
      return new Response(JSON.stringify({ success: false, error: "Dados obrigatórios faltando no servidor." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    let cpfNormalizado: string;
    let clienteId: string;

    try {
      cpfNormalizado = normalizarCpf(body.cpfCnpjCliente);
      clienteId = await buscarOuCriarCliente(
        body.nomeCliente,
        body.emailCliente,
        cpfNormalizado,
      );
    } catch (error: unknown) {
      const mensagem = error instanceof Error
        ? error.message
        : "Não foi possível identificar ou criar o cliente no Asaas.";
      return new Response(JSON.stringify({ success: false, error: mensagem }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const valorDesafio = body.valorDesafio;

    // Payload de cobrança limpo amarrado ao ID da inscrição
    const cobrancaPayload: Record<string, any> = {
      customer: clienteId,
      billingType: body.formaPagamento === "PIX" ? "PIX" : "CREDIT_CARD",
      value: valorDesafio,
      dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split("T")[0],
      description: `Desafio: ${body.nomeDesafio || "Circuito"}`,
      externalReference: body.inscricaoId, // Webhook lerá este ID para atualizar a tabela participantes_apostas
    };

    // ============================================================
    // 🔥 CONFIGURAÇÃO DO SPLIT DE PAGAMENTO (COFRE DO DESAFIO)
    // ============================================================
    // Se o Flutter enviar o walletIdSubconta, aplica as regras de Split
    if (body.walletIdSubconta) {
      cobrancaPayload.split = [
        {
          walletId: body.walletIdSubconta,
          percentualValue: 97.0, // 97% vai direto para a subconta (Cofre), os 3% restantes ficam no MEI
          description: `Rateio de entrada - ${body.nomeDesafio || "Desafio"}`,
        }
      ];
    }

    if (body.formaPagamento === "CREDIT_CARD") {
      if (!body.cartao) return new Response(JSON.stringify({ success: false, error: "Dados do cartão não enviados." }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });

      cobrancaPayload.creditCard = {
        holderName: body.cartao.holderName,
        number: body.cartao.number.replace(/\s/g, ""),
        expiryMonth: body.cartao.expiryMonth.padStart(2, "0"),
        expiryYear: body.cartao.expiryYear,
        ccv: body.cartao.ccv,
      };

      cobrancaPayload.creditCardHolderInfo = {
        name: body.nomeCliente,
        email: body.emailCliente || `${body.usuarioId}@circuitofitness.app`,
        cpfCnpj: cpfNormalizado,
        postalCode: "20040002",
        addressNumber: "100",
        phone: "21999999999",
      };

      cobrancaPayload.remoteIp = req.headers.get("x-forwarded-for") || "127.0.0.1";
    }

    const response = await fetch(`${ASAAS_API_BASE}/payments`, {
      method: "POST",
      headers: headersAsaas(),
      body: JSON.stringify(cobrancaPayload),
    });

    const data = await response.json();

    if (!response.ok) {
      return new Response(JSON.stringify({ success: false, error: data.errors?.[0]?.description || "Erro no gateway.", detalhes: data.errors }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Tratamento PIX coletando QR Code dinâmico
    if (body.formaPagamento === "PIX") {
      const pixResponse = await fetch(`${ASAAS_API_BASE}/payments/${data.id}/pixQrCode`, { method: "GET", headers: headersAsaas() });
      const pixData = await pixResponse.json();

      return new Response(JSON.stringify({
        success: true,
        pagamentoId: data.id,
        statusAsaas: data.status,
        pixCopiaECola: pixData.payload || data.pixQrCode || data.pixPayload,
        pixQrCodeBase64: pixData.encodedImage,
        invoiceUrl: data.invoiceUrl || null,
      }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ success: true, pagamentoId: data.id, statusAsaas: data.status, mensagem: "Inscrição efetuada com sucesso!" }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : "Erro crítico.";
    return new Response(JSON.stringify({ success: false, error: msg }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
