import 'package:gabarito_plus/core/professor_db.dart';
import 'package:gabarito_plus/features/correcao_prova/services/correcao_repository.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';

/// Carrega provas, correções, turmas e disciplinas para as telas de provas.
/// As telas usam [instancia]; os testes podem trocar por uma versão em
/// memória, já que não inicializam o Firebase.
abstract class DesempenhoRepository {
  static DesempenhoRepository instancia = DesempenhoRepositoryFirestore();

  Future<AnaliseDesempenho> carregar();
}

class DesempenhoRepositoryFirestore implements DesempenhoRepository {
  @override
  Future<AnaliseDesempenho> carregar() async {
    final resultados = await Future.wait([
      ProfessorDb.colecao('provas').get(),
      ProfessorDb.colecao('assuntos').get(),
      ProfessorDb.colecao('disciplinas').get(),
      ProfessorDb.colecao('turmas').get(),
    ]);
    final provasSnap = resultados[0];
    final assuntosSnap = resultados[1];
    final disciplinasSnap = resultados[2];
    final turmasSnap = resultados[3];

    final correcoes = await CorrecaoRepository.instancia.obterTodas();

    final nomeDisciplina = {
      for (final d in disciplinasSnap.docs)
        d.id: (d.data()['descricao'] ?? '') as String,
    };
    final disciplinaDoAssunto = {
      for (final a in assuntosSnap.docs)
        a.id: (a.data()['disciplinaId'] ?? '') as String,
    };

    final provas = provasSnap.docs.map((doc) {
      final dados = doc.data();
      final disciplinaId = disciplinaDoAssunto[dados['assuntoId']] ?? '';
      return ProvaResumo.fromMap(
        doc.id,
        dados,
        disciplinaId: disciplinaId,
        nomeDisciplina: nomeDisciplina[disciplinaId] ?? '',
      );
    }).toList();

    final disciplinas = nomeDisciplina.entries
        .map((e) => OpcaoFiltro(id: e.key, nome: e.value))
        .toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    // Turmas cadastradas + turmas que só aparecem em provas/correções
    // (ex.: turma excluída depois de corrigida).
    final turmasPorId = <String, String>{
      for (final t in turmasSnap.docs) t.id: (t.data()['nomeTurma'] ?? '') as String,
    };
    for (final p in provas) {
      if (p.turmaId.isNotEmpty) turmasPorId.putIfAbsent(p.turmaId, () => p.nomeTurma);
    }
    for (final c in correcoes) {
      if (c.turmaId.isNotEmpty) turmasPorId.putIfAbsent(c.turmaId, () => c.nomeTurma);
    }
    final turmas = turmasPorId.entries
        .map((e) => OpcaoFiltro(id: e.key, nome: e.value))
        .toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    return AnaliseDesempenho(
      provas: provas,
      correcoes: correcoes,
      disciplinas: disciplinas,
      turmas: turmas,
    );
  }
}
