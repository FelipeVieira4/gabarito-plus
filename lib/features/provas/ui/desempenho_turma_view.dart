import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';
import 'package:gabarito_plus/features/provas/ui/desempenho_aluno_view.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/filtros_provas.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/graficos_notas.dart';

/// Desempenho de uma turma: média de cada aluno e média de cada prova.
/// A turma pode ser trocada no filtro; tocar num aluno abre as notas dele.
class DesempenhoTurmaView extends StatefulWidget {
  const DesempenhoTurmaView({
    super.key,
    required this.analise,
    required this.turmaId,
    this.filtroInicial = const FiltroDesempenho(),
  });

  final AnaliseDesempenho analise;
  final String turmaId;
  final FiltroDesempenho filtroInicial;

  @override
  State<DesempenhoTurmaView> createState() => _DesempenhoTurmaViewState();
}

class _DesempenhoTurmaViewState extends State<DesempenhoTurmaView> {
  late FiltroDesempenho _filtro = FiltroDesempenho(
    disciplinaId: widget.filtroInicial.disciplinaId,
    turmaId: widget.turmaId,
    semestre: widget.filtroInicial.semestre,
  );

  @override
  Widget build(BuildContext context) {
    final analise = widget.analise;
    final validado = FiltrosProvas.validar(analise, _filtro);
    // A tela é sempre de uma turma: sem turma escolhida, mantém a original.
    final turmaId = validado.turmaId ?? widget.turmaId;
    final filtro = FiltroDesempenho(
      disciplinaId: validado.disciplinaId,
      turmaId: turmaId,
      semestre: validado.semestre,
    );
    final filtroTodasTurmas = FiltroDesempenho(
      disciplinaId: filtro.disciplinaId,
      semestre: filtro.semestre,
    );

    final mediaTurma = analise.mediaGeral(filtro);
    final mediaGeral = analise.mediaGeral(filtroTodasTurmas);
    final alunos = analise.mediasPorAluno(filtro);
    final provas = analise.mediasPorProva(filtro);
    final abaixo = alunos.where((a) => a.media < notaCorteDesempenho).length;

    return Scaffold(
      appBar: AppBar(title: Text(analise.nomeTurma(turmaId))),
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
                      rotulo: 'Média da turma',
                      valor: formatarNota(mediaTurma),
                      icone: Icons.analytics_outlined,
                      cor: mediaTurma == null ? Colors.blueGrey : corDaNota(mediaTurma),
                    ),
                    IndicadorResumo(
                      rotulo: 'Média de todas as turmas',
                      valor: formatarNota(mediaGeral),
                      icone: Icons.public,
                      cor: Colors.blueGrey.shade700,
                    ),
                    IndicadorResumo(
                      rotulo: 'Alunos avaliados',
                      valor: '${alunos.length}',
                      icone: Icons.people_outline,
                      cor: Colors.indigo.shade700,
                    ),
                    IndicadorResumo(
                      rotulo: 'Abaixo da média',
                      valor: '$abaixo',
                      icone: Icons.warning_amber_rounded,
                      cor: abaixo == 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SecaoGrafico(
                  titulo: 'Média dos alunos',
                  subtitulo: 'Da maior para a menor. Toque num aluno para ver as notas dele.',
                  icone: Icons.people_outline,
                  child: GraficoBarrasNotas(
                    itens: alunos,
                    mediaReferencia: mediaTurma,
                    rotuloReferencia: 'Média da turma (${formatarNota(mediaTurma)})',
                    onTapItem: (item) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DesempenhoAlunoView(
                          analise: analise,
                          chaveAluno: item.id,
                          nomeAluno: item.rotulo,
                          turmaId: turmaId,
                          filtroInicial: filtro,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SecaoGrafico(
                  titulo: 'Média das provas da turma',
                  subtitulo: 'Em ordem de aplicação.',
                  icone: Icons.description_outlined,
                  child: GraficoColunasNotas(
                    itens: provas,
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
