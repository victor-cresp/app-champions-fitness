import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

// Inicialização oficial com as suas credenciais
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sixinlpheadgnxguutvr.supabase.co',
    anonKey: 'sb_publishable_7XYEQNIfSXrbfh8CH1BVkA_jxOYzGGo',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const ChampionsApp());
}

final supabase = Supabase.instance.client;

class ChampionsApp extends StatefulWidget {
  const ChampionsApp({super.key});

  @override
  State<ChampionsApp> createState() => _ChampionsAppState();
}

class _ChampionsAppState extends State<ChampionsApp> {
  bool _logado = false;
  bool _verificandoStatus = true;
  late final StreamSubscription<AuthState> _inscricaoAuth;

  @override
  void initState() {
    super.initState();
    
    // 💡 Fica escutando o Supabase em tempo real. Se logar, muda a tela na hora!
    _inscricaoAuth = supabase.auth.onAuthStateChange.listen((data) {
      final Session? sessao = data.session;
      setState(() {
        _logado = sessao != null;
        _verificandoStatus = false;
      });
    });
  }

  @override
  void dispose() {
    _inscricaoAuth.cancel(); // Limpa o ouvinte para evitar vazamento de memória
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 🎨 Mantendo o seu design escuro original que você mandou:
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.greenAccent,
      ),
      // Enquanto o Supabase confere o status, mostra um loading. Depois decide a tela.
      home: _verificandoStatus
          ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)))
          : (_logado ? const TelaPrincipal() : const TelaLogin()),
    );
  }
}

// =====================================================================
// 1. TELA DE LOGIN (COM DESIGN ATUALIZADO CIRCUITO FITNESS)
// =====================================================================
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  bool _carregando = false;

  Future<void> _fazerLoginComGoogle() async {
    if (_carregando) return;
    setState(() => _carregando = true);

    try {
      final String URLdeRedirecionamento = kIsWeb 
          ? Uri.base.origin 
          : 'io.supabase.flutter://login-callback';

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: URLdeRedirecionamento,
        authScreenLaunchMode: kIsWeb 
            ? LaunchMode.platformDefault 
            : LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao logar com Google: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🎨 Cor de fundo escura idêntica à textura da pedra do seu modelo
      backgroundColor: const Color(0xFF222831), 
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              
              // 🖼️ A sua Logo centralizada (Buscando da pasta assets)
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 180, // Tamanho ideal para o M55
                  fit: BoxFit.contain, // 🛠️ CORREÇÃO: BoxFit em vez de ContentFit
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 🟢 O subtítulo verde em caixa alta do seu modelo
              Text(
                "O RANKING DOS MELHORES",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2, // Espaçamento elegante entre as letras
                ),
              ),
              
              const Spacer(),
              
              // 🔘 Botão de Login do Google Premium e arredondado igual ao print
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _fazerLoginComGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Bordas suaves do modelo
                    ),
                  ),
                  child: _carregando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Letra "G" vermelha estilizada do Google
                            Text(
                              "G ",
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 20,
                                fontWeight: FontWeight.w800, // 🛠️ CORREÇÃO: FontWeight.w800 em vez de extrabold
                                fontFamily: 'sans-serif',
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Entrar com o Google",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 32), // Espaço inferior para o botão respirar
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// 2. TELA PRINCIPAL (RANKING & TREINO)
// =====================================================================
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final String bairroFoco = "taquara";
  final String urlBackend = "http://127.0.0.1:8080"; 

  bool _treinando = false;
  DateTime? _timestampInicio;
  List<dynamic> _rankingDados = [];
  bool _carregandoRanking = true;

  @override
  void initState() {
    super.initState();
    _buscarRanking();
  }

  Future<void> _buscarRanking() async {
    setState(() => _carregandoRanking = true);
    try {
      final response = await http.get(Uri.parse('$urlBackend/ranking/$bairroFoco'));
      if (response.statusCode == 200) {
        setState(() {
          _rankingDados = jsonDecode(response.body)['ranking'];
          _carregandoRanking = false;
        });
      }
    } catch (e) {
      setState(() => _carregandoRanking = false);
    }
  }

  Future<void> _alternarTreino() async {
    final String? usuarioId = supabase.auth.currentUser?.id;

    if (usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuário não identificado.")));
      return;
    }

    if (!_treinando) {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      setState(() {
        _treinando = true;
        _timestampInicio = DateTime.now();
      });
    } else {
      setState(() => _carregandoRanking = true);
      Position position = await Geolocator.getCurrentPosition();
      int minutosTreinados = DateTime.now().difference(_timestampInicio!).inMinutes;
      if (minutosTreinados == 0) minutosTreinados = 55; 

      final dadosTreino = {
        "usuario_id": usuarioId, 
        "bairro_id": bairroFoco,
        "academia_latitude": position.latitude,
        "academia_longitude": position.longitude,
        "tempo_total_minutos": minutosTreinados,
        "percentual_movimento": 85
      };

      try {
        final response = await http.post(
          Uri.parse('$urlBackend/validar-treino'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(dadosTreino),
        );

        if (response.statusCode == 201) {
          _buscarRanking();
        }
      } catch (e) {
        setState(() => _carregandoRanking = false);
      }

      setState(() {
        _treinando = false;
        _timestampInicio = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🏆 Liga ${bairroFoco.toUpperCase()}"),
        backgroundColor: const Color(0xFF1F1F1F),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaLogin()));
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _alternarTreino,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _treinando ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _treinando ? Colors.redAccent : Colors.greenAccent, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_treinando ? Icons.stop_circle : Icons.play_circle_fill, color: _treinando ? Colors.redAccent : Colors.greenAccent, size: 36),
                    const SizedBox(height: 8),
                    Text(_treinando ? "ENCERRAR TREINO" : "INICIAR TREINO", style: TextStyle(fontWeight: FontWeight.bold, color: _treinando ? Colors.redAccent : Colors.greenAccent)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: const [
                Icon(Icons.leaderboard, color: Colors.orangeAccent),
                SizedBox(width: 8),
                Text("Classificação da Categoria", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: _carregandoRanking
                  ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                  : ListView.builder(
                      itemCount: _rankingDados.length,
                      itemBuilder: (context, index) {
                        final atleta = _rankingDados[index];
                        return Card(
                          color: const Color(0xFF1F1F1F),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: index == 0 ? Colors.orangeAccent : Colors.grey[800],
                              child: Text("${index + 1}º", style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(atleta['usuario_nome'] ?? 'Atleta', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${atleta['total_treinos']} treinos confirmados"),
                            trailing: Text("${atleta['total_pontos']} PTS", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}