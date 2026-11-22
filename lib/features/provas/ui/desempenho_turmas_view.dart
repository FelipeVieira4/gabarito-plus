import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';
import 'package:gabarito_plus/features/provas/ui/consulta_provas_view.dart';
import 'package:gabarito_plus/features/provas/ui/desempenho_turma_view.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/filtros_provas.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/graficos_notas.dart';

/// Gráficos gerais: média de cada turma no semestre e média de cada prova.
/// Tocar numa turma abre o desempenho dos alunos dela.
class DesempenhoTurmasView extends StatefulWidget {
  const DesempenhoTurmasView({
    super.key,
    required this.analise,
    this.filtroInicial = const FiltroDesempenho(),
  });

  final AnaliseDesempenho analise;
  final FiltroDesempenho filtroInicial;

  @override
  State<DesempenhoTurmasView> createState() => _DesempenhoTurmasViewState();
}

class _DesempenhoTurmasViewState extends State<DesempenhoTurmasView> {
  late FiltroDesempenho _filtro = widget.filtroInicial;

  void _abrirTurma(String turmaId, FiltroDesempenho filtro) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DesempenhoTurmaView(
          analise: widget.analise,
          turmaId: turmaId,
          filtroInicial: filtro,
        ),
      ),
    );
  }

  void _abrirProva(String provaId) {
    final analise = widget.analise;
    final notas = analise.notasDaProva(provaId);
    ProvaResumo? prova;
    for (final p in analise.provas) {
      if (p.id == provaId) prova = p;
    }
    // Correção sem prova cadastrada (prova apagada): monta um resumo mínimo.
    prova ??= ProvaResumo(
      id: provaId,
      titulo: notas.isEmpty ? '' : notas.first.tituloProva,
      turmaId: notas.isEmpty ? '' : notas.first.turmaId,
      nomeTurma: notas.isEmpty ? '' : notas.first.nomeTurma,
      assuntoId: '',
      nomeAssunto: '',
      disciplinaId: '',
      nomeDisciplina: '',
      quantidadeQuestoes: notas.isEmpty ? 0 : notas.first.correcao.totalQuestoes,
      criadaEm: null,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalheProvaView(prova: prova!, notas: notas)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analise = widget.analise;
    final filtro = FiltrosProvas.validar(analise, _filtro);
    final media = analise.mediaGeral(filtro);
    final turmas = analise.mediasPorTurma(filtro);
    final provas = analise.mediasPorProva(filtro);

    final melhor = turmas.isEmpty
        ? null
        : turmas.reduce((a, b) => b.media > a.media ? b : a);

    final periodo = filtro.semestre == null
        ? 'em todos os semestres'
        : 'no ${rotuloSemestre(filtro.semestre!)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Desempenho das Turmas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FiltrosProvas(
                  analise: analise,
                  filtro: filtro,
                  onChanged: (f) => setState(() => _filtro = f),
                ),
                const SizedBox(height: 16),
                IndicadoresResumo(
                  itens: [
                    IndicadorResumo(
                      rotulo: 'Média geral',
                      valor: formatarNota(media),
                      icone: Icons.analytics_outlined,
                      cor: media == null ? Colors.blueGrey : corDaNota(media),
                    ),
                    IndicadorResumo(
                      rotulo: 'Turmas avaliadas',
                      valor: '${turmas.length}',
                      icone: Icons.groups_outlined,
                      cor: Colors.indigo.shade700,
                    ),
                    IndicadorResumo(
                      rotulo: 'Provas corrigidas',
                      valor: '${provas.length}',
                      icone: Icons.description_outlined,
                      cor: Colors.blue.shade700,
                    ),
                    IndicadorResumo(
                      rotulo: 'Melhor turma',
                      valor: melhor == null
                          ? '—'
                          : '${melhor.rotulo} (${formatarNota(melhor.media)})',
                      icone: Icons.emoji_events_outlined,
                      cor: Colors.amber.shade800,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SecaoGrafico(
                  titulo: 'Média geral das turmas',
                  subtitulo: 'Média de todas as notas de cada turma $periodo. '
                      'Toque numa turma para ver os alunos.',
                  icone: Icons.groups_outlined,
                  child: GraficoBarrasNotas(
                    itens: turmas,
                    mediaReferencia: media,
                    rotuloReferencia: 'Média geral (${formatarNota(media)})',
                    onTapItem: (item) => _abrirTurma(item.id, filtro),
                  ),
                ),
                const SizedBox(height: 16),
                SecaoGrafico(
                  titulo: 'Média das provas',
                  subtitulo: 'Em ordem de aplicação. Toque numa prova para ver as notas.',
                  icone: Icons.description_outlined,
                  child: GraficoBarrasNotas(
                    itens: provas,
                    mediaReferencia: media,
                    rotuloReferencia: 'Média geral (${formatarNota(media)})',
                    onTapItem: (item) => _abrirProva(item.id),
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
