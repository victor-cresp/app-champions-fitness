import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização oficial com as suas credenciais
  await Supabase.initialize(
    url: 'https://sixinlpheadgnxguutvr.supabase.co',
    anonKey: 'sb_publishable_7XYEQNIfSXrbfh8CH1BVkA_jxOYzGGo',
  );

  runApp(const ChampionsApp());
}

final supabase = Supabase.instance.client;

class ChampionsApp extends StatelessWidget {
  const ChampionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.greenAccent,
      ),
      // Se já houver sessão ativa na inicialização, abre o ranking. Caso contrário, login.
      home: supabase.auth.currentSession == null 
          ? const TelaLogin() 
          : const TelaPrincipal(),
    );
  }
}

// =====================================================================
// 1. TELA DE LOGIN (COM ESCUTA ATIVA DE REDIRECIONAMENTO)
// =====================================================================
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  bool _carregando = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Escuta ativamente as mudanças de autenticação (captura o retorno da Web)
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      if (session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TelaPrincipal()),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _fazerLoginComGoogle() async {
    setState(() => _carregando = true);
    try {
      final String urlAtual = Uri.base.origin;

      // Fluxo limpo e nativo para Web
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: urlAtual,
      );
      
    } catch (e) {
      print("Erro capturado no login: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao logar com Google: $e")),
        );
      }
      if (mounted) setState(() => _carregando = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🏆", style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                "CHAMPIONS LEAGUE",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const Text(
                "DOS BAIRROS",
                style: TextStyle(fontSize: 16, color: Colors.greenAccent, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 48),
              _carregando
                  ? const CircularProgressIndicator(color: Colors.greenAccent)
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _fazerLoginComGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.redAccent),
                      label: const Text(
                        "Entrar com o Google",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
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