enum EstagioDesafio { divulgacao, bloqueio, jogo, finalizado }

class DesafioModel {
  final String id;
  final String title;
  final DateTime dataLimiteInscricao;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double valorEntrada;
  final int totalParticipantes;

  DesafioModel({
    required this.id,
    required this.title,
    required this.dataLimiteInscricao,
    required this.dataInicio,
    required this.dataFim,
    required this.valorEntrada,
    required this.totalParticipantes,
  });

  // Calcula o Pote Total Dinamicamente
  double get poteTotal => totalParticipantes * valorEntrada;

  // Descobre em qual fase o desafio está baseado na data atual
  EstagioDesafio get estagio {
    final agora = DateTime.now();
    
    if (agora.isBefore(dataLimiteInscricao)) {
      return EstagioDesafio.divulgacao;
    } else if (agora.isAfter(dataLimiteInscricao) && agora.isBefore(dataInicio)) {
      return EstagioDesafio.bloqueio;
    } else if (agora.isAfter(dataInicio) && agora.isBefore(dataFim)) {
      // Regra dos Atrasados (Late Joiners): Permite entrar até o 7º dia de jogo
      final limiteAtrasados = dataInicio.add(const Duration(days: 5));
      if (agora.isBefore(limiteAtrasados)) {
        return EstagioDesafio.divulgacao; // Ainda aceita inscrição, mas já está rodando
      }
      return EstagioDesafio.jogo;
    } else {
      return EstagioDesafio.finalizado;
    }
  }
}