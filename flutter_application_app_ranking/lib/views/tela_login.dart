import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import 'tela_registro.dart'; // Importe a tela que criaremos abaixo

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

  // Login tradicional (E-mail ou Usuário - Supabase usa e-mail por padrão)
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Colors.black],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Image.asset('assets/logo.png', height: 120),
                  const SizedBox(height: 30),
                  
                  // Campo E-mail
                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration("E-mail ou Usuário", Icons.person_outline),
                    validator: (v) => v!.isEmpty ? "Informe seu e-mail" : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Senha
                  TextFormField(
                    controller: _senhaController,
                    obscureText: !_senhaVisivel,
                    decoration: _inputDecoration("Senha", Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_senhaVisivel ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                        onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                    validator: (v) => v!.length < 6 ? "Senha muito curta" : null,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botão Entrar
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _fazerLoginEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade400,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _carregando 
                        ? const CircularProgressIndicator(color: Colors.black) 
                        : const Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  const Text("OU", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.greenAccent),
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.greenAccent)),
    );
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
          Text("Entrar com Google", style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}