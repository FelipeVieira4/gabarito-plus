/// Geometria da folha de respostas, compartilhada pelo leitor (OMR) e pelo
/// PDF que imprime a folha. Medidas em pixels da imagem retificada: o
/// retângulo formado pelos centros dos 4 marcadores de canto vira
/// [largura] x [altura]. Mudar aqui muda a folha impressa e a leitura juntas.
class LayoutFolhaOmr {
  LayoutFolhaOmr._();

  static const int largura = 800;
  static const int altura = 1200;

  static const int margemEsquerda = 140;
  static const int margemDireita = 40;
  static const int margemSuperior = 60;
  static const int margemInferior = 60;

  /// Fração de cada célula descartada em cada borda ao medir o preenchimento.
  static const double recuoCelula = 0.15;

  /// Fração mínima da área medida que precisa estar pintada.
  static const double limiarMarcado = 0.42;
}

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