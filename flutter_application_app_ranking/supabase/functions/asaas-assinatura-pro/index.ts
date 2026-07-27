import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

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

const VALOR_ASSINATURA = 19.90;

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

// 1. FUNÇÃO AUTOMÁTICA DE BUSCA OU CRIAÇÃO DE CLIENTE
async function obterOuCriarCliente(nome: string, email: string, cpf: string): Promise<string> {
  // Garante que o nome tenha sobrenome para o Asaas não recusar
  let nomeCompleto = nome.trim();
  if (!nomeCompleto.includes(" ")) {
    nomeCompleto = `${nomeCompleto} Silva`;
  }

  // Tenta buscar existente
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

  if (data.data && data.data.length > 0) {
    console.log(`[Asaas] Cliente existente localizado: ${data.data[0].id}`);
    return data.data[0].id;
  }

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

  console.log(`[Asaas] Novo cliente criado com sucesso: ${createData.id}`);
  return createData.id;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    console.log("[Asaas] Solicitação de assinatura recebida:", {
      usuarioId: body.usuarioId,
      formaPagamento: body.formaPagamento,
    });

    if (!body.usuarioId || !body.formaPagamento || !body.cpfCnpjCliente || !body.nomeCliente) {
      return new Response(
        JSON.stringify({ success: false, error: "Dados obrigatórios faltando no body enviado pelo Flutter." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let cpfNormalizado: string;
    let clienteId: string;

    try {
      cpfNormalizado = normalizarCpf(body.cpfCnpjCliente);
      clienteId = await obterOuCriarCliente(
        body.nomeCliente,
        body.emailCliente,
        cpfNormalizado,
      );
    } catch (error: unknown) {
      const mensagem = error instanceof Error
        ? error.message
        : "Não foi possível identificar ou cadastrar o cliente no Asaas.";
      return new Response(
        JSON.stringify({ success: false, error: mensagem }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 2. MONTAR PAYLOAD DE ASSINATURA RECORRENTE (/v3/subscriptions)
    const assinaturaPayload: Record<string, any> = {
      customer: clienteId,
      billingType: body.formaPagamento === "PIX" ? "PIX" : "CREDIT_CARD",
      value: VALOR_ASSINATURA,
      cycle: "MONTHLY",
      nextDueDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().split("T")[0],
      description: "Circuito Fitness Pro",
      externalReference: body.usuarioId,
    };

    if (body.formaPagamento === "CREDIT_CARD") {
      if (!body.cartao) {
        return new Response(
          JSON.stringify({ success: false, error: "O objeto 'cartao' não foi enviado pelo Flutter." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      assinaturaPayload.creditCard = {
        holderName: body.cartao.holderName,
        number: body.cartao.number ? body.cartao.number.replace(/\s/g, "") : "",
        expiryMonth: body.cartao.expiryMonth ? body.cartao.expiryMonth.padStart(2, "0") : "",
        expiryYear: body.cartao.expiryYear,
        ccv: body.cartao.ccv,
      };

      // Injeta dados estruturais em Sandbox caso o Flutter envie em branco, evitando erros de checkout
      assinaturaPayload.creditCardHolderInfo = {
        name: body.nomeCliente,
        email: body.emailCliente || "atleta@circuitofitness.app",
        cpfCnpj: cpfNormalizado,
        postalCode: body.postalCode || (IS_SANDBOX ? "20040002" : ""),
        addressNumber: body.addressNumber || (IS_SANDBOX ? "100" : ""),
        phone: body.phone || (IS_SANDBOX ? "21999999999" : ""),
      };

      assinaturaPayload.remoteIp = req.headers.get("x-forwarded-for") || "127.0.0.1";
    }

    console.log("[Asaas] Enviando assinatura:", {
      usuarioId: body.usuarioId,
      formaPagamento: assinaturaPayload.billingType,
    });

    const response = await fetch(`${ASAAS_API_BASE}/subscriptions`, {
      method: "POST",
      headers: headersAsaas(),
      body: JSON.stringify(assinaturaPayload),
    });

    const data = await response.json();
    console.log("[Raio-X] Resposta final do /subscriptions:", JSON.stringify(data, null, 2));

    if (!response.ok) {
      return new Response(
        JSON.stringify({ success: false, error: data.errors?.[0]?.description || "Erro ao criar assinatura.", detalhesAsaas: data.errors }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. TRATAMENTO ESPECÍFICO SE FOR PIX (Busca a primeira parcela da assinatura para gerar o QR Code)
    if (body.formaPagamento === "PIX") {
      try {
        console.log(`[PIX] Buscando a primeira cobrança da assinatura: ${data.id}`);

        // Buscamos as cobranças vinculadas a esta assinatura (sub_...)
        const cobrancasResponse = await fetch(`${ASAAS_API_BASE}/subscriptions/${data.id}/payments`, {
          method: "GET",
          headers: headersAsaas()
        });

        const cobrancasData = await cobrancasResponse.json();

        // Pegamos a primeira cobrança da lista (que é a parcela atual aguardando pagamento)
        const primeiraCobranca = cobrancasData.data?.[0];

        if (!primeiraCobranca || !primeiraCobranca.id) {
          throw new Error("Nenhuma cobrança ativa foi gerada para esta assinatura ainda.");
        }

        console.log(`[PIX] Cobrança atual localizada: ${primeiraCobranca.id}. Solicitando QR Code...`);

        // Buscamos o QR Code usando o ID correto da cobrança (pay_...)
        const pixResponse = await fetch(`${ASAAS_API_BASE}/payments/${primeiraCobranca.id}/pixQrCode`, {
          method: "GET",
          headers: headersAsaas()
        });

        const pixData = await pixResponse.json();

        return new Response(
          JSON.stringify({
            success: true,
            assinaturaId: data.id,
            pagamentoId: primeiraCobranca.id,
            statusAsaas: primeiraCobranca.status,
            pixCopiaECola: pixData.payload,
            pixQrCodeBase64: pixData.encodedImage
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } catch (pixError) {
        const msg = pixError instanceof Error ? pixError.message : "Erro desconhecido";
        console.error("[Raio-X Erro] Erro ao buscar QR Code da assinatura PIX:", msg);
        return new Response(
          JSON.stringify({ success: false, error: "Assinatura criada, mas falhou ao gerar o QR Code do PIX.", detalhes: msg }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 6. RETORNO DE SUCESSO GERAL (Incluso Cartão de Crédito)
    return new Response(
      JSON.stringify({
        success: true,
        assinaturaId: data.id,
        statusAsaas: data.status,
        mensagem: "Assinatura processada com sucesso!"
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: unknown) {
    const mensagem = error instanceof Error ? error.message : "Erro crítico.";
    return new Response(JSON.stringify({ success: false, error: mensagem }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
