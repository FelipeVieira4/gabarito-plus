import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';

/// Dropdowns de disciplina, turma e semestre usados em todas as telas de
/// provas. Valores que não existem mais nas opções viram "Todos".
class FiltrosProvas extends StatelessWidget {
  const FiltrosProvas({
    super.key,
    required this.analise,
    required this.filtro,
    required this.onChanged,
    this.mostrarTurma = true,
    this.mostrarSemestre = true,
  });

  final AnaliseDesempenho analise;
  final FiltroDesempenho filtro;
  final ValueChanged<FiltroDesempenho> onChanged;
  final bool mostrarTurma;
  final bool mostrarSemestre;

  /// Ajusta o filtro para só conter valores que existem nas opções.
  static FiltroDesempenho validar(AnaliseDesempenho analise, FiltroDesempenho filtro) {
    final disciplinaOk = analise.disciplinas.any((d) => d.id == filtro.disciplinaId);
    final turmaOk = analise.turmas.any((t) => t.id == filtro.turmaId);
    final semestreOk = analise.semestres.contains(filtro.semestre);
    return FiltroDesempenho(
      disciplinaId: disciplinaOk ? filtro.disciplinaId : null,
      turmaId: turmaOk ? filtro.turmaId : null,
      semestre: semestreOk ? filtro.semestre : null,
    );
  }

  bool get possuiFiltroAtivo =>
      filtro.disciplinaId != null ||
      (mostrarTurma && filtro.turmaId != null) ||
      (mostrarSemestre && filtro.semestre != null);

  @override
  Widget build(BuildContext context) {
    final f = validar(analise, filtro);

    final disciplina = _Dropdown(
      chave: 'disciplina-${f.disciplinaId}',
      rotulo: 'Disciplina',
      rotuloTodos: 'Todas as disciplinas',
      valor: f.disciplinaId,
      opcoes: analise.disciplinas,
      onChanged: (v) => onChanged(
        FiltroDesempenho(disciplinaId: v, turmaId: f.turmaId, semestre: f.semestre),
      ),
    );

    final turma = _Dropdown(
      chave: 'turma-${f.turmaId}',
      rotulo: 'Turma',
      rotuloTodos: 'Todas as turmas',
      valor: f.turmaId,
      opcoes: analise.turmas,
      onChanged: (v) => onChanged(
        FiltroDesempenho(disciplinaId: f.disciplinaId, turmaId: v, semestre: f.semestre),
      ),
    );

    final semestre = _Dropdown(
      chave: 'semestre-${f.semestre}',
      rotulo: 'Semestre',
      rotuloTodos: 'Todos os semestres',
      valor: f.semestre,
      opcoes: analise.semestres
          .map((s) => OpcaoFiltro(id: s, nome: rotuloSemestre(s)))
          .toList(),
      onChanged: (v) => onChanged(
        FiltroDesempenho(disciplinaId: f.disciplinaId, turmaId: f.turmaId, semestre: v),
      ),
    );

    final campos = <Widget>[
      disciplina,
      if (mostrarTurma) turma,
      if (mostrarSemestre) semestre,
    ];

    final limpar = possuiFiltroAtivo
        ? IconButton(
            tooltip: 'Limpar filtros',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: () => onChanged(
              FiltroDesempenho(
                turmaId: mostrarTurma ? null : f.turmaId,
                semestre: mostrarSemestre ? null : f.semestre,
              ),
            ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 650) {
          return Row(
            children: [
              for (var i = 0; i < campos.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: campos[i]),
              ],
              if (limpar != null) ...[const SizedBox(width: 4), limpar],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < campos.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: campos[i]),
                  if (i == campos.length - 1 && limpar != null) ...[
                    const SizedBox(width: 4),
                    limpar,
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.chave,
    required this.rotulo,
    required this.rotuloTodos,
    required this.valor,
    required this.opcoes,
    required this.onChanged,
  });

  final String chave;
  final String rotulo;
  final String rotuloTodos;
  final String? valor;
  final List<OpcaoFiltro> opcoes;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      key: ValueKey(chave),
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: rotulo,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(rotuloTodos)),
        ...opcoes.map(
          (o) => DropdownMenuItem<String?>(
            value: o.id,
            child: Text(o.nome, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
