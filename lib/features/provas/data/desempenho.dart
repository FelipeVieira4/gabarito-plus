import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gabarito_plus/features/geracao_prova/data/correcao.dart';

/// Nota mínima de aprovação usada nos gráficos (mesmo padrão das correções).
const notaCorteDesempenho = 6.0;

/// Semestre letivo no formato `2026/1` (jan–jun) ou `2026/2` (jul–dez).
String semestreDe(DateTime data) => '${data.year}/${data.month <= 6 ? 1 : 2}';

/// `2026/2` → `2º sem. 2026`.
String rotuloSemestre(String semestre) {
  final partes = semestre.split('/');
  if (partes.length != 2) return semestre;
  return '${partes[1]}º sem. ${partes[0]}';
}

double _arredondar(double valor) => (valor * 10).round() / 10;

/// Média das notas com uma casa decimal, ou null se não houver notas.
double? mediaDe(Iterable<double> notas) {
  if (notas.isEmpty) return null;
  final soma = notas.fold<double>(0, (total, nota) => total + nota);
  return _arredondar(soma / notas.length);
}

/// Item de um dropdown de filtro (disciplina ou turma).
class OpcaoFiltro {
  final String id;
  final String nome;

  const OpcaoFiltro({required this.id, required this.nome});
}

/// Filtros comuns às telas de provas. Null = "todos".
class FiltroDesempenho {
  final String? disciplinaId;
  final String? turmaId;
  final String? semestre;

  const FiltroDesempenho({this.disciplinaId, this.turmaId, this.semestre});

  FiltroDesempenho semDisciplina() =>
      FiltroDesempenho(turmaId: turmaId, semestre: semestre);
}

/// Prova lida do Firestore já com a disciplina resolvida
/// (prova → assunto → disciplina).
class ProvaResumo {
  final String id;
  final String titulo;
  final String turmaId;
  final String nomeTurma;
  final String assuntoId;
  final String nomeAssunto;
  final String disciplinaId;
  final String nomeDisciplina;
  final int quantidadeQuestoes;
  final DateTime? criadaEm;

  /// Quantas versões (alunos) a prova tem. Null se não foi possível saber.
  final int? quantidadeVersoes;

  ProvaResumo({
    required this.id,
    required this.titulo,
    required this.turmaId,
    required this.nomeTurma,
    required this.assuntoId,
    required this.nomeAssunto,
    required this.disciplinaId,
    required this.nomeDisciplina,
    required this.quantidadeQuestoes,
    required this.criadaEm,
    this.quantidadeVersoes,
  });

  /// [dados] é o formato de `Prova.toMap()`.
  factory ProvaResumo.fromMap(
    String id,
    Map<String, dynamic> dados, {
    required String disciplinaId,
    required String nomeDisciplina,
    int? quantidadeVersoes,
  }) {
    final criadaEm = dados['criadaEm'];
    return ProvaResumo(
      id: id,
      titulo: dados['titulo'] ?? '',
      turmaId: dados['turmaId'] ?? '',
      nomeTurma: dados['nomeTurma'] ?? '',
      assuntoId: dados['assuntoId'] ?? '',
      nomeAssunto: dados['nomeAssunto'] ?? '',
      disciplinaId: disciplinaId,
      nomeDisciplina: nomeDisciplina,
      quantidadeQuestoes: (dados['questoesPorProva'] as num?)?.toInt() ??
          (dados['questoesIds'] as List?)?.length ??
          0,
      criadaEm: criadaEm is Timestamp ? criadaEm.toDate() : null,
      quantidadeVersoes:
          (dados['quantidadeVersoes'] as num?)?.toInt() ?? quantidadeVersoes,
    );
  }

  String get semestre => criadaEm == null ? '' : semestreDe(criadaEm!);
}

/// Uma correção ligada à prova de origem (para saber disciplina e semestre).
class NotaLancada {
  final Correcao correcao;
  final ProvaResumo? prova;

  NotaLancada({required this.correcao, required this.prova});

  double get nota => correcao.nota;

  String get provaId =>
      correcao.provaId.isNotEmpty ? correcao.provaId : (prova?.id ?? '');

  String get tituloProva =>
      correcao.tituloProva.isNotEmpty ? correcao.tituloProva : (prova?.titulo ?? '');

  String get turmaId =>
      correcao.turmaId.isNotEmpty ? correcao.turmaId : (prova?.turmaId ?? '');

  String get nomeTurma =>
      correcao.nomeTurma.isNotEmpty ? correcao.nomeTurma : (prova?.nomeTurma ?? '');

  String get disciplinaId => prova?.disciplinaId ?? '';

  String get nomeDisciplina => prova?.nomeDisciplina ?? '';

