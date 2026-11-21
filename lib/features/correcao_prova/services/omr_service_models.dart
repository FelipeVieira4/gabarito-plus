class ResultadoLeituraOmr {
  /// Compatível com `FolhaLida.respostasMarcadas` (0 = A, 1 = B, ..., null = branco/rasura).
  final List<int?> respostasMarcadas;

  /// Números das questões (base 1) com dupla marcação ou rasura detectada.
  final List<int> questoesComAlerta;

  const ResultadoLeituraOmr({
    required this.respostasMarcadas,
    this.questoesComAlerta = const [],
  });
}

class OmrException implements Exception {
  final String mensagem;
  const OmrException(this.mensagem);

  @override
  String toString() => mensagem;
}