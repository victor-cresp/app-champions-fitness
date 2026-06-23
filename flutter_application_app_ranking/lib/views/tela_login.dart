import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/app_theme.dart';
import 'tela_registro.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;
  bool _senhaVisivel = false;

  Future<void> _fazerLoginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );
    } on AuthException catch (e) {
      _mostrarErro(e.message);
    } catch (e) {
      _mostrarErro("Erro inesperado: $e");
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _fazerLoginComGoogle() async {
    setState(() => _carregando = true);
    try {
      final String urlDeRedirecionamento = kIsWeb ? Uri.base.origin : 'io.supabase.flutter://login-callback';
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: urlDeRedirecionamento,
      );
    } catch (e) {
      _mostrarErro("Erro Google: $e");
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🛠️ FIX DO CINZA 1: Força o fundo do próprio Scaffold a ser preto puro, matando o bug do cinza
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1E1E), Colors.black], // Ajustado o início para um grafite premium
          ),
        ),
        child: SafeArea(
          bottom: false, // 🛠️ FIX DO CINZA 2: Impede o sistema de pintar o rodapé de cinza
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  
                  // 🚀 LOGO EM DESTAQUE (Apenas maior e limpa, sem fundo verde)
                  Center(
                    child: SizedBox(
                      height: 160, // Aumentado para 160 para dar o destaque que você quer
                      child: Image.asset(
                        'assets/logo.png', 
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24), // Espaço elegante entre a logo e o texto abaixo
                  
                  // Nome do app imponente
                  const Text(
                    "Circuito Fitness",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Campo E-mail
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("E-mail ou Usuário", Icons.person_outline),
                    validator: (v) => v!.isEmpty ? "Informe seu e-mail" : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Senha
                  TextFormField(
                    controller: _senhaController,
                    obscureText: !_senhaVisivel,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Senha", Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_senhaVisivel ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                        onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                    validator: (v) => v!.length < 6 ? "Senha muito curta" : null,
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Botão Entrar
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _fazerLoginEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade400,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _carregando 
                        ? const CircularProgressIndicator(color: Colors.black) 
                        : const Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text("OU", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  // Botão Google
                  _botaoGoogle(),

                  const SizedBox(height: 40),
                  
                  // Link para Registro
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Não tem uma conta?", style: TextStyle(color: Colors.white70)),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaRegistro())),
                        child: Text("Cadastrar-se", style: TextStyle(color: Colors.greenAccent.shade400, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return buildInputDecoration(label: label, icon: icon)
      .copyWith(fillColor: Colors.white.withValues(alpha: 0.05));
  }

  Widget _botaoGoogle() {
    return OutlinedButton(
      onPressed: _carregando ? null : _fazerLoginComGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.g_mobiledata, size: 30, color: Colors.white),
          SizedBox(width: 8),
          Text("Entrar com Google", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}