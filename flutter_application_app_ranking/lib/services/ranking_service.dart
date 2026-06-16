import 'dart:convert';
import 'package:http/http.dart' as http;

class RankingService {
  final String urlBackend = "https://champions-fitness-backend.onrender.com";

  // Busca a lista de ranking por bairro
  Future<List<dynamic>> buscarRanking(String bairro) async {
    try {
      final response = await http.get(Uri.parse('$urlBackend/ranking/$bairro'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['ranking'] ?? [];
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  // Envia os dados do treino para validação no backend
  Future<bool> enviarTreino(Map<String, dynamic> dadosTreino) async {
    try {
      final response = await http.post(
        Uri.parse('$urlBackend/validar-treino'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dadosTreino),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}