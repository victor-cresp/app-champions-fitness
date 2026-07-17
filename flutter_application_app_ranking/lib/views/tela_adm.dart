import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/supabase_client.dart';
import '../core/app_theme.dart';
import '../core/date_utils.dart';

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

  final _buscaNomeController = TextEditingController();
  DateTimeRange? _filtroDataRange;

  // 🚀 NOVAS VARIÁVEIS PARA ABA DE MODERAÇÃO DE VÍDEOS COM SUPORTE A PAGINAÇÃO
  List<dynamic> _videosParaAnalise = [];
  bool _carregandoVideos = false;

  // 🚀 VARIÁVEIS DE PAGINAÇÃO DE ALTA PERFORMANCE (CORRIGIDO: INJETADAS NO STATE)
  final int _itensPorPagina = 10;
  int _paginaAtual = 0;
  bool _temMaisDados = true;
  bool _carregandoMais = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _buscarVideosParaAnalise(resetar: true);

    // Ouvinte da barra de rolagem (Dispara carregamento automático ao atingir 80% da tela)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _buscarVideosParaAnalise(resetar: false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tituloController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    _dataInicioController.dispose();
    _dataLimiteInscricaoController.dispose();
    _dataFimController.dispose();
    _buscaNomeController.dispose();
    super.dispose();
  }

  // 🚀 BUSCA INSCRIÇÕES COM PAGINAÇÃO E INFINITE SCROLL (.range() NATIVO DO SUPABASE)
  Future<void> _buscarVideosParaAnalise({bool resetar = false}) async {
    if (!mounted) return;
    if (_carregandoVideos || _carregandoMais) return;
    if (!resetar && !_temMaisDados) return;

    setState(() {
      if (resetar) {
        _carregandoVideos = true;
        _paginaAtual = 0;
        _temMaisDados = true;
        _videosParaAnalise = [];
      } else {
        _carregandoMais = true;
      }
    });

    try {
      final int de = _paginaAtual * _itensPorPagina;
      final int ate = de + _itensPorPagina - 1;

      print("ADM: Buscando bloco de $de até $ate...");

      final dados = await supabase
          .from('participantes_desafios')
          .select('*, usuarios(nome), desafios(nome)')
          .eq('status_video', 'em_analise')
          .order('created_at', ascending: true)
          .range(de, ate);

      setState(() {
        _videosParaAnalise.addAll(dados);
        _carregandoVideos = false;
        _carregandoMais = false;

        if (dados.length < _itensPorPagina) {
          _temMaisDados = false;
        } else {
          _paginaAtual++;
        }
      });
    } catch (e) {
      setState(() {
        _carregandoVideos = false;
        _carregandoMais = false;
      });
      print("Erro ao carregar moderação: $e");
    }
  }

  // 🚀 AUXILIAR: ENTRA COM O PLAYER DE VÍDEO INTEGRADO EM MODAL
  void _assistirVideoInline(String url, String tituloVideo) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) =>
          ModalPlayerVideo(urlVideo: url, titulo: tituloVideo),
    );
  }

  // 🚀 ATUALIZA O STATUS DO VÍDEO DO ATLETA (APROVADO/REPROVADO) VIA RPC SEGURO
  Future<void> _moderarVideo(String inscricaoId, String novoStatus) async {
    try {
      // Chamando via RPC seguro interno do Supabase
      await supabase.rpc(
        'moderar_pesagem',
        params: {'inscricao_id': inscricaoId, 'novo_status': novoStatus},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              novoStatus == 'aprovado'
                  ? "✅ Pesagem Homologada via Função!"
                  : "❌ Vídeo Reprovado via Função.",
            ),
            backgroundColor: novoStatus == 'aprovado'
                ? AppColors.success
                : AppColors.error,
          ),
        );
        _buscarVideosParaAnalise(resetar: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao salvar decisão: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _buscarDesafiosDoSupabase() async {
    setState(() => _carregandoListagem = true);
    try {
      final dados = await supabase
          .from('desafios')
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
          SnackBar(
            content: Text("❌ Erro ao listar desafios: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _excluirDesafio(dynamic desafioId) async {
    try {
      await supabase
          .from('desafios')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', desafioId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🗑️ Desafio arquivado/excluído com sucesso!"),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      _buscarDesafiosDoSupabase();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Erro ao excluir: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _atualizarDuracao() {
    if (_dataInicioSelecionada != null && _dataFimSelecionada != null) {
      final diferenca = _dataFimSelecionada!
          .difference(_dataInicioSelecionada!)
          .inDays;
      setState(() {
        _duracaoTexto = diferenca > 0 ? "$diferenca" : "0";
      });
    }
  }

  Future<void> _selecionarData(BuildContext context, int tipoData) async {
    DateTime dataInicialCalendario = DateTime.now();
    DateTime primeiroDiaDisponivel = DateTime.now().subtract(
      const Duration(days: 365),
    );
    DateTime ultimoDiaDisponivel = DateTime.now().add(
      const Duration(days: 365),
    );

    if (tipoData == 2 && _dataInicioSelecionada != null) {
      dataInicialCalendario = _dataInicioSelecionada!;
      primeiroDiaDisponivel = _dataInicioSelecionada!;
      ultimoDiaDisponivel = _dataInicioSelecionada!.add(
        const Duration(days: 5),
      );
    }

    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: dataInicialCalendario,
      firstDate: primeiroDiaDisponivel,
      lastDate: ultimoDiaDisponivel,
    );

    if (escolhida != null) {
      setState(() {
        String dataFormatada = escolhida.formatted;

        if (tipoData == 1) {
          _dataInicioSelecionada = escolhida;
          _dataInicioController.text = dataFormatada;
          _dataLimiteSelecionada = null;
          _dataLimiteInscricaoController.clear();
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
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
              surface: AppColors.surface,
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
            content: Text(
              "❌ A data de término não pode ser antes da data de início!",
            ),
            backgroundColor: AppColors.error,
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

      await supabase.from('desafios').insert({
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
          const SnackBar(
            content: Text("🚀 Novo desafio lançado com sucesso!"),
            backgroundColor: AppColors.success,
          ),
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
          SnackBar(
            content: Text("❌ Erro ao lançar desafio: $e"),
            backgroundColor: AppColors.error,
          ),
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
        backgroundColor: AppColors.card,
        title: const Text(
          "Excluir Desafio?",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Tem certeza que deseja remover o desafio '$nome'?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CANCELAR",
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _excluirDesafio(id);
            },
            child: const Text(
              "CONFIRMAR",
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text(
            "Painel do Administrador",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.add_box_outlined), text: "Lançar"),
              Tab(icon: Icon(Icons.settings_outlined), text: "Gerenciar"),
              Tab(icon: Icon(Icons.rate_review_outlined), text: "Vídeos"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAbaLancamento(),
            _buildAbaGerenciamento(),
            _buildAbaModerarVideos(),
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
              decoration: _buildInputDecoration(
                "Nome do Desafio",
                Icons.emoji_events_outlined,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? "O nome é obrigatório" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descricaoController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                "Descrição / Regras do Desafio",
                Icons.description_outlined,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? "A descrição é obrigatória"
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                "Valor da Aposta (em Reais)",
                Icons.attach_money,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return "O valor é obrigatório";
                if (double.tryParse(v.replaceAll(',', '.').trim()) == null)
                  return "Número inválido";
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dataInicioController,
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                "Data de Início do Desafio",
                Icons.calendar_today_outlined,
              ),
              onTap: () => _selecionarData(context, 1),
              validator: (v) => v == null || v.isEmpty
                  ? "A data de início é obrigatória"
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dataLimiteInscricaoController,
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                "Data Limite de Inscrição",
                Icons.event_busy_outlined,
              ),
              onTap: () => _selecionarData(context, 2),
              validator: (v) =>
                  v == null || v.isEmpty ? "A data limite é obrigatória" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dataFimController,
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                "Data de Término do Desafio",
                Icons.gavel_outlined,
              ),
              onTap: () => _selecionarData(context, 3),
              validator: (v) => v == null || v.isEmpty
                  ? "A data de término é obrigatória"
                  : null,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.timelapse, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Text(
                    "Duração Calculada: ",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    "$_duracaoTexto dias",
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Lançar Desafio",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaGerenciamento() {
    if (_carregandoListagem) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final desafiosFiltrados = _desafiosCadastrados.where((item) {
      final String nomeDesafio = (item['nome'] ?? '').toString().toLowerCase();
      final String termoBusca = _buscaNomeController.text.toLowerCase().trim();
      if (termoBusca.isNotEmpty && !nomeDesafio.contains(termoBusca)) {
        return false;
      }

      if (_filtroDataRange != null) {
        final dataInicioItem = DateTime.tryParse(item['data_inicio'] ?? '');
        if (dataInicioItem == null) return false;

        final dataItemZero = DateTime(
          dataInicioItem.year,
          dataInicioItem.month,
          dataInicioItem.day,
        );
        final dataStartZero = DateTime(
          _filtroDataRange!.start.year,
          _filtroDataRange!.start.month,
          _filtroDataRange!.start.day,
        );
        final dataEndZero = DateTime(
          _filtroDataRange!.end.year,
          _filtroDataRange!.end.month,
          _filtroDataRange!.end.day,
        );

        if (dataItemZero.isBefore(dataStartZero) ||
            dataItemZero.isAfter(dataEndZero)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _buscaNomeController,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) => setState(() {}),
                decoration: _buildInputDecoration(
                  "Procurar por nome do desafio...",
                  Icons.search,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selecionarDataRangeFiltro(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.date_range_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _filtroDataRange == null
                                    ? "Filtrar por Período de Início"
                                    : "Período: ${_filtroDataRange!.start.day}/${_filtroDataRange!.start.month} até ${_filtroDataRange!.end.day}/${_filtroDataRange!.end.month}/${_filtroDataRange!.end.year}",
                                style: TextStyle(
                                  color: _filtroDataRange == null
                                      ? Colors.white54
                                      : Colors.white,
                                  fontSize: 14,
                                ),
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
                      icon: const Icon(Icons.close, color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _buscarDesafiosDoSupabase,
            color: AppColors.primary,
            child: desafiosFiltrados.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhum desafio correspondente encontrado.",
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    itemCount: desafiosFiltrados.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = desafiosFiltrados[index];
                      final dynamic id = item['id'];
                      final String nome = item['nome'] ?? 'Sem nome';
                      final double valor =
                          double.tryParse(
                            item['valor_entrada']?.toString() ?? '',
                          ) ??
                          0.0;
                      final dtInicio =
                          DateTime.tryParse(item['data_inicio'] ?? '') ??
                          DateTime.now();
                      final String inicioFormatado = dtInicio.formatted;

                      return Card(
                        color: AppColors.card,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(
                              Icons.emoji_events,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            nome,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Inicia em: $inicioFormatado\nValor: R\$ ${valor.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () => _mostrarDialogExclusao(id, nome),
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

  // 🚀 INTERFACE DA FILA DE MODERAÇÃO TOTALMENTE OTIMIZADA COM PAGINAÇÃO INFINITA
  Widget _buildAbaModerarVideos() {
    if (_carregandoVideos) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _buscarVideosParaAnalise(resetar: true),
      color: AppColors.primary,
      child: _videosParaAnalise.isEmpty
          ? const Center(
              child: Text(
                "🎉 Tudo limpo! Nenhum vídeo pendente de análise.",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              controller: _scrollController, // 🚀 ESCUTA A ROLAGEM AQUI
              itemCount: _videosParaAnalise.length + (_temMaisDados ? 1 : 0),
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                // Se atingir o final da lista carregada e houver mais dados, exibe loader no rodapé
                if (index == _videosParaAnalise.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                final inscricao = _videosParaAnalise[index];

                final usuarioNome =
                    inscricao['usuarios']?['nome'] ?? 'Atleta Desconhecido';
                final desafioNome =
                    inscricao['desafios']?['nome'] ??
                    'Desafio não identificado';
                final codigoEscrito = inscricao['codigo_verificacao'] ?? '---';

                final urlRosto = inscricao['video_rosto_url'] ?? '';
                final urlPeso = inscricao['video_peso_url'] ?? '';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  usuarioNome,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Desafio: $desafioNome",
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "CÓDIGO: $codigoEscrito",
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),

                      const Text(
                        "VÍDEOS DA PESAGEM:",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Botões Inline que chamam o Player de Vídeo Integrado
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                              ),
                              icon: const Icon(
                                Icons.person_pin,
                                color: AppColors.info,
                              ),
                              label: const Text(
                                "Vídeo Rosto",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              // 🚀 ATUALIZADO: Abre o player diretamente dentro do app
                              onPressed: urlRosto.isEmpty
                                  ? null
                                  : () => _assistirVideoInline(
                                      urlRosto,
                                      "Vídeo do Rosto ($usuarioNome)",
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                              ),
                              icon: const Icon(
                                Icons.monitor_weight_outlined,
                                color: AppColors.warning,
                              ),
                              label: const Text(
                                "Vídeo Peso",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              // 🚀 ATUALIZADO: Abre o player diretamente dentro do app
                              onPressed: urlPeso.isEmpty
                                  ? null
                                  : () => _assistirVideoInline(
                                      urlPeso,
                                      "Vídeo do Peso ($usuarioNome)",
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Botões de Ação para o ADM homologar
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error.withValues(
                                  alpha: 0.2,
                                ),
                                foregroundColor: AppColors.error,
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.close),
                              label: const Text(
                                "REPROVAR",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _moderarVideo(
                                inscricao['id'].toString(),
                                'reprovado',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: AppColors.onPrimary,
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.check),
                              label: const Text(
                                "APROVAR",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _moderarVideo(
                                inscricao['id'].toString(),
                                'aprovado',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return buildInputDecoration(label: label, icon: icon);
  }
}

// ============================================================================
// 🚀 WIDGET COMPLEMENTAR: MODAL COMPLETO COM PLAYER DE ALTA PERFORMANCE
// ============================================================================
class ModalPlayerVideo extends StatefulWidget {
  final String urlVideo;
  final String titulo;

  const ModalPlayerVideo({
    super.key,
    required this.urlVideo,
    required this.titulo,
  });

  @override
  State<ModalPlayerVideo> createState() => _ModalPlayerVideoState();
}

class _ModalPlayerVideoState extends State<ModalPlayerVideo> {
  late VideoPlayerController _controller;
  bool _inicializado = false;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.urlVideo))
      ..initialize()
          .then((_) {
            setState(() {
              _inicializado = true;
              _controller.play();
              _controller.setLooping(true);
            });
          })
          .catchError((e) {
            setState(() => _erro = true);
            print("Erro ao carregar o vídeo no player: $e");
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: _erro
            ? const Center(
                child: Text(
                  "❌ Erro ao reproduzir vídeo.\nVerifique se o Bucket é público.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
              )
            : _inicializado
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (!_controller.value.isPlaying)
                      const CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                  ],
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
      ),
    );
  }
}
