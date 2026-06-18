import 'package:flutter/material.dart';
import '../core/supabase_client.dart';

class TelaAdm extends StatefulWidget {
  const TelaAdm({super.key});

  @override
  State<TelaAdm> createState() => _TelaAdmState();
}

class _TelaAdmState extends State<TelaAdm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers do Formulário de Criação
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _dataInicioController = TextEditingController();
  final _dataLimiteInscricaoController = TextEditingController();
  final _dataFimController = TextEditingController();

  DateTime? _dataInicioSelecionada;
  DateTime? _dataLimiteSelecionada;
  DateTime? _dataFimSelecionada;
  
  String _duracaoTexto = "0"; 
  bool _salvando = false;

  // Gerenciamento e Listagem
  List<dynamic> _desafiosCadastrados = [];
  bool _carregandoListagem = false;

  // 🚀 NOVOS CONTROLES DE FILTRO
  final _buscaNomeController = TextEditingController(); // Controller para a barra de pesquisa
  DateTimeRange? _filtroDataRange; // Guarda o período (Início e Fim) selecionado

  @override
  void initState() {
    super.initState();
    _buscarDesafiosDoSupabase();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    _dataInicioController.dispose();
    _dataLimiteInscricaoController.dispose();
    _dataFimController.dispose();
    _buscaNomeController.dispose(); // 🚀 Importante dar dispose para evitar leak de memória
    super.dispose();
  }

  Future<void> _buscarDesafiosDoSupabase() async {
    setState(() => _carregandoListagem = true);
    try {
      final dados = await supabase
          .from('apostas_disponiveis')
          .select('*')
          .eq('is_deleted', false)
          .order('data_inicio', ascending: true);

      setState(() {
        _desafiosCadastrados = dados;
        _carregandoListagem = false;
      });
    } catch (e) {
      setState(() => _carregandoListagem = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro ao listar desafios: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _excluirDesafio(dynamic desafioId) async {
    try {
      await supabase
          .from('apostas_disponiveis')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', desafioId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Desafio arquivado/excluído com sucesso!"), backgroundColor: Colors.orangeAccent),
        );
      }
      _buscarDesafiosDoSupabase(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro ao excluir: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _atualizarDuracao() {
    if (_dataInicioSelecionada != null && _dataFimSelecionada != null) {
      final diferenca = _dataFimSelecionada!.difference(_dataInicioSelecionada!).inDays;
      setState(() {
        _duracaoTexto = diferenca > 0 ? "$diferenca" : "0";
      });
    }
  }

  Future<void> _selecionarData(BuildContext context, int tipoData) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (escolhida != null) {
      setState(() {
        String dataFormatada = "${escolhida.day.toString().padLeft(2, '0')}/${escolhida.month.toString().padLeft(2, '0')}/${escolhida.year}";
        
        if (tipoData == 1) {
          _dataInicioSelecionada = escolhida;
          _dataInicioController.text = dataFormatada;
        } else if (tipoData == 2) {
          _dataLimiteSelecionada = escolhida;
          _dataLimiteInscricaoController.text = dataFormatada;
        } else if (tipoData == 3) {
          _dataFimSelecionada = escolhida;
          _dataFimController.text = dataFormatada;
        }
      });
      _atualizarDuracao();
    }
  }

  // 🚀 NOVA FUNÇÃO: Abre o seletor de Período/Range de datas nativo do Flutter
  Future<void> _selecionarDataRangeFiltro(BuildContext context) async {
    final DateTimeRange? escolhido = await showDateRangePicker(
      context: context,
      initialDateRange: _filtroDataRange,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E676),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (escolhido != null) {
      setState(() {
        _filtroDataRange = escolhido;
      });
    }
  }

  Future<void> _salvarDesafio() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dataFimSelecionada != null && _dataInicioSelecionada != null) {
      if (_dataFimSelecionada!.isBefore(_dataInicioSelecionada!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ A data de término não pode ser antes da data de início!"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _salvando = true);

    try {
      final valorLimpo = _valorController.text.replaceAll(',', '.').trim();
      final double valorAposta = double.parse(valorLimpo);
      
      final int diasDuracao = int.tryParse(_duracaoTexto) ?? 0;

      await supabase.from('apostas_disponiveis').insert({
        'nome': _tituloController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'valor_entrada': valorAposta,
        'data_inicio': _dataInicioSelecionada?.toIso8601String(),
        'data_limite_inscricao': _dataLimiteSelecionada?.toIso8601String(),
        'data_fim': _dataFimSelecionada?.toIso8601String(),
        'duracao': diasDuracao, 
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 Novo desafio lançado com sucesso!"), backgroundColor: Colors.green),
        );
        
        _tituloController.clear();
        _descricaoController.clear();
        _valorController.clear();
        _dataInicioController.clear();
        _dataLimiteInscricaoController.clear();
        _dataFimController.clear();
        setState(() {
          _dataInicioSelecionada = null;
          _dataLimiteSelecionada = null;
          _dataFimSelecionada = null;
          _duracaoTexto = "0";
        });
      }
      _buscarDesafiosDoSupabase(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro ao lançar desafio: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarDialogExclusao(dynamic id, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir Desafio?", style: TextStyle(color: Colors.white)),
        content: Text("Tem certeza que deseja remover o desafio '$nome'? Os usuários não poderão mais se inscrever.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _excluirDesafio(id);
            },
            child: const Text("CONFIRMAR EXCLUSÃO", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121212),
          title: const Text("Painel do Administrador", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          elevation: 0,
          bottom: TabBar(
            indicatorColor: const Color(0xFF00E676),
            labelColor: const Color(0xFF00E676),
            unselectedLabelColor: Colors.white54,
            tabs: [
              const Tab(icon: Icon(Icons.add_box_outlined), text: "Lançar Desafio"),
              const Tab(icon: Icon(Icons.settings_outlined), text: "Gerenciar Desafios"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAbaLancamento(),
            _buildAbaGerenciamento(),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaLancamento() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _tituloController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration("Nome do Desafio", Icons.emoji_events_outlined),
              validator: (v) => v == null || v.trim().isEmpty ? "O nome é obrigatório" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descricaoController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration("Descrição / Regras do Desafio", Icons.description_outlined),
              validator: (v) => v == null || v.trim().isEmpty ? "A descrição é obrigatória" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration("Valor da Aposta (em Reais)", Icons.attach_money),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "O valor é obrigatório";
                if (double.tryParse(v.replaceAll(',', '.').trim()) == null) return "Número inválido";
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dataInicioController,
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration("Data de Início do Desafio", Icons.calendar_today_outlined),
              onTap: () => _selecionarData(context, 1),
              validator: (v) => v == null || v.isEmpty ? "A data de início é obrigatória" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dataLimiteInscricaoController,
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration("Data Limite de Inscrição", Icons.event_busy_outlined),
              onTap: () => _selecionarData(context, 2),
              validator: (v) => v == null || v.isEmpty ? "A data limite é obrigatória" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dataFimController,
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration("Data de Término do Desafio", Icons.gavel_outlined),
              onTap: () => _selecionarData(context, 3),
              validator: (v) => v == null || v.isEmpty ? "A data de término é obrigatória" : null,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.timelapse, color: Colors.greenAccent.shade400),
                  const SizedBox(width: 12),
                  const Text("Duração Calculada: ", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text("$_duracaoTexto dias", style: const TextStyle(color: Color(0xFF00E676), fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarDesafio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _salvando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("Lançar Desafio", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaGerenciamento() {
    if (_carregandoListagem) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
    }

    // 🚀 NOVA LOGICA DE FILTRAGEM COMBINADA (Nome + Período de Datas)
    final desafiosFiltrados = _desafiosCadastrados.where((item) {
      // 1. Filtro de Texto (Nome do Desafio)
      final String nomeDesafio = (item['nome'] ?? '').toString().toLowerCase();
      final String termoBusca = _buscaNomeController.text.toLowerCase().trim();
      if (termoBusca.isNotEmpty && !nomeDesafio.contains(termoBusca)) {
        return false;
      }

      // 2. Filtro de Período (Range de Datas)
      if (_filtroDataRange != null) {
        final dataInicioItem = DateTime.tryParse(item['data_inicio'] ?? '');
        if (dataInicioItem == null) return false;

        // Zerando as horas para comparar apenas Ano, Mês e Dia de forma justa
        final dataItemZero = DateTime(dataInicioItem.year, dataInicioItem.month, dataInicioItem.day);
        final dataStartZero = DateTime(_filtroDataRange!.start.year, _filtroDataRange!.start.month, _filtroDataRange!.start.day);
        final dataEndZero = DateTime(_filtroDataRange!.end.year, _filtroDataRange!.end.month, _filtroDataRange!.end.day);

        if (dataItemZero.isBefore(dataStartZero) || dataItemZero.isAfter(dataEndZero)) {
          return false;
        }
      }

      return true;
    }).toList();

    return Column(
      children: [
        // 🚀 NOVO PAINEL SUPERIOR: Caixa de Pesquisa + Seletor de Range
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Barra de Pesquisa por Nome
              TextField(
                controller: _buscaNomeController,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) => setState(() {}), // Atualiza a lista a cada letra digitada
                decoration: _buildInputDecoration("Procurar por nome do desafio...", Icons.search),
              ),
              const SizedBox(height: 12),
              
              // Botão do Seletor de Período (Date Range)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selecionarDataRangeFiltro(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range_outlined, color: Color(0xFF00E676), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _filtroDataRange == null 
                                    ? "Filtrar por Período de Início" 
                                    : "Período: ${_filtroDataRange!.start.day}/${_filtroDataRange!.start.month} até ${_filtroDataRange!.end.day}/${_filtroDataRange!.end.month}/${_filtroDataRange!.end.year}",
                                style: TextStyle(color: _filtroDataRange == null ? Colors.white54 : Colors.white, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_filtroDataRange != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _filtroDataRange = null),
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      tooltip: "Limpar Período",
                    )
                  ]
                ],
              ),
            ],
          ),
        ),

        // Lista de Desafios Ativos e Filtrados
        Expanded(
          child: RefreshIndicator(
            onRefresh: _buscarDesafiosDoSupabase,
            color: const Color(0xFF00E676),
            child: desafiosFiltrados.isEmpty
                ? const Center(child: Text("Nenhum desafio correspondente encontrado.", style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: desafiosFiltrados.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = desafiosFiltrados[index];
                      final dynamic id = item['id'];
                      final String nome = item['nome'] ?? 'Sem nome';
                      final double valor = double.tryParse(item['valor_entrada']?.toString() ?? '') ?? 0.0;
                      
                      final dtInicio = DateTime.tryParse(item['data_inicio'] ?? '') ?? DateTime.now();
                      final String inicioFormatado = "${dtInicio.day.toString().padLeft(2, '0')}/${dtInicio.month.toString().padLeft(2, '0')}/${dtInicio.year}";

                      return Card(
                        color: const Color(0xFF1A1A1A),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(Icons.emoji_events, color: Color(0xFF00E676)),
                          ),
                          title: Text(nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Inicia em: $inicioFormatado\nValor: R\$ ${valor.toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _mostrarDialogExclusao(id, nome),
                            tooltip: "Excluir Desafio",
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: const Color(0xFF00E676)),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}