  /// Data usada para o semestre: criação da prova; sem ela, a da correção.
  DateTime get data => prova?.criadaEm ?? correcao.dataHora;

  String get semestre => semestreDe(data);

  /// Correções antigas podem não ter alunoId; o nome serve de reserva.
  String get chaveAluno =>
      correcao.alunoId.isNotEmpty ? correcao.alunoId : 'nome:${correcao.nomeAluno}';
}

/// Uma barra/coluna de gráfico: média de um grupo de notas.
class ItemMedia {
  final String id;
  final String rotulo;
  final String? subtitulo;
  final double media;
  final int quantidade;

  /// Valor de comparação desenhado como marcador sobre a barra
  /// (ex.: média da turma na prova, no gráfico do aluno).
  final double? referencia;

  ItemMedia({
    required this.id,
    required this.rotulo,
    this.subtitulo,
    required this.media,
    required this.quantidade,
    this.referencia,
  });
}

/// Todos os dados das telas de provas, carregados uma vez e filtrados em
/// memória. Não depende do Firebase: dá para testar montando à mão.
class AnaliseDesempenho {
  AnaliseDesempenho({
    required this.provas,
    required List<Correcao> correcoes,
    required this.disciplinas,
    required this.turmas,
  }) : notas = _ligar(provas, correcoes);

  factory AnaliseDesempenho.vazia() => AnaliseDesempenho(
        provas: const [],
        correcoes: const [],
        disciplinas: const [],
        turmas: const [],
      );

  final List<ProvaResumo> provas;
  final List<NotaLancada> notas;
  final List<OpcaoFiltro> disciplinas;
  final List<OpcaoFiltro> turmas;

  static List<NotaLancada> _ligar(
    List<ProvaResumo> provas,
    List<Correcao> correcoes,
  ) {
    final porId = {for (final p in provas) p.id: p};
    return correcoes.map((c) {
      // provaId vazio (correção antiga): tenta pelo prefixo do código da versão
      final provaId = c.provaId.isNotEmpty
          ? c.provaId
          : c.codigoVersao.split('-').first;
      return NotaLancada(correcao: c, prova: porId[provaId]);
    }).toList();
  }

