import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

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
      final String urlDeRedirecionamento = kIsWeb 
          ? Uri.base.origin 
          : 'io.supabase.flutter://login-callback';

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: urlDeRedirecionamento,
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // 🧱 Carrega a sua textura de pedra limpa cobrindo a tela toda
          image: DecorationImage(
            image: AssetImage('assets/fundo_pedra.png'),
            fit: BoxFit.cover, 
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Spacer cria um espaçamento elástico ideal para centralizar a logo verticalmente
                const Spacer(flex: 3),
                
                // 🖼️ Sua logo recortada (transparente) centralizada e protegida contra esticamento na Web
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Image.asset(
                      'assets/logo.png', 
                      fit: BoxFit.contain, 
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 🟢 Subtítulo verde idêntico ao modelo original
                Text(
                  "O RANKING DOS MELHORES",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.greenAccent.shade400, 
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    shadows: const [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black54,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                
                // Empurra o botão do Google de forma suave para repousar no rodapé
                const Spacer(flex: 4),
                
                // 🔘 Botão do Google Premium
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _fazerLoginComGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), 
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
                                Text(
                                  "G ",
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Entrar com o Google",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24), // Margem final de segurança da barra de navegação do celular
              ],
            ),
          ),
        ),
      ),
    );
  }
}