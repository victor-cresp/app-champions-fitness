import 'package:flutter/material.dart';

class TelaDetalhesDesafio extends StatelessWidget {
  final Map<String, dynamic> inscricaoData;
  final Map<String, dynamic> desafioData;

  const TelaDetalhesDesafio({
    super.key, 
    required this.inscricaoData, 
    required this.desafioData
  });

  @override
  Widget build(BuildContext context) {
    final String titulo = desafioData['nome'] ?? 'Detalhes do Desafio';
    final double valor = double.tryParse(desafioData['valor_entrada']?.toString() ?? '') ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aqui você desenha a página do jeito que preferir!
            Text(
              "Valor da Inscrição: R\$ ${valor.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Exemplo de botão para resolver o pagamento pendente
            if (inscricaoData['status_pagamento'] == 'pendente')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                  onPressed: () {
                    // Lógica para ir pro checkout de pagamento
                  },
                  child: const Text("EFETUAR PAGAMENTO", style: TextStyle(color: Colors.black)),
                ),
              ),

             const SizedBox(height: 16),

             // Exemplo de botão para enviar vídeo
             if (inscricaoData['status_video'] == 'nao_enviado' || inscricaoData['status_video'] == 'reprovado')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () {
                    // Lógica para abrir câmera/galeria
                  },
                  child: const Text("ENVIAR VÍDEO DE PESAGEM", style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}