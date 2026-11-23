/// O que fica abaixo de cada questão para o aluno resolver.
enum TipoEspacoQuestao {
  /// Nada além das alternativas (comportamento original).
  nenhum,

  /// Espaço em branco para rascunho.
  rascunho,

  /// Linhas horizontais para cálculos.
  linhasCalculo,
}

/// Personalização do layout das provas em PDF (RF07).
///
/// Afeta só as páginas de questões. A folha de respostas (OMR) não recebe
/// este objeto: sua geometria é fixa porque o leitor da câmera depende dela.
///
/// O gabarito do professor NÃO é uma opção daqui: ele é um PDF separado
/// (`ProvaPdf.gabaritoDoProfessor`), para que nenhuma configuração possa
/// colocá-lo num PDF de aluno.
class LayoutProvaPdf {
  const LayoutProvaPdf({
    this.instituicao = '',
    this.instrucoes = '',
    this.tamanhoFonte = fontePadrao,
    this.tipoEspaco = TipoEspacoQuestao.nenhum,
    this.quantidadeEspaco = espacoPadrao,
    this.exibirData = true,
    this.exibirNota = true,
  });

  /// Fonte do enunciado. As alternativas usam 0,5 ponto a menos.
  static const fontePadrao = 10.5;
  static const fonteMinima = 8.0;
  static const fonteMaxima = 16.0;

  /// Linhas (ou "alturas de linha" em branco) abaixo de cada questão.
  static const espacoPadrao = 4;
  static const espacoMinimo = 1;
  static const espacoMaximo = 12;

  /// Nome da instituição, no topo do cabeçalho. Vazio = não exibe.
  final String instituicao;

  /// Instruções ao aluno, abaixo do cabeçalho. Vazio = não exibe.
  final String instrucoes;

  final double tamanhoFonte;
  final TipoEspacoQuestao tipoEspaco;
  final int quantidadeEspaco;
  final bool exibirData;
  final bool exibirNota;

  String get instituicaoEfetiva => instituicao.trim();
  String get instrucoesEfetivas => instrucoes.trim();

  double get fonteEfetiva {
    if (!tamanhoFonte.isFinite) return fontePadrao;
    return tamanhoFonte.clamp(fonteMinima, fonteMaxima).toDouble();
  }

  double get fonteAlternativaEfetiva => fonteEfetiva - 0.5;

  int get espacoEfetivo =>
      quantidadeEspaco.clamp(espacoMinimo, espacoMaximo).toInt();

  /// Altura de uma linha de cálculo, proporcional à fonte.
  double get alturaLinha => (fonteEfetiva * 1.7).clamp(14.0, 28.0).toDouble();

  /// Altura total reservada abaixo de cada questão.
  double get alturaEspaco => tipoEspaco == TipoEspacoQuestao.nenhum
      ? 0.0
      : espacoEfetivo * alturaLinha;

  LayoutProvaPdf copyWith({
    String? instituicao,
    String? instrucoes,
    double? tamanhoFonte,
    TipoEspacoQuestao? tipoEspaco,
    int? quantidadeEspaco,
    bool? exibirData,
    bool? exibirNota,
  }) {
    return LayoutProvaPdf(
      instituicao: instituicao ?? this.instituicao,
      instrucoes: instrucoes ?? this.instrucoes,
      tamanhoFonte: tamanhoFonte ?? this.tamanhoFonte,
      tipoEspaco: tipoEspaco ?? this.tipoEspaco,
      quantidadeEspaco: quantidadeEspaco ?? this.quantidadeEspaco,
      exibirData: exibirData ?? this.exibirData,
      exibirNota: exibirNota ?? this.exibirNota,
    );
  }

  /// Igualdade pelos valores EFETIVOS: dois layouts que geram o mesmo PDF
  /// são iguais (ex.: fonte 99 e fonte 16).
  @override
  bool operator ==(Object other) =>
      other is LayoutProvaPdf &&
      other.instituicaoEfetiva == instituicaoEfetiva &&
      other.instrucoesEfetivas == instrucoesEfetivas &&
      other.fonteEfetiva == fonteEfetiva &&
      other.tipoEspaco == tipoEspaco &&
      other.espacoEfetivo == espacoEfetivo &&
      other.exibirData == exibirData &&
      other.exibirNota == exibirNota;

  @override
  int get hashCode => Object.hash(
    instituicaoEfetiva,
    instrucoesEfetivas,
    fonteEfetiva,
    tipoEspaco,
    espacoEfetivo,
    exibirData,
    exibirNota,
  );
}
