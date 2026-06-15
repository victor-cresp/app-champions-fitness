import 'package:supabase_flutter/supabase_flutter.dart';

// Inicialização centralizada do Supabase
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://sixinlpheadgnxguutvr.supabase.co',
    anonKey: 'sb_publishable_7XYEQNIfSXrbfh8CH1BVkA_jxOYzGGo',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

// Instância global limpa para o resto do app usar
final supabase = Supabase.instance.client;