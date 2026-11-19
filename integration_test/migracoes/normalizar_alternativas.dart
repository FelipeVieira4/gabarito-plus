// Regra da migração "correta" -> "isCorreta" das alternativas das questões.
// Fica separada do script para ser testada sem Firebase
// (test/normalizar_alternativas_test.dart).

/// Resultado de normalizar as alternativas de uma questão.
class AlternativasNormalizadas {
  AlternativasNormalizadas({
    required this.alternativas,
    required this.alterada,
    required this.corretas,
    this.problema,
  });

  /// Alternativas no formato do app: `{texto, isCorreta: bool}`, sem `correta`.
  final List<Map<String, dynamic>> alternativas;

  /// Se o documento precisa ser regravado.
  final bool alterada;

  /// Quantas alternativas ficaram marcadas como corretas (o esperado é 1).
  final int corretas;

  /// Motivo para NÃO gravar o documento (valor desconhecido ou conflito).
  /// Quando preenchido, a questão deve ser revisada à mão.
  final String? problema;
}

class _ValorInvalido implements Exception {
  _ValorInvalido(this.valor);
  final Object valor;
}

/// `true`/`false` em booleano, texto (`"true"`, `"False"`) ou número (1/0).
/// `null` quando o campo não existe.
bool? _comoBool(Object? valor) {
  if (valor == null || valor is bool) return valor as bool?;
  if (valor is String) {
    switch (valor.trim().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
  }
  if (valor is num) {
    if (valor == 1) return true;
    if (valor == 0) return false;
  }
  throw _ValorInvalido(valor);
}

/// Converte `correta` em `isCorreta` (booleano) em cada alternativa, mantendo
/// os demais campos. Não mexe em nada se houver valor não reconhecido ou se
/// `correta` e `isCorreta` existirem com valores diferentes.
AlternativasNormalizadas normalizarAlternativas(Object? alternativas) {
  if (alternativas is! List) {
    return AlternativasNormalizadas(
      alternativas: const [],
      alterada: false,
      corretas: 0,
      problema: alternativas == null
          ? 'questão sem o campo "alternativas"'
          : '"alternativas" não é uma lista',
    );
  }

  final resultado = <Map<String, dynamic>>[];
  var alterada = false;
  var corretas = 0;

  for (var i = 0; i < alternativas.length; i++) {
    final letra = String.fromCharCode(65 + i);
    final item = alternativas[i];
    if (item is! Map) {
      return AlternativasNormalizadas(
        alternativas: const [],
        alterada: false,
        corretas: 0,
        problema: 'alternativa $letra não é um mapa',
      );
    }
    final original = Map<String, dynamic>.from(item);

    final bool? isCorreta;
    final bool? correta;
    try {
      isCorreta = _comoBool(original['isCorreta']);
      correta = _comoBool(original['correta']);
    } on _ValorInvalido catch (e) {
      return AlternativasNormalizadas(
        alternativas: const [],
        alterada: false,
        corretas: 0,
        problema: 'alternativa $letra tem valor não reconhecido: "${e.valor}"',
      );
    }

    if (isCorreta != null && correta != null && isCorreta != correta) {
      return AlternativasNormalizadas(
        alternativas: const [],
        alterada: false,
        corretas: 0,
        problema: 'alternativa $letra tem "correta" e "isCorreta" diferentes',
      );
    }

    final valor = isCorreta ?? correta ?? false;
    if (valor) corretas++;

    // regravar se havia "correta", se faltava "isCorreta" ou se não era bool
    if (original.containsKey('correta') || original['isCorreta'] is! bool) {
      alterada = true;
    }

    resultado.add({
      ...original..remove('correta'),
      'isCorreta': valor,
    });
  }

  return AlternativasNormalizadas(
    alternativas: resultado,
    alterada: alterada,
    corretas: corretas,
  );
}
