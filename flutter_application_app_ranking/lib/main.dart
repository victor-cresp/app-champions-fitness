import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client.dart';
import 'views/tela_login.dart';
import 'views/tela_principal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chama a inicialização externa do Supabase
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
    
    // Fica escutando o Supabase em tempo real através da instância centralizada
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
      home: _verificandoStatus
          ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)))
          : (_logado ? const TelaPrincipal() : const TelaLogin()),
    );
  }
}