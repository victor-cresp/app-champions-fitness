import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'views/tela_abas.dart';
import 'core/supabase_client.dart';
import 'views/tela_login.dart';
import 'views/tela_principal.dart';

void main() async {
  // 1. Garante que os bindings do Flutter estão prontos
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Carrega o arquivo .env e ESPERA terminar (com o await)
    await dotenv.load(fileName: ".env");
    print("DEBUG: .env carregado com sucesso!"); // Log de segurança no console
  } catch (e) {
    print("DEBUG: Erro ao carregar o arquivo .env: $e");
  }

  // 3. Só depois de carregar o .env, chama a inicialização do Supabase
  await initSupabase();

  runApp(const ChampionsApp());
}

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
    
    // 1. Faz uma checagem imediata se já existe uma sessão guardada no dispositivo
    final sessaoAtual = supabase.auth.currentSession;
    if (sessaoAtual != null) {
      setState(() {
        _logado = true;
        _verificandoStatus = false;
      });
    }
    
    // 2. Fica escutando as mudanças (como o retorno do Google Login)
    _inscricaoAuth = supabase.auth.onAuthStateChange.listen((data) {
      final Session? sessao = data.session;
      final AuthChangeEvent evento = data.event;

      // Se o evento for de token recuperado ou login efetuado com sucesso
      if (sessao != null) {
        setState(() {
          _logado = true;
          _verificandoStatus = false;
        });
      } else if (evento == AuthChangeEvent.signedOut) {
        // Apenas desloga se o evento for explicitamente de Logout
        setState(() {
          _logado = false;
          _verificandoStatus = false;
        });
      } else {
        // Evita que estados intermediários joguem o usuário para o login antes da hora
        setState(() {
          _verificandoStatus = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _inscricaoAuth.cancel(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.greenAccent,
      ),
      // Se estiver verificando o status, mostra um loading, se logado vai para a TelaAbas, senão TelaLogin
      home: _verificandoStatus
          ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)))
          : (_logado ? const TelaAbas() : const TelaLogin()), // <-- ALTERADO AQUI (De TelaPrincipal para TelaAbas)
    );
  }
}