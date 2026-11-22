import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/geracao_prova/data/embaralhador.dart';
import 'package:gabarito_plus/features/geracao_prova/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/data/versao_prova.dart';
import 'package:gabarito_plus/features/geracao_prova/service/prova_repository.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/gabarito_qrcode.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/widgets/resumo_prova_card.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/widgets/versao_prova_card.dart';

class VisualizacaoEmbaralhamento extends StatefulWidget {
  const VisualizacaoEmbaralhamento({
    super.key,
    required this.prova,
    this.edicao = false,
  });

  final Prova prova;

  /// A prova já existe: salvar substitui as versões anteriores (mesmos
  /// códigos) e, ao terminar, a tela fecha devolvendo `true`.
  final bool edicao;

  @override
  State<VisualizacaoEmbaralhamento> createState() => _VisualizacaoEmbaralhamentoState();
}

class _VisualizacaoEmbaralhamentoState extends State<VisualizacaoEmbaralhamento> {
  late List<VersaoProva> _versoes;
  bool _salvando = false;
  bool _salva = false;

  @override
  void initState() {
    super.initState();
    _versoes = Embaralhador.gerarVersoes(widget.prova);
  }

  void _regerarVersoes() {
    setState(() => _versoes = Embaralhador.gerarVersoes(widget.prova));
  }

  Future<void> _salvarProvas() async {
    setState(() => _salvando = true);
    try {
      final repositorio = ProvaRepository.instancia;
      if (widget.edicao) {
        await repositorio.substituir(widget.prova, _versoes);
      } else {
        await repositorio.salvar(widget.prova, _versoes);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError
              ? e.message
              : 'Não foi possível salvar as provas. Verifique a conexão e '
                  'tente de novo.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _salvando = false;
      _salva = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.edicao
            ? 'Prova atualizada: ${_versoes.length} versões regeradas'
            : '${_versoes.length} provas salvas'),
      ),
    );
    if (widget.edicao) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final prova = widget.prova;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Embaralhamento das Provas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            // depois de salvas, as versões impressas precisam bater com o banco
            tooltip: _salva
                ? 'Provas já salvas: não é possível embaralhar de novo'
                : 'Gerar nova distribuição',
            onPressed: _salva || _salvando ? null : _regerarVersoes,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prova.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('Assunto: ${prova.assunto.nome}'),
                    const SizedBox(height: 2),
                    Text(
                      prova.sorteiaQuestoes
                          ? '${prova.turma.nomeTurma} · ${prova.quantidadeQuestoesPorVersao} de ${prova.questoes.length} questões por prova · ${_versoes.length} variações geradas'
                          : '${prova.turma.nomeTurma} · ${prova.questoes.length} questões · ${_versoes.length} variações geradas',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (prova.sorteiaQuestoes)
                          _buildChip(Icons.check_circle, 'Questões sorteadas por aluno', true),
                        _buildChip(
                          prova.embaralharQuestoes ? Icons.check_circle : Icons.cancel,
                          'Ordem das questões',
                          prova.embaralharQuestoes,
                        ),
                        _buildChip(
                          prova.embaralharAlternativas ? Icons.check_circle : Icons.cancel,
                          'Ordem das alternativas',
                          prova.embaralharAlternativas,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_salva)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Provas ainda não salvas: a correção só encontra provas salvas.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                prova.sorteiaQuestoes
                    ? 'Cada aluno recebe questões sorteadas do banco selecionado'
                    : 'Cada aluno recebe uma prova com a mesma dificuldade, mas em uma ordem diferente',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: _versoes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final versao = _versoes[index];
                return VersaoProvaCard(
                  versao: versao,
                  onVerGabarito: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GabaritoQrCode(
                        tituloProva: prova.titulo,
                        nomeTurma: prova.turma.nomeTurma,
                        versao: versao,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _salva || _salvando ? null : _salvarProvas,
            icon: _salvando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_salva ? Icons.check : Icons.save),
            label: Text(
              _salva
                  ? 'Provas salvas'
                  : _salvando
                      ? 'Salvando...'
                      : widget.edicao
                          ? 'Salvar alterações'
                          : 'Salvar provas',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }
}
