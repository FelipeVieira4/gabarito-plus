import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/disciplina/data/disciplina.dart';
import 'package:gabarito_plus/features/provas/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/visualizacao_embaralhamento.dart';
import 'package:gabarito_plus/features/provas/service/prova_repository.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';
import 'package:gabarito_plus/features/questoes/service/questoes_service.dart';
import 'package:gabarito_plus/features/turma/data/turma.dart';
import 'package:gabarito_plus/features/turma/service/turma_service.dart';


class ConfiguracaoProva extends StatefulWidget {
  const ConfiguracaoProva({super.key});

  @override
  State<ConfiguracaoProva> createState() => _ConfiguracaoProvaState();
}

class _ConfiguracaoProvaState extends State<ConfiguracaoProva> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _questoesPorProvaController = TextEditingController();
  final _questoesService = QuestoesService();
  final _turmaService = TurmaService();

  List<Disciplina> _disciplinas = [];
  bool _carregandoDisciplinas = true;

  List<Turma> _turmas = [];
  bool _carregandoTurmas = true;

  Disciplina? _disciplinaSelecionada;
  Assunto? _assuntoSelecionado;
  Turma? _turmaSelecionada;

  final Set<Questao> _questoesSelecionadas = {};

  /// Opção "Todos os assuntos" do dropdown: lista as questões de todos os
  /// assuntos da disciplina.
  final _todosAssuntos = Assunto(id: '__todos__', nome: 'Todos os assuntos', questoes: []);

  bool get _todosSelecionado => _assuntoSelecionado == _todosAssuntos;

  /// Assuntos cujas questões aparecem na lista.
  List<Assunto> get _assuntosExibidos {
    if (_disciplinaSelecionada == null || _assuntoSelecionado == null) return [];
    return _todosSelecionado
        ? _disciplinaSelecionada!.assuntos
        : [_assuntoSelecionado!];
  }

  bool _embaralharQuestoes = true;
  bool _embaralharAlternativas = true;

  /// Cada aluno recebe [_questoesPorProva] questões sorteadas das selecionadas.
  bool _sortearQuestoes = false;

  int? get _questoesPorProva =>
      int.tryParse(_questoesPorProvaController.text.trim());

  @override
  void initState() {
    super.initState();
    _carregarDisciplinas();
    _carregarTurmas();
  }

  Future<void> _carregarTurmas() async {
    try {
      final turmas = await _turmaService.listarTurmas(apenasAtivas: true);
      if (!mounted) return;
      setState(() {
        _turmas = turmas;
        _carregandoTurmas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoTurmas = false);
      _mostrarAviso('Erro ao carregar turmas: $e');
    }
  }

  Future<void> _carregarDisciplinas() async {
    try {
      final disciplinas = await _questoesService.obterDisciplinas();
      if (!mounted) return;
      setState(() {
        _disciplinas = disciplinas;
        _carregandoDisciplinas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoDisciplinas = false);
      _mostrarAviso('Erro ao carregar disciplinas: $e');
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _questoesPorProvaController.dispose();
    super.dispose();
  }

  List<Questao> get _questoesExibidas =>
      _assuntosExibidos.expand((assunto) => assunto.questoes).toList();

  void _gerarProvas() {
    if (!_formKey.currentState!.validate()) return;

    if (_turmaSelecionada == null) {
      _mostrarAviso('Selecione uma turma para aplicar a prova');
      return;
    }

    if (_disciplinaSelecionada == null) {
      _mostrarAviso('Selecione a disciplina da prova');
      return;
    }

    if (_assuntoSelecionado == null) {
      _mostrarAviso('Selecione o assunto da prova');
      return;
    }

    if (_questoesSelecionadas.isEmpty) {
      _mostrarAviso('Selecione ao menos uma questão para a prova');
      return;
    }

    if (_sortearQuestoes) {
      final porProva = _questoesPorProva;
      if (porProva == null || porProva < 1) {
        _mostrarAviso('Informe quantas questões cada prova deve ter');
        return;
      }
      if (porProva > _questoesSelecionadas.length) {
        _mostrarAviso(
          'Cada prova pede $porProva questões, mas só '
          '${_questoesSelecionadas.length} foram selecionadas',
        );
        return;
      }
    }

    if (_turmaSelecionada!.listaAlunos.isEmpty) {
      _mostrarAviso('A turma selecionada não possui alunos cadastrados');
      return;
    }

    final prova = Prova(
      id: gerarIdProva(),
      titulo: _tituloController.text.trim(),
      turma: _turmaSelecionada!,
      assunto: _todosSelecionado
          ? Assunto(id: '', nome: 'Todos os assuntos', questoes: _questoesExibidas)
          : _assuntoSelecionado!,
      disciplinaId: _disciplinaSelecionada!.id,
      nomeDisciplina: _disciplinaSelecionada!.descricao,
      questoes: _questoesSelecionadas.toList(),
      questoesPorProva: _sortearQuestoes ? _questoesPorProva : null,
      embaralharQuestoes: _embaralharQuestoes,
      embaralharAlternativas: _embaralharAlternativas,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisualizacaoEmbaralhamento(prova: prova),
      ),
    );
  }

  void _mostrarAviso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  void _alternarSelecaoTodasQuestoes(bool? selecionarTodas) {
    setState(() {
      if (selecionarTodas == true) {
        _questoesSelecionadas.addAll(_questoesExibidas);
      } else {
        _questoesSelecionadas.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração da Prova'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Campo Título
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título da Prova',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o título da prova';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Seleção de Turma
              DropdownButtonFormField<Turma>(
                initialValue: _turmaSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Turma',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.class_),
                ),
                hint: _carregandoTurmas
                    ? const Text('Carregando turmas...')
                    : null,
                items: _turmas
                    .map((turma) => DropdownMenuItem(
                          value: turma,
                          child: Text(
                            turma.nomeTurma,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (turma) => setState(() => _turmaSelecionada = turma),
                validator: (value) => value == null ? 'Selecione uma turma' : null,
              ),
              const SizedBox(height: 16),

              // Seleção de Disciplina
              DropdownButtonFormField<Disciplina>(
                initialValue: _disciplinaSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Disciplina',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                hint: _carregandoDisciplinas
                    ? const Text('Carregando disciplinas...')
                    : null,
                items: _disciplinas
                    .map((disciplina) => DropdownMenuItem(
                          value: disciplina,
                          child: Text(
                            disciplina.descricao,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (disciplina) {
                  setState(() {
                    _disciplinaSelecionada = disciplina;
                    _assuntoSelecionado = null;
                    _questoesSelecionadas.clear();
                  });
                },
                validator: (value) =>
                    value == null ? 'Selecione uma disciplina' : null,
              ),
              const SizedBox(height: 16),

              // Seleção de Assunto
              DropdownButtonFormField<Assunto>(
                initialValue: _assuntoSelecionado,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assunto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.topic),
                ),
                items: [
                  if (_disciplinaSelecionada != null &&
                      _disciplinaSelecionada!.assuntos.isNotEmpty)
                    DropdownMenuItem(
                      value: _todosAssuntos,
                      child: const Text(
                        'Todos os assuntos',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ...(_disciplinaSelecionada?.assuntos ?? <Assunto>[])
                      .map((assunto) => DropdownMenuItem(
                            value: assunto,
                            child: Text(
                              assunto.nome,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                ],
                onChanged: _disciplinaSelecionada == null
                    ? null
                    : (assunto) {
                        setState(() {
                          _assuntoSelecionado = assunto;
                          _questoesSelecionadas.clear();
                        });
                      },
                validator: (value) =>
                    value == null ? 'Selecione um assunto' : null,
              ),
              const SizedBox(height: 24),

              // Listagem de Questões do Assunto
              _buildSecaoQuestoes(),
              const SizedBox(height: 24),

              // Sorteio de questões diferentes por aluno
              _buildSecaoSorteio(),
              const SizedBox(height: 24),

              // Opções de Embaralhamento
              _buildSecaoEmbaralhamento(),
              const SizedBox(height: 24),

              // Botão Principal
              ElevatedButton.icon(
                onPressed: _gerarProvas,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Gerar Provas da Turma'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecaoQuestoes() {
    if (_disciplinaSelecionada == null) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Selecione uma disciplina para listar os assuntos disponíveis.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    if (_assuntoSelecionado == null) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Selecione um assunto para listar as questões disponíveis.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final questoesExibidas = _questoesExibidas;
    final totalQuestoes = questoesExibidas.length;
    final todasSelecionadas = totalQuestoes > 0 &&
        _questoesSelecionadas.length == totalQuestoes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _todosSelecionado
                    ? 'Questões de ${_disciplinaSelecionada!.descricao} (todos os assuntos)'
                    : 'Questões de ${_assuntoSelecionado!.nome} (${_disciplinaSelecionada!.descricao})',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (totalQuestoes > 0)
              TextButton(
                onPressed: () => _alternarSelecaoTodasQuestoes(!todasSelecionadas),
                child: Text(todasSelecionadas ? 'Desmarcar todas' : 'Marcar todas'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (totalQuestoes == 0)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _todosSelecionado
                    ? 'Nenhuma questão cadastrada para esta disciplina.'
                    : 'Nenhuma questão cadastrada para este assunto.',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final assunto in _assuntosExibidos)
                  if (assunto.questoes.isNotEmpty) ...[
                    // Cabeçalho do Assunto
                    Container(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha(50),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text(
                        'Assunto: ${assunto.nome} (${assunto.questoes.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // Lista de Questões do Assunto
                    ...assunto.questoes.map((questao) {
                      final selecionada = _questoesSelecionadas.contains(questao);

                      return Column(
                        children: [
                          CheckboxListTile(
                            value: selecionada,
                            title: Text(questao.enunciado),
                            subtitle: Text(
                              '${questao.alternativas.length} alternativas',
                            ),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _questoesSelecionadas.add(questao);
                                } else {
                                  _questoesSelecionadas.remove(questao);
                                }
                              });
                            },
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),
                  ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '${_questoesSelecionadas.length} de $totalQuestoes questões selecionadas',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSecaoSorteio() {
    final banco = _questoesSelecionadas.length;
    final porProva = _questoesPorProva;

    String? dica;
    if (_sortearQuestoes && porProva != null && porProva > 0 && porProva <= banco) {
      dica = porProva == banco
          ? 'Todas as provas terão as mesmas $banco questões. '
              'Selecione mais questões para variar.'
          : 'Cada aluno recebe $porProva das $banco questões selecionadas.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Questões por aluno',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                key: const Key('switch-sortear-questoes'),
                value: _sortearQuestoes,
                title: const Text('Sortear questões diferentes para cada aluno'),
                subtitle: const Text(
                  'As questões selecionadas viram um banco e cada prova '
                  'sorteia parte delas',
                ),
                onChanged: (value) => setState(() => _sortearQuestoes = value),
              ),
              if (_sortearQuestoes) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    key: const Key('campo-questoes-por-prova'),
                    controller: _questoesPorProvaController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Questões por prova',
                      helperText: dica ?? '$banco questões selecionadas no banco',
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.format_list_numbered),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (!_sortearQuestoes) return null;
                      final n = int.tryParse(value?.trim() ?? '');
                      if (n == null || n < 1) {
                        return 'Informe quantas questões cada prova terá';
                      }
                      if (n > banco) {
                        return 'Máximo de $banco (questões selecionadas)';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoEmbaralhamento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Embaralhamento',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _embaralharQuestoes,
                title: const Text('Embaralhar ordem das questões'),
                subtitle: const Text(
                  'Cada aluno recebe as questões em uma ordem diferente',
                ),
                onChanged: (value) => setState(() => _embaralharQuestoes = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _embaralharAlternativas,
                title: const Text('Embaralhar ordem das alternativas'),
                subtitle: const Text(
                  'A posição da alternativa correta muda a cada prova',
                ),
                onChanged: (value) =>
                    setState(() => _embaralharAlternativas = value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
