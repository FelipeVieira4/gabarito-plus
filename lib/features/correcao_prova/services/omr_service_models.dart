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

  /// A grade sempre tem ao menos estas linhas/colunas: com poucas questões
  /// ou alternativas, as células não esticam pela folha inteira (ficam
  /// juntas no topo/esquerda, e o resto da folha fica em branco).
  static const int linhasMinimas = 20;
  static const int colunasMinimas = 5;

  /// Tamanho máximo da caixa de marcação (em pixels da imagem retificada).
  static const double larguraMaximaCaixa = 70;
  static const double alturaMaximaCaixa = 40;

  static int linhasDaGrade(int totalQuestoes) =>
      totalQuestoes > linhasMinimas ? totalQuestoes : linhasMinimas;

  static int colunasDaGrade(int quantidadeAlternativas) =>
      quantidadeAlternativas > colunasMinimas ? quantidadeAlternativas : colunasMinimas;

  static double alturaLinha(int totalQuestoes) =>
      (altura - margemSuperior - margemInferior) / linhasDaGrade(totalQuestoes);

  static double larguraColuna(int quantidadeAlternativas) =>
      (largura - margemEsquerda - margemDireita) / colunasDaGrade(quantidadeAlternativas);

  /// Caixa de marcação (centralizada na célula) da questão [questao] e
  /// alternativa [alternativa], ambas a partir de 0. É a área que a folha
  /// impressa desenha e que o leitor mede.
  static ({double x, double y, double largura, double altura}) caixa({
    required int questao,
    required int alternativa,
    required int totalQuestoes,
    required int quantidadeAlternativas,
  }) {
    final linha = alturaLinha(totalQuestoes);
    final coluna = larguraColuna(quantidadeAlternativas);
    final w = _menor(coluna * (1 - 2 * recuoCelula), larguraMaximaCaixa);
    final h = _menor(linha * (1 - 2 * recuoCelula), alturaMaximaCaixa);
    return (
      x: margemEsquerda + alternativa * coluna + (coluna - w) / 2,
      y: margemSuperior + questao * linha + (linha - h) / 2,
      largura: w,
      altura: h,
    );
  }

  static double _menor(double a, double b) => a < b ? a : b;
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