import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/geracao_prova/data/embaralhador.dart';
import 'package:gabarito_plus/features/provas/data/prova.dart';
import 'package:gabarito_plus/features/provas/data/versao_prova.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/gabarito_qrcode.dart';
import 'package:gabarito_plus/features/provas/pdf/exportar_pdf.dart';
import 'package:gabarito_plus/features/provas/pdf/prova_pdf.dart';
import 'package:gabarito_plus/features/provas/service/prova_repository.dart';

class VisualizacaoEmbaralhamento extends StatefulWidget {
  const VisualizacaoEmbaralhamento({super.key, required this.prova});

  final Prova prova;

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

  /// Retorna true se as provas ficaram salvas.
  Future<bool> _salvarProvas() async {
    setState(() => _salvando = true);
    try {
      await ProvaRepository.instancia.salvar(widget.prova, _versoes);
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
      return false;
    }

    if (!mounted) return true;
    setState(() {
      _salvando = false;
      _salva = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_versoes.length} provas salvas')),
    );
    return true;
  }

  /// Uma prova impressa sem estar salva não é encontrada na correção
  /// (o QR Code aponta para o gabarito no banco). Pede para salvar antes.
  Future<bool> _garantirSalva() async {
    if (_salva) return true;
    final salvar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salvar antes de imprimir'),
        content: const Text(
          'As provas ainda não foram salvas. Sem salvar, a correção não '
          'encontra o gabarito destas provas.

Deseja salvar agora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salvar e continuar'),
          ),
        ],
      ),
    );
    if (salvar != true || !mounted) return false;
    return _salvarProvas();
  }

  Future<void> _exportarProvas() async {
    if (!await _garantirSalva() || !mounted) return;
    final prova = widget.prova;
    final versoes = List<VersaoProva>.of(_versoes);
    await exportarPdf(
      context,
      nomeArquivo: nomeArquivoPdf('${prova.titulo}_${prova.turma.nomeTurma}'),
      gerar: () => ProvaPdf.todasAsProvas(prova, versoes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prova = widget.prova;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Embaralhamento das Provas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar provas (PDF)',
            onPressed: _salvando ? null : _exportarProvas,
          ),
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
                    Text(
                      prova.nomeDisciplina.isEmpty
                          ? 'Assunto: ${prova.assunto.nome}'
                          : 'Disciplina: ${prova.nomeDisciplina} · Assunto: ${prova.assunto.nome}',
                    ),
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
                return _VersaoProvaCard(
                  versao: versao,
                  onVerGabarito: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GabaritoQrCode(
                        prova: prova,
                        versao: versao,
                        antesDeExportar: _garantirSalva,
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _salvando ? null : _exportarProvas,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Exportar provas'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                            : 'Salvar provas',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, bool ativo) {
    return Chip(
      avatar: Icon(icon, size: 16, color: ativo ? Colors.green : Colors.grey),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _VersaoProvaCard extends StatelessWidget {
  const _VersaoProvaCard({required this.versao, required this.onVerGabarito});

  final VersaoProva versao;
  final VoidCallback onVerGabarito;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(child: Text(versao.aluno.nome[0])),
        title: Text(versao.aluno.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Código da versão: ${versao.codigo}'),
        children: [
          ...versao.questoes.asMap().entries.map((entry) {
            final numero = entry.key + 1;
            final questaoEmbaralhada = entry.value;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questão $numero',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                  Text(questaoEmbaralhada.questao.enunciado),
                  const SizedBox(height: 4),
                  ...questaoEmbaralhada.alternativas.asMap().entries.map((alt) {
                    final letra = String.fromCharCode(65 + alt.key);
                    final correta = alt.key == questaoEmbaralhada.respostaCorreta;
                    return Text(
                      '$letra) ${alt.value}',
                      style: TextStyle(
                        color: correta ? Colors.green[700] : null,
                        fontWeight: correta ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onVerGabarito,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Ver Gabarito'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
