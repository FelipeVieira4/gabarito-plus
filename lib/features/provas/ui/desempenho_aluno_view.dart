import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/correcao_prova/ui/detalhes_prova_corrigida_view.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/filtros_provas.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/graficos_notas.dart';

/// Desempenho de um aluno dentro de uma turma: nota em cada prova
/// (comparada à média da turma) e média por disciplina.
class DesempenhoAlunoView extends StatefulWidget {
  const DesempenhoAlunoView({
    super.key,
    required this.analise,
    required this.chaveAluno,
    required this.nomeAluno,
    required this.turmaId,
    this.filtroInicial = const FiltroDesempenho(),
  });

  final AnaliseDesempenho analise;

  /// [NotaLancada.chaveAluno]: o id do aluno (ou o nome, em correções antigas).
  final String chaveAluno;
  final String nomeAluno;
  final String turmaId;
  final FiltroDesempenho filtroInicial;

  @override
  State<DesempenhoAlunoView> createState() => _DesempenhoAlunoViewState();
}

class _DesempenhoAlunoViewState extends State<DesempenhoAlunoView> {
  late FiltroDesempenho _filtro = widget.filtroInicial;

  void _abrirCorrecao(NotaLancada nota) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalhesProvaCorrigidaView(
          correcao: nota.correcao,
          notaCorte: notaCorteDesempenho,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analise = widget.analise;
    final validado = FiltrosProvas.validar(analise, _filtro);
    final filtro = FiltroDesempenho(
      disciplinaId: validado.disciplinaId,
      turmaId: widget.turmaId,
      semestre: validado.semestre,
    );

    final notas = analise.notasDoAluno(widget.chaveAluno, filtro);
    final mediaAluno = mediaDe(notas.map((n) => n.nota));
    final mediaTurma = analise.mediaGeral(filtro);

    final ranking = analise.mediasPorAluno(filtro);
    final posicao = ranking.indexWhere((a) => a.id == widget.chaveAluno);

    final notasPorProva = analise.notasDoAlunoPorProva(widget.chaveAluno, filtro);

    final porDisciplina = analise
        .mediasDoAlunoPorDisciplina(widget.chaveAluno, filtro)
        .map(
          (item) => ItemMedia(
            id: item.id,
            rotulo: item.rotulo,
            subtitulo: item.subtitulo,
            media: item.media,
            quantidade: item.quantidade,
            referencia: analise.mediaGeral(
              FiltroDesempenho(
                disciplinaId: item.id,
                turmaId: widget.turmaId,
                semestre: filtro.semestre,
              ),
            ),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.nomeAluno)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analise.nomeTurma(widget.turmaId),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                FiltrosProvas(
                  analise: analise,
                  filtro: filtro,
                  mostrarTurma: false,
                  onChanged: (f) => setState(() => _filtro = f),
                ),
                const SizedBox(height: 16),
                IndicadoresResumo(
                  itens: [
                    IndicadorResumo(
                      rotulo: 'Média do aluno',
                      valor: formatarNota(mediaAluno),
                      icone: Icons.person_outline,
                      cor: mediaAluno == null ? Colors.blueGrey : corDaNota(mediaAluno),
                    ),
                    IndicadorResumo(
                      rotulo: 'Média da turma',
                      valor: formatarNota(mediaTurma),
                      icone: Icons.groups_outlined,
                      cor: Colors.blueGrey.shade700,
                    ),
                    IndicadorResumo(
                      rotulo: 'Provas feitas',
                      valor: '${notas.length}',
                      icone: Icons.description_outlined,
                      cor: Colors.blue.shade700,
                    ),
                    IndicadorResumo(
                      rotulo: 'Posição na turma',
                      valor: posicao < 0 ? '—' : '${posicao + 1}º de ${ranking.length}',
                      icone: Icons.leaderboard_outlined,
                      cor: Colors.indigo.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SecaoGrafico(
                  titulo: 'Notas por prova',
                  subtitulo: 'Em ordem de aplicação. A linha preta é a média da '
                      'turma naquela prova. Toque numa coluna para ver a correção.',
                  icone: Icons.show_chart,
                  child: GraficoColunasNotas(
                    itens: notasPorProva,
                    rotuloReferencia: 'Média da turma',
                    onTapItem: (item) => _abrirCorrecao(
                      notas.firstWhere((n) => n.correcao.codigoVersao == item.id),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SecaoGrafico(
                  titulo: 'Média por disciplina',
                  subtitulo: 'Considera todas as disciplinas do período. '
                      'A linha preta é a média da turma na disciplina.',
                  icone: Icons.bookmark_outline,
                  child: GraficoBarrasNotas(
                    itens: porDisciplina,
                    rotuloReferencia: 'Média da turma',
                  ),
                ),
                const SizedBox(height: 16),
                SecaoGrafico(
                  titulo: 'Provas do aluno',
                  icone: Icons.list_alt,
                  child: notas.isEmpty
                      ? const GraficoVazio()
                      : Column(
                          children: [
                            for (final n in notas.reversed)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: corDaNota(n.nota).withValues(alpha: 0.15),
                                  child: Text(
                                    formatarNota(n.nota),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: corDaNota(n.nota),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  n.tituloProva,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  [
                                    if (n.nomeDisciplina.isNotEmpty) n.nomeDisciplina,
                                    '${n.correcao.acertos}/${n.correcao.totalQuestoes} acertos',
                                    formatarData(n.correcao.dataHora),
                                  ].join(' • '),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _abrirCorrecao(n),
                              ),
                          ],
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
