import math
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware  # <-- 1. ADICIONE ESSA LINHA
from pydantic import BaseModel
from supabase import create_client, Client

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Diz ao navegador: "Pode aceitar requisições vindas do Edge/Flutter"
    allow_credentials=True,
    allow_methods=["*"],  # Libera GET, POST, etc.
    allow_headers=["*"],
)

# =====================================================================
# CONFIGURAÇÃO DO BANCO DE DADOS (Substitua com as suas chaves reais!)
# =====================================================================
SUPABASE_URL = "https://sixinlpheadgnxguutvr.supabase.co"
SUPABASE_KEY = "sb_publishable_7XYEQNIfSXrbfh8CH1BVkA_jxOYzGGo"

# Inicializa o cliente do Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
# =====================================================================

# Lista de referência para validação geográfica
ACADEMIAS_CADASTRADAS = [
    {
        "nome": "Smart Fit - Taquara (Estr. dos Bandeirantes)",
        "bairro_id": "taquara",
        "latitude": -22.9324,
        "longitude": -43.3653
    },
    {
        "nome": "Smart Fit - Recreio (Av. das Américas)",
        "bairro_id": "recreio",
        "latitude": -23.0089,
        "longitude": -43.4650
    }
]

# Função matemática para calcular distância entre duas coordenadas
def calcular_distancia_metros(lat1, lon1, lat2, lon2):
    R = 6371000  # Raio da Terra em metros
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

# Nosso Schema de Entrada (adicionando tratamento do UUID do usuário)
class PayloadTreino(BaseModel):
    usuario_id: str  # Aqui passaremos o UUID que você copiou do Supabase
    bairro_id: str
    academia_latitude: float
    academia_longitude: float
    tempo_total_minutos: int
    percentual_movimento: int

@app.post("/validar-treino", status_code=status.HTTP_201_CREATED)
async def validar_e_pontuar_treino(treino: PayloadTreino):
    
    # 1. VALIDAÇÃO DAS REGRAS ANTIFRAUDE (Tempo e Movimento)
    if treino.tempo_total_minutos < 45:
        raise HTTPException(status_code=400, detail="Treino muito curto. Mínimo 45 min.")
    if treino.tempo_total_minutos > 120:
        raise HTTPException(status_code=400, detail="Treino excedeu o limite de 2 horas.")
    if treino.percentual_movimento < 70:
        raise HTTPException(status_code=400, detail="Fraude detectada: Baixo movimento.")

    # 2. VALIDAÇÃO GEOGRÁFICA
    usuario_esta_na_academia = False
    academia_detectada = ""

    for academia in ACADEMIAS_CADASTRADAS:
        if academia["bairro_id"] == treino.bairro_id.lower():
            distancia = calcular_distancia_metros(
                treino.academia_latitude, treino.academia_longitude,
                academia["latitude"], academia["longitude"]
            )
            if distancia <= 100:
                usuario_esta_na_academia = True
                academia_detectada = academia["nome"]
                break

    if not usuario_esta_na_academia:
        raise HTTPException(
            status_code=400, 
            detail=f"Localização inválida para o bairro {treino.bairro_id.capitalize()}."
        )
    
    # 3. NOVO PASSO: PERSISTÊNCIA DOS DADOS NO SUPABASE
    pontos = 100
    try:
        # Monta a linha que será inserida no banco
        dados_treino = {
            "usuario_id": treino.usuario_id,
            "bairro_id": treino.bairro_id.lower(),
            "academia_nome": academia_detectada,
            "pontos_ganhos": pontos
        }
        
        # Executa o comando de INSERT via API do Supabase
        resposta = supabase.table("historico_treinos").insert(dados_treino).execute()
        
    except Exception as e:
        # Se o UUID do usuário não existir ou o banco falhar, capturamos o erro aqui
        raise HTTPException(
            status_code=500, 
            detail=f"Erro ao salvar no banco de dados: {str(e)}"
        )
    
    return {
        "status": "sucesso",
        "academia": academia_detectada,
        "mensagem": f"Treino registrado e +{pontos} pontos creditados no banco de dados!",
        "dados_gravados": resposta.data
    }

# Rota para puxar o ranking de um bairro específico
@app.get("/ranking/{bairro}", status_code=status.HTTP_200_OK)
async def obter_ranking_bairro(bairro: str):
    try:
        # Consulta a nossa View SQL filtrando pelo bairro e trazendo os dados prontos
        resposta = (
            supabase.table("ranking_bairros")
            .select("*")
            .eq("bairro_id", bairro.lower())
            .execute()
        )
        
        return {
            "bairro": bairro.capitalize(),
            "ranking": resposta.data
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao buscar ranking no banco de dados: {str(e)}"
        )