import 'package:flutter/material.dart';
import 'package:gabarito_plus/widgets/menu_opcoes.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/disciplina/data/disciplina.dart';
import 'package:gabarito_plus/features/disciplina/service/disciplinas_service.dart';
 
class ConsultaDisciplinasView extends StatefulWidget {
  const ConsultaDisciplinasView({super.key});
 
  @override
  State<ConsultaDisciplinasView> createState() =>
      _ConsultaDisciplinasViewState();
}
 
class _ConsultaDisciplinasViewState extends State<ConsultaDisciplinasView> {
  final _service = DisciplinasService();
  final _buscaController = TextEditingController();
  String? _disciplinaExpandidaId;
  List<Disciplina> _disciplinas = [];
  bool _carregando = true;
 
  @override
  void initState() {
    super.initState();
    _carregarDisciplinas();
  }
 
  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }
 
  Future<void> _carregarDisciplinas() async {
    try {
      final disciplinas = await _service.listarDisciplinas();
      if (!mounted) return;
      setState(() {
        _disciplinas = disciplinas;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar disciplinas: $e')),
      );
    }
  }
 
  List<Disciplina> get _disciplinasFiltradas {
    final todas = _disciplinas;
    final termo = _buscaController.text.trim().toLowerCase();
    if (termo.isEmpty) return todas;
 
    return todas.where((d) {
      final bateDisciplina = d.descricao.toLowerCase().contains(termo);
      final bateAssunto =
          d.assuntos.any((a) => a.nome.toLowerCase().contains(termo));
      return bateDisciplina || bateAssunto;
    }).toList();
  }
 
  // ---------------------------------------------------------------------------
  // Utilitários
  // ---------------------------------------------------------------------------
 
  void _mensagem(String texto, {Color? cor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: cor),
    );
  }
 
  Future<String?> _abrirModal(WidgetBuilder builder) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: builder,
    );
  }
 
  // ---------------------------------------------------------------------------
  // Cadastro
  // ---------------------------------------------------------------------------
 
  void _exibirOpcoesCadastro() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'O que você deseja cadastrar?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.school,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Criar Disciplina',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle:
                      const Text('Cadastre uma nova disciplina no sistema'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _exibirModalNovaDisciplina();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: const Icon(
                      Icons.topic,
                      color: Colors.purple,
                    ),
                  ),
                  title: const Text(
                    'Criar Assunto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle:
                      const Text('Adicione um novo assunto a uma disciplina'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _exibirModalNovoAssunto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
 
  Future<void> _exibirModalNovaDisciplina() async {
    final disciplinaIdCriada =
        await _abrirModal((_) => const ModalCadastroDisciplina());
 
    if (disciplinaIdCriada != null) {
      _disciplinaExpandidaId = disciplinaIdCriada;
      await _carregarDisciplinas();
    }
  }
 
  Future<void> _exibirModalNovoAssunto() async {
    final disciplinaIdAtualizada = await _abrirModal(
      (_) => ModalCadastroAssunto(disciplinas: _disciplinas),
    );
 
    if (disciplinaIdAtualizada != null) {
      _disciplinaExpandidaId = disciplinaIdAtualizada;
      await _carregarDisciplinas();
    }
  }
 
  // ---------------------------------------------------------------------------
  // Manutenção: disciplina
  // ---------------------------------------------------------------------------
 
  Future<void> _editarDisciplina(Disciplina disciplina) async {
    final id = await _abrirModal(
      (_) => ModalCadastroDisciplina(disciplina: disciplina),
    );
    if (id != null) {
      _disciplinaExpandidaId = id;
      await _carregarDisciplinas();
    }
  }
 
  Future<void> _excluirDisciplina(Disciplina disciplina) async {
    if (disciplina.assuntos.isNotEmpty) {
      _mensagem(
        'Exclua ou mova os ${disciplina.assuntos.length} assunto(s) '
        'desta disciplina antes de excluí-la.',
        cor: Colors.orange,
      );
      return;
    }
    final ok = await confirmarExclusao(
      context,
      titulo: 'Excluir disciplina',
      mensagem: 'Deseja excluir "${disciplina.descricao}"?',
    );
    if (!ok) return;
 
    try {
      await _service.excluirDisciplina(disciplina.id);
      if (!mounted) return;
      _mensagem('Disciplina excluída!', cor: Colors.green);
      await _carregarDisciplinas();
    } catch (e) {
      if (!mounted) return;
      _mensagem('Erro ao excluir disciplina: $e');
    }
  }
 
  // ---------------------------------------------------------------------------
  // Manutenção: assunto
  // ---------------------------------------------------------------------------
 
  Future<void> _editarAssunto(Disciplina disciplina, Assunto assunto) async {
    final id = await _abrirModal(
      (_) => ModalCadastroAssunto(
        disciplinas: _disciplinas,
        assunto: assunto,
        disciplinaInicialId: disciplina.id,
      ),
    );
    if (id != null) {
      _disciplinaExpandidaId = id;
      await _carregarDisciplinas();
    }
  }
 
  Future<void> _excluirAssunto(Disciplina disciplina, Assunto assunto) async {
    if (assunto.questoes.isNotEmpty) {
      _mensagem(
        'Este assunto possui ${assunto.questoes.length} questão(ões) '
        'e não pode ser excluído.',
        cor: Colors.orange,
      );
      return;
    }
    final ok = await confirmarExclusao(
      context,
      titulo: 'Excluir assunto',
      mensagem: 'Deseja excluir "${assunto.nome}"?',
    );
    if (!ok) return;
 
    try {
      await _service.excluirAssunto(assunto.id);
      if (!mounted) return;
      _disciplinaExpandidaId = disciplina.id;
      _mensagem('Assunto excluído!', cor: Colors.green);
      await _carregarDisciplinas();
    } catch (e) {
      if (!mounted) return;
      _mensagem('Erro ao excluir assunto: $e');
    }
  }
 
  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
 
  @override
  Widget build(BuildContext context) {
    final disciplinas = _disciplinasFiltradas;
 
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disciplinas & Assuntos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de Busca
            TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Buscar disciplina ou assunto...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscaController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscaController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
 
            // Lista de Disciplinas e Assuntos
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : disciplinas.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma disciplina ou assunto encontrado.',
                          ),
                        )
                      : ListView.separated(
                          itemCount: disciplinas.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final disciplina = disciplinas[index];
                            final isExpandida =
                                disciplina.id == _disciplinaExpandidaId;
 
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ExpansionTile(
                                key: ValueKey(
                                  '${disciplina.id}_$isExpandida',
                                ),
                                initiallyExpanded: isExpandida,
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Icon(
                                    Icons.school,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                title: Text(
                                  disciplina.descricao,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${disciplina.assuntos.length} assunto(s) cadastrado(s)',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MenuOpcoes(
                                      tooltip: 'Opções da disciplina',
                                      onEditar: () =>
                                          _editarDisciplina(disciplina),
                                      onExcluir: () =>
                                          _excluirDisciplina(disciplina),
                                    ),
                                    Icon(
                                      isExpandida
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                    ),
                                  ],
                                ),
                                children: disciplina.assuntos.isEmpty
                                    ? [
                                        const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Text(
                                            'Nenhum assunto cadastrado para esta disciplina.',
                                            style:
                                                TextStyle(color: Colors.grey),
                                          ),
                                        ),
                                      ]
                                    : disciplina.assuntos.map((assunto) {
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.topic,
                                            color: Colors.purple,
                                          ),
                                          title: Text(assunto.nome),
                                          subtitle: Text(
                                            '${assunto.questoes.length} questão(ões)',
                                          ),
                                          trailing: MenuOpcoes(
                                            tooltip: 'Opções do assunto',
                                            onEditar: () => _editarAssunto(
                                              disciplina,
                                              assunto,
                                            ),
                                            onExcluir: () => _excluirAssunto(
                                              disciplina,
                                              assunto,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar',
        onPressed: _exibirOpcoesCadastro,
        child: const Icon(Icons.add),
      ),
    );
  }
}
 