  /// Semestres com provas ou correções, do mais recente para o mais antigo.
  List<String> get semestres {
    final todos = <String>{
      ...provas.map((p) => p.semestre).where((s) => s.isNotEmpty),
      ...notas.map((n) => n.semestre),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return todos;
  }

  bool _provaBate(ProvaResumo prova, FiltroDesempenho filtro) {
    if (filtro.disciplinaId != null && prova.disciplinaId != filtro.disciplinaId) {
      return false;
    }
    if (filtro.turmaId != null && prova.turmaId != filtro.turmaId) return false;
    if (filtro.semestre != null && prova.semestre != filtro.semestre) return false;
    return true;
  }

  bool _notaBate(NotaLancada nota, FiltroDesempenho filtro) {
    if (filtro.disciplinaId != null && nota.disciplinaId != filtro.disciplinaId) {
      return false;
    }
    if (filtro.turmaId != null && nota.turmaId != filtro.turmaId) return false;
    if (filtro.semestre != null && nota.semestre != filtro.semestre) return false;
    return true;
  }

  /// Provas do filtro, mais recentes primeiro.
  List<ProvaResumo> provasFiltradas(FiltroDesempenho filtro) {
    final lista = provas.where((p) => _provaBate(p, filtro)).toList();
    lista.sort((a, b) {
      final da = a.criadaEm, db = b.criadaEm;
      if (da == null || db == null) return a.titulo.compareTo(b.titulo);
      return db.compareTo(da);
    });
    return lista;
  }

  List<NotaLancada> notasFiltradas(FiltroDesempenho filtro) =>
      notas.where((n) => _notaBate(n, filtro)).toList();

  List<NotaLancada> notasDaProva(String provaId) =>
      notas.where((n) => n.provaId == provaId).toList();

  List<NotaLancada> notasDoAluno(String chaveAluno, FiltroDesempenho filtro) {
    final lista = notasFiltradas(filtro)
        .where((n) => n.chaveAluno == chaveAluno)
        .toList();
    lista.sort((a, b) => a.data.compareTo(b.data));
    return lista;
  }

  double? mediaGeral(FiltroDesempenho filtro) =>
      mediaDe(notasFiltradas(filtro).map((n) => n.nota));

  String nomeTurma(String turmaId) {
    for (final t in turmas) {
      if (t.id == turmaId) return t.nome;
    }
    for (final n in notas) {
      if (n.turmaId == turmaId && n.nomeTurma.isNotEmpty) return n.nomeTurma;
    }
    return 'Turma';
  }

  /// Agrupa as notas e calcula a média de cada grupo.
  List<ItemMedia> _agrupar(
    Iterable<NotaLancada> notas, {
    required String Function(NotaLancada) chave,
    required String Function(NotaLancada) rotulo,
    required String Function(List<NotaLancada>) subtitulo,
  }) {
    final grupos = <String, List<NotaLancada>>{};
    for (final n in notas) {
      grupos.putIfAbsent(chave(n), () => []).add(n);
    }
    return grupos.entries.map((e) {
      return ItemMedia(
        id: e.key,
        rotulo: rotulo(e.value.first),
        subtitulo: subtitulo(e.value),
        media: mediaDe(e.value.map((n) => n.nota))!,
        quantidade: e.value.length,
      );
    }).toList();
  }

  /// Média geral de cada turma (todas as notas do filtro), por nome.
  List<ItemMedia> mediasPorTurma(FiltroDesempenho filtro) {
    final itens = _agrupar(
      notasFiltradas(filtro),
      chave: (n) => n.turmaId.isNotEmpty ? n.turmaId : 'nome:${n.nomeTurma}',
      rotulo: (n) => n.nomeTurma.isNotEmpty ? n.nomeTurma : 'Sem turma',
      subtitulo: (g) {
        final provas = g.map((n) => n.provaId).toSet().length;
        final alunos = g.map((n) => n.chaveAluno).toSet().length;
        return '$provas ${provas == 1 ? 'prova' : 'provas'} • '
            '$alunos ${alunos == 1 ? 'aluno' : 'alunos'}';
      },
    );
    itens.sort((a, b) => a.rotulo.toLowerCase().compareTo(b.rotulo.toLowerCase()));
    return itens;
  }

  /// Média de cada prova do filtro, em ordem cronológica.
  List<ItemMedia> mediasPorProva(FiltroDesempenho filtro) {
    final lista = notasFiltradas(filtro);
    final datas = <String, DateTime>{};
    for (final n in lista) {
      final atual = datas[n.provaId];
      if (atual == null || n.data.isBefore(atual)) datas[n.provaId] = n.data;
    }

    final itens = _agrupar(
      lista,
      chave: (n) => n.provaId,
      rotulo: (n) => n.tituloProva.isNotEmpty ? n.tituloProva : 'Prova ${n.provaId}',
      subtitulo: (g) {
        final n = g.first;
        final partes = [
          if (n.nomeTurma.isNotEmpty) n.nomeTurma,
          if (n.nomeDisciplina.isNotEmpty) n.nomeDisciplina,
          '${g.length} ${g.length == 1 ? 'correção' : 'correções'}',
        ];
        return partes.join(' • ');
      },
    );
    itens.sort((a, b) => datas[a.id]!.compareTo(datas[b.id]!));
    return itens;
  }

  /// Média de cada aluno no filtro, da maior para a menor.
  List<ItemMedia> mediasPorAluno(FiltroDesempenho filtro) {
    final itens = _agrupar(
      notasFiltradas(filtro),
      chave: (n) => n.chaveAluno,
      rotulo: (n) => n.correcao.nomeAluno.isNotEmpty ? n.correcao.nomeAluno : 'Aluno',
      subtitulo: (g) => '${g.length} ${g.length == 1 ? 'prova' : 'provas'}',
    );
    itens.sort((a, b) {
      final comp = b.media.compareTo(a.media);
      return comp != 0 ? comp : a.rotulo.compareTo(b.rotulo);
    });
    return itens;
  }

  /// Nota do aluno em cada prova, com a média da turma naquela prova
  /// como referência.
  List<ItemMedia> notasDoAlunoPorProva(String chaveAluno, FiltroDesempenho filtro) {
    return notasDoAluno(chaveAluno, filtro).map((n) {
      return ItemMedia(
        id: n.correcao.codigoVersao,
        rotulo: n.tituloProva,
        subtitulo: n.nomeDisciplina.isNotEmpty ? n.nomeDisciplina : null,
        media: n.nota,
        quantidade: 1,
        referencia: mediaDe(notasDaProva(n.provaId).map((x) => x.nota)),
      );
    }).toList();
  }

  /// Média do aluno em cada disciplina (ignora o filtro de disciplina).
  List<ItemMedia> mediasDoAlunoPorDisciplina(
    String chaveAluno,
    FiltroDesempenho filtro,
  ) {
    final itens = _agrupar(
      notasDoAluno(chaveAluno, filtro.semDisciplina()),
      chave: (n) => n.disciplinaId,
      rotulo: (n) => n.nomeDisciplina.isNotEmpty ? n.nomeDisciplina : 'Sem disciplina',
      subtitulo: (g) => '${g.length} ${g.length == 1 ? 'prova' : 'provas'}',
    );
    itens.sort((a, b) => a.rotulo.toLowerCase().compareTo(b.rotulo.toLowerCase()));
    return itens;
  }
}
