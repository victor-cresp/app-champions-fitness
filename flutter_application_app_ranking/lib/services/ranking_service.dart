import '../core/supabase_client.dart';

class RankingService {
  // Busca a lista de ranking por bairro direto do Supabase
Future<List<dynamic>> buscarRanking(String bairro) async {
    try {
      final response = await supabase
          .from('ranking_bairros') // <-- Confirme se esse nome está idêntico no painel do Supabase
          .select()
          .eq('bairro_id', bairro) 
          .order('total_pontos', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      // Isso vai cuspir o erro exato do Supabase no seu terminal do VS Code / Cursor
      print("ERRO DO SUPABASE AQUI: $e"); 
      return [];
    }
  }

  // Envia os dados do treino direto para a tabela do Supabase
  Future<bool> enviarTreino(Map<String, dynamic> dadosTreino) async {
    try {
      // Insere a linha direto na tabela 'treinos'
      await supabase.from('historico_treinos').insert(dadosTreino);
      return true;
    } catch (e) {
      return false;
    }
  }
}