// =============================================================================
// Modal: cadastro / edição de disciplina
// =============================================================================
 
class ModalCadastroDisciplina extends StatefulWidget {
  final VoidCallback? onSalvo;
 
  /// null = cadastro; preenchida = edição.
  final Disciplina? disciplina;
 
  const ModalCadastroDisciplina({super.key, this.onSalvo, this.disciplina});
 
  @override
  State<ModalCadastroDisciplina> createState() =>
      _ModalCadastroDisciplinaState();
}
 
class _ModalCadastroDisciplinaState extends State<ModalCadastroDisciplina> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  final _service = DisciplinasService();
  bool _salvando = false;
 
  bool get _editando => widget.disciplina != null;
 
  @override
  void initState() {
    super.initState();
    _nomeController =
        TextEditingController(text: widget.disciplina?.descricao ?? '');
  }
 
  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }
 
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
 
    final nomeDisciplina = _nomeController.text.trim();
    setState(() => _salvando = true);
 
    try {
      final jaExiste = await _service.existeDisciplina(
        nomeDisciplina,
        ignorarId: widget.disciplina?.id,
      );
      if (!mounted) return;
 
      if (jaExiste) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta disciplina já está cadastrada!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
 
      final String id;
      if (_editando) {
        id = widget.disciplina!.id;
        await _service.atualizarDisciplina(id: id, descricao: nomeDisciplina);
      } else {
        id = await _service.criarDisciplina(nomeDisciplina);
      }
      if (!mounted) return;
 
      widget.onSalvo?.call();
 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editando
                ? 'Disciplina atualizada com sucesso!'
                : 'Disciplina cadastrada com sucesso!',
          ),
          backgroundColor: Colors.green,
        ),
      );
 
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar disciplina: $e')),
      );
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _editando
                            ? 'Editar Disciplina'
                            : 'Cadastrar Nova Disciplina',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Disciplina',
                    prefixIcon: Icon(Icons.school),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da disciplina';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Salvar',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
 
