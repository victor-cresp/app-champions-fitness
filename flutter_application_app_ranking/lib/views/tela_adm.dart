import 'package:flutter/material.dart';
import '../core/supabase_client.dart';

class TelaAdm extends StatefulWidget {
  const TelaAdm({super.key});

  @override
  State<TelaAdm> createState() => _TelaAdmState();
}

class _TelaAdmState extends State<TelaAdm> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _duracaoController = TextEditingController(); // Em semanas ou dias
  
  DateTime? _dataLimiteInscricao;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _salvando = false;

  Future<void> _selecionarData(BuildContext context, int tipo) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (escolhida != null) {
      setState(() {
        if (tipo == 1) _dataLimiteInscricao = escolhida;
        if (tipo == 2) _dataInicio = escolhida;
        if (tipo == 3) _dataFim = escolhida;
      });
    }
  }

  Future<void> _criarDesafio() async {
    if (!_formKey.currentState!.validate() || _dataLimiteInscricao == null || _dataInicio == null || _dataFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, preencha todos os campos e selecione todas as datas."), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      await supabase.from('apostas_disponiveis').insert({
        'nome': _nomeController.text.trim(),
        'duracao': "${_duracaoController.text.trim()} Semanas",
        'data_limite_inscricao': _dataLimiteInscricao!.toIso8601String(),
        'data_inicio': _dataInicio!.toIso8601String(),
        'data_fim': _dataFim!.toIso8601String(),
        'valor_entrada': 25.00, // Valor padrão de entrada fixado por você
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🏆 Novo Desafio Criado com Sucesso!"), backgroundColor: Colors.green),
        );
        _nomeController.clear();
        _duracaoController.clear();
        setState(() {
          _dataLimiteInscricao = null;
          _dataInicio = null;
          _dataFim = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar desafio: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Painel do Administrador", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              const SizedBox(height: 8),
              const Text("Crie novas temporadas rígidas de desafios para o aplicativo.", style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nomeController,
                style: const TextStyle(color: Colors.white),
                decoration: _decoracao("Nome do Desafio (Ex: Desafio de Julho)", Icons.emoji_events_outlined),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _duracaoController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _decoracao("Duração Estimada (Apenas o número em Semanas)", Icons.timer_outlined),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 24),

              const Text("Definição de Datas Críticas:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 12),

              _botaoData("1. Limite de Inscrição: ${_dataLimiteInscricao == null ? 'Selecionar' : '${_dataLimiteInscricao!.day}/${_dataLimiteInscricao!.month}'}", 1),
              _botaoData("2. Início Oficial do Jogo: ${_dataInicio == null ? 'Selecionar' : '${_dataInicio!.day}/${_dataInicio!.month}'}", 2),
              _botaoData("3. Fim Oficial (Pesagem Final): ${_dataFim == null ? 'Selecionar' : '${_dataFim!.day}/${_dataFim!.month}'}", 3),
              
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _criarDesafio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _salvando 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("LANÇAR NOVO DESAFIO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracao(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.greenAccent),
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _botaoData(String texto, int tipo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: () => _selecionarData(context, tipo),
        icon: const Icon(Icons.calendar_today, size: 16, color: Colors.greenAccent),
        label: Text(texto, style: const TextStyle(color: Colors.white)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: Colors.white24),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}