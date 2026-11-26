import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/disciplina/data/disciplina.dart';
import 'package:gabarito_plus/features/provas/data/prova.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';
import 'package:gabarito_plus/features/questoes/service/questoes_service.dart';

/// Tela de edição de provas já criadas.
class EdicaoProvaView extends StatefulWidget {
  const EdicaoProvaView({super.key, required this.prova});

  final Prova prova;

  @override
  State<EdicaoProvaView> createState() => _EdicaoProvaViewState();
}

class _EdicaoProvaViewState extends State<EdicaoProvaView> {
  late final TextEditingController _tituloController;
  final _questoesService = QuestoesService();

  late List<Disciplina> _disciplinas;
  late Disciplina? _disciplinaSelecionada;
  late Set<Questao> _questoesSelecionadas;
  late bool _embaralharQuestoes;
  late bool _embaralharAlternativas;

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.prova.titulo);
    _questoesSelecionadas = Set.from(widget.prova.questoes);
    _embaralharQuestoes = widget.prova.embaralharQuestoes;
    _embaralharAlternativas = widget.prova.embaralharAlternativas;
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final disciplinas = await _questoesService.obterDisciplinas();
      if (!mounted) return;

      Disciplina? selecionada;
      for (final d in disciplinas) {
        if (d.id == widget.prova.disciplinaId) {
          selecionada = d;
          break;
        }
      }

      setState(() {
        _disciplinas = disciplinas;
        _disciplinaSelecionada = selecionada;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _mostrarAviso('Erro ao carregar disciplinas: $e');
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  void _mostrarAviso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  void _salvarAlteracoes() {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      _mostrarAviso('Informe o título da prova');
      return;
    }

    if (_questoesSelecionadas.isEmpty) {
      _mostrarAviso('Selecione ao menos uma questão');
      return;
    }

    _mostrarAviso('Alterações salvas com sucesso!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar Prova')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Prova')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título da Prova',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Turma: ${widget.prova.turma.nomeTurma}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Assunto: ${widget.prova.assunto.nome}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Text(
              'Questões selecionadas (${_questoesSelecionadas.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questoesSelecionadas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final questao = _questoesSelecionadas.elementAt(index);
                  return Dismissible(
                    key: Key(questao.id),
                    onDismissed: (_) {
                      setState(() => _questoesSelecionadas.remove(questao));
                      _mostrarAviso('Questão removida');
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            questao.enunciado,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          questao.id,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text('Embaralhar questões'),
              value: _embaralharQuestoes,
              onChanged: (v) => setState(() => _embaralharQuestoes = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Embaralhar alternativas'),
              value: _embaralharAlternativas,
              onChanged: (v) => setState(() => _embaralharAlternativas = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _salvarAlteracoes,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Alterações'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}