// =============================================================================
// Modal: cadastro / edição de assunto
// =============================================================================
 
class ModalCadastroAssunto extends StatefulWidget {
  final List<Disciplina> disciplinas;
  final VoidCallback? onSalvo;
 
  /// null = cadastro; preenchido = edição.
  final Assunto? assunto;
 
  /// Disciplina atual do assunto (usada na edição).
  final String? disciplinaInicialId;
 
  const ModalCadastroAssunto({
    super.key,
    required this.disciplinas,
    this.onSalvo,
    this.assunto,
    this.disciplinaInicialId,
  });
 
  @override
  State<ModalCadastroAssunto> createState() => _ModalCadastroAssuntoState();
}
 
class _ModalCadastroAssuntoState extends State<ModalCadastroAssunto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  final _service = DisciplinasService();
  Disciplina? _disciplinaSelecionada;
  bool _salvando = false;
 
  bool get _editando => widget.assunto != null;
 
  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.assunto?.nome ?? '');
    if (widget.disciplinaInicialId != null) {
      for (final d in widget.disciplinas) {
        if (d.id == widget.disciplinaInicialId) {
          _disciplinaSelecionada = d;
          break;
        }
      }
    }
  }
 
  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }
 
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
 
    final disciplina = _disciplinaSelecionada!;
    final nomeAssunto = _nomeController.text.trim();
    setState(() => _salvando = true);
 
    try {
      if (_editando) {
        await _service.atualizarAssunto(
          id: widget.assunto!.id,
          nome: nomeAssunto,
          disciplinaId: disciplina.id,
        );
      } else {
        await _service.criarAssunto(
          disciplinaId: disciplina.id,
          nome: nomeAssunto,
        );
      }
      if (!mounted) return;
 
      widget.onSalvo?.call();
 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editando
                ? 'Assunto atualizado com sucesso!'
                : 'Assunto cadastrado com sucesso!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, disciplina.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar assunto: $e')),
      );
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _editando
                            ? 'Editar Assunto'
                            : 'Cadastrar Novo Assunto',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<Disciplina>(
                  initialValue: _disciplinaSelecionada,
                  decoration: const InputDecoration(
                    labelText: 'Disciplina',
                    prefixIcon: Icon(Icons.school),
                    border: OutlineInputBorder(),
                  ),
                  items: widget.disciplinas.map((disciplina) {
                    return DropdownMenuItem<Disciplina>(
                      value: disciplina,
                      child: Text(disciplina.descricao),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _disciplinaSelecionada = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione uma disciplina';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Assunto',
                    prefixIcon: Icon(Icons.topic),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do assunto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Salvar',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
 