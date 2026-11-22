import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/disciplina/data/disciplina.dart';
import 'package:gabarito_plus/features/geracao_prova/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/service/prova_repository.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/visualizacao_embaralhamento.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';
import 'package:gabarito_plus/features/questoes/service/questoes_service.dart';
import 'package:gabarito_plus/features/turma/data/turma.dart';
import 'package:gabarito_plus/features/turma/service/turma_service.dart';


class ConfiguracaoProva extends StatefulWidget {
  const ConfiguracaoProva({super.key, this.provaEditada});

  /// Prova já salva a editar. Os campos vêm preenchidos e, ao regerar, as
  /// versões mantêm os códigos. A tela fecha devolvendo `true` ao salvar.
  final ProvaSalva? provaEditada;

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

  bool _embaralharQuestoes = true;
  bool _embaralharAlternativas = true;

  bool get _edicao => widget.provaEditada != null;
  bool _sortearQuestoes = false;

  int? get _questoesPorProva =>
      int.tryParse(_questoesPorProvaController.text.trim());

  @override
  void initState() {
    super.initState();
    final prova = widget.provaEditada;
    if (prova != null) {
      _tituloController.text = prova.titulo;
      _embaralharQuestoes = prova.embaralharQuestoes;
      _embaralharAlternativas = prova.embaralharAlternativas;
    }
    _carregarDisciplinas();
    _carregarTurmas();
  }

  /// Seleciona turma, disciplina, assunto e questões da prova editada. Roda
  /// uma vez, quando turmas e disciplinas terminam de carregar. O que não
  /// existe mais fica sem seleção, com um aviso.
  void _preencherEdicao() {
    final prova = widget.provaEditada;
    if (prova == null || _edicaoPreenchida) return;
    if (_carregandoTurmas || _carregandoDisciplinas) return;
    _edicaoPreenchida = true;

    final avisos = <String>[];

    final turma = _turmas.where((t) => t.id == prova.turmaId).firstOrNull;
    if (turma == null) avisos.add('a turma ${prova.nomeTurma} não está mais ativa');

    Disciplina? disciplina;
    Assunto? assunto;
    for (final d in _disciplinas) {
      assunto = d.assuntos.where((a) => a.id == prova.assuntoId).firstOrNull;
      if (assunto != null) {
        disciplina = d;
        break;
      }
    }
    if (assunto == null) avisos.add('o assunto ${prova.nomeAssunto} foi excluído');

    final questoes = (assunto?.questoes ?? const <Questao>[])
        .where((q) => prova.questoesIds.contains(q.id))
        .toList();
    final faltando = assunto == null ? 0 : prova.questoesIds.length - questoes.length;
    if (faltando > 0) {
      avisos.add(faltando == 1
          ? '1 questão foi excluída do banco'
          : '$faltando questões foram excluídas do banco');
    }

    setState(() {
      _turmaSelecionada = turma;
      _disciplinaSelecionada = disciplina;
      _assuntoSelecionado = assunto;
      _questoesSelecionadas
        ..clear()
        ..addAll(questoes);
    });

    if (avisos.isNotEmpty) {
      _mostrarAviso('Revise a prova: ${avisos.join('; ')}.');
    }
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
    _preencherEdicao();
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
    _preencherEdicao();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _questoesPorProvaController.dispose();
    super.dispose();
  }

  List<Questao> get _questoesExibidas {
    if (_disciplinaSelecionada == null) return [];
    if (_assuntoSelecionado != null) {
      return _assuntoSelecionado!.questoes;
    }
    return _disciplinaSelecionada!.assuntos
        .expand((assunto) => assunto.questoes)
        .toList();
  }

  Future<void> _gerarProvas() async {
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
      // na edição o id se mantém, e com ele os códigos das versões
      id: widget.provaEditada?.id ?? gerarIdProva(),
      titulo: _tituloController.text.trim(),
      turma: _turmaSelecionada!,
      assunto: _assuntoSelecionado!,
      questoes: _questoesSelecionadas.toList(),
      questoesPorProva: _sortearQuestoes ? _questoesPorProva : null,
      embaralharQuestoes: _embaralharQuestoes,
      embaralharAlternativas: _embaralharAlternativas,
    );

    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VisualizacaoEmbaralhamento(prova: prova, edicao: _edicao),
      ),
    );
    if (salvou == true && _edicao && mounted) Navigator.pop(context, true);
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
        title: Text(_edicao ? 'Editar Prova' : 'Configuração da Prova'),
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
                // initialValue só é lido ao criar o campo: a key o recria
                // quando a seleção muda por código (preenchimento da edição)
                key: ValueKey('turma-${_turmaSelecionada?.id}'),
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
                // initialValue só é lido ao criar o campo: a key o recria
                // quando a seleção muda por código (preenchimento da edição)
                key: ValueKey('disciplina-${_disciplinaSelecionada?.id}'),
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
                // initialValue só é lido ao criar o campo: a key o recria
                // quando a seleção muda por código (preenchimento da edição)
                key: ValueKey('assunto-${_assuntoSelecionado?.id}'),
                initialValue: _assuntoSelecionado,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assunto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.topic),
                ),
                items: (_disciplinaSelecionada?.assuntos ?? <Assunto>[])
                    .map((assunto) => DropdownMenuItem(
                          value: assunto,
                          child: Text(
                            assunto.nome,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
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
                label: Text(_edicao ? 'Regerar Provas da Turma' : 'Gerar Provas da Turma'),
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
                'Questões de ${_assuntoSelecionado!.nome} (${_disciplinaSelecionada!.descricao})',
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
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Nenhuma questão cadastrada para este assunto.',
                style: TextStyle(color: Colors.grey),
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
                // Cabeçalho do Assunto
                Container(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withAlpha(50),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Text(
                    'Assunto: ${_assuntoSelecionado!.nome}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Lista de Questões do Assunto
                ..._assuntoSelecionado!.questoes.map((questao) {
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
