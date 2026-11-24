import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:gabarito_plus/features/correcao_prova/services/omr_service_models.dart';
import 'package:gabarito_plus/features/provas/data/prova.dart';
import 'package:gabarito_plus/features/provas/data/versao_prova.dart';
import 'package:gabarito_plus/features/provas/pdf/layout_prova_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';

String _letra(int indice) => String.fromCharCode(65 + indice);

/// Maior quantidade de alternativas entre as questões da versão. É o mesmo
/// cálculo de `GabaritoLido.daVersao`, que a leitura da folha usa para
/// dividir as colunas: precisa bater com a folha impressa.
int quantidadeAlternativasDaVersao(VersaoProva versao) =>
    versao.questoes.fold<int>(
      0,
      (maior, q) =>
          q.alternativas.length > maior ? q.alternativas.length : maior,
    );

/// Folha de respostas em pontos do PDF, a partir da geometria do leitor
/// ([LayoutFolhaOmr]). As coordenadas são relativas ao centro do marcador
/// superior esquerdo.
///
/// O leitor retifica a foto para 800x1200 usando os centros dos marcadores,
/// então basta escalar: a folha impressa tem sempre o mesmo tamanho, e com
/// poucas questões as caixas ficam juntas no topo (a grade tem no mínimo
/// [LayoutFolhaOmr.linhasMinimas] linhas).
class GeometriaFolha {
  GeometriaFolha({
    required this.totalQuestoes,
    required this.quantidadeAlternativas,
  });

  final int totalQuestoes;
  final int quantidadeAlternativas;

  static const tamanhoMarcador = 22.0;

  /// Distância vertical entre os centros dos marcadores.
  static const altura = 560.0;

  /// Distância horizontal entre os centros dos marcadores (proporção 2:3).
  static const largura =
      altura * LayoutFolhaOmr.largura / LayoutFolhaOmr.altura;

  static const _escala = altura / LayoutFolhaOmr.altura;

  /// Caixa de marcação em pontos do PDF.
  ({double x, double y, double largura, double altura}) caixa(
    int questao,
    int alternativa,
  ) {
    final c = LayoutFolhaOmr.caixa(
      questao: questao,
      alternativa: alternativa,
      totalQuestoes: totalQuestoes,
      quantidadeAlternativas: quantidadeAlternativas,
    );
    return (
      x: c.x * _escala,
      y: c.y * _escala,
      largura: c.largura * _escala,
      altura: c.altura * _escala,
    );
  }

  /// Início da grade (x da primeira coluna), para alinhar os números.
  double get inicioGrade => LayoutFolhaOmr.margemEsquerda * _escala;
}

/// Monta os PDFs das provas: questões, folha de respostas e gabaritos.
class ProvaPdf {
  ProvaPdf._();

  static Future<pw.ThemeData> _tema() async {
    final fonteRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
    );

    final fonteNegrito = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
    );

    return pw.ThemeData.withFont(base: fonteRegular, bold: fonteNegrito);
  }

  /// Todas as provas da turma: uma por aluno, cada uma com sua folha de
  /// respostas. Sem gabarito (o gabarito fica só no app).
  static Future<Uint8List> todasAsProvas(
    Prova prova,
    List<VersaoProva> versoes, {
    LayoutProvaPdf layout = const LayoutProvaPdf(),
  }) async {
    final tema = await _tema();
    final doc = pw.Document(title: prova.titulo, author: 'Gabarito Plus');
    for (final versao in versoes) {
      _adicionarProva(doc, tema, prova, versao, layout);
    }
    return doc.save();
  }

  /// Prova e folha de respostas de um único aluno. Sem a página de
  /// gabarito: este PDF pode ir para a mão do aluno.
  static Future<Uint8List> provaDoAluno(
    Prova prova,
    VersaoProva versao, {
    LayoutProvaPdf layout = const LayoutProvaPdf(),
  }) async {
    final tema = await _tema();
    final doc = pw.Document(
      title: '${prova.titulo} - ${versao.aluno.nome}',
      author: 'Gabarito Plus',
    );
    _adicionarProva(doc, tema, prova, versao, layout);
    return doc.save();
  }

  /// Gabarito do professor em PDF separado. Não contém folha OMR nem QR Code.
  /// Cada versão apresenta as respostas na ordem em que foram embaralhadas.
  static Future<Uint8List> gabaritoDoProfessor(
    Prova prova,
    List<VersaoProva> versoes,
  ) async {
    final tema = await _tema();
    final doc = pw.Document(
      title: 'Gabarito - ${prova.titulo}',
      author: 'Gabarito Plus',
    );

    for (final versao in versoes) {
      doc.addPage(
        pw.MultiPage(
          theme: tema,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => [
            pw.Text(
              'GABARITO DO PROFESSOR',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(prova.titulo),
            pw.Text('Turma: ${prova.turma.nomeTurma}'),
            pw.Text('Código da versão: ${versao.codigo}'),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(65),
                1: const pw.FlexColumnWidth(),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Questão',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Resposta correta',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                for (var i = 0; i < versao.questoes.length; i++)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${i + 1}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _letra(versao.questoes[i].respostaCorreta),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return doc.save();
  }

  // ---------------------------------------------------------------- prova

  static void _adicionarProva(
    pw.Document doc,
    pw.ThemeData tema,
    Prova prova,
    VersaoProva versao,
    LayoutProvaPdf layout,
  ) {
    doc.addPage(
      pw.MultiPage(
        theme: tema,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${prova.titulo} • ${versao.aluno.nome}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              versao.codigo,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (context) => [
          _cabecalhoProva(prova, versao, layout),
          pw.SizedBox(height: 8),
          pw.Text(
            [
              'Marque suas respostas na FOLHA DE RESPOSTAS (página seguinte às questões).',
              if (layout.instrucoesEfetivas.isNotEmpty)
                layout.instrucoesEfetivas,
            ].join('\n'),
            style: pw.TextStyle(fontSize: layout.fonteEfetiva - 1),
          ),
          pw.SizedBox(height: 6),
          for (var i = 0; i < versao.questoes.length; i++)
            ..._questao(i + 1, versao.questoes[i], layout),
        ],
      ),
    );

    doc.addPage(_folhaDeRespostas(tema, prova, versao));
  }

  static pw.Widget _cabecalhoProva(
    Prova prova,
    VersaoProva versao,
    LayoutProvaPdf layout,
  ) {
    pw.Widget campo(String rotulo, String valor, {int flex = 1}) => pw.Expanded(
      flex: flex,
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$rotulo: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.TextSpan(text: valor, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.8, color: PdfColors.grey700),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (layout.instituicaoEfetiva.isNotEmpty)
            pw.Center(
              child: pw.Text(
                layout.instituicaoEfetiva,
                style: pw.TextStyle(
                  fontSize: layout.fonteEfetiva,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          pw.Text(
            prova.titulo,
            style: pw.TextStyle(
              fontSize: layout.fonteEfetiva,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              campo(
                'Disciplina',
                prova.nomeDisciplina.isEmpty ? '—' : prova.nomeDisciplina,
              ),
              campo('Assunto', prova.assunto.nome),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              campo('Turma', prova.turma.nomeTurma),
              campo('Código', versao.codigo),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(children: [campo('Aluno', versao.aluno.nome)]),
          if (layout.exibirData || layout.exibirNota) ...[
            pw.SizedBox(height: 3),
            pw.Row(
              children: [
                if (layout.exibirData) campo('Data', '____/____/________'),
                if (layout.exibirData && layout.exibirNota)
                  pw.SizedBox(width: 12),
                if (layout.exibirNota) campo('Nota', '__________'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static List<pw.Widget> _questao(
    int numero,
    QuestaoEmbaralhada questao,
    LayoutProvaPdf layout,
  ) {
    final enunciado = pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$numero. ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: layout.fonteEfetiva,
            ),
          ),
          pw.TextSpan(
            text: questao.questao.enunciado,
            style: pw.TextStyle(fontSize: layout.fonteEfetiva),
          ),
        ],
      ),
    );

    final alternativas = [
      for (var i = 0; i < questao.alternativas.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, top: 2),
          child: pw.Text(
            '${_letra(i)}) ${questao.alternativas[i]}',
            style: pw.TextStyle(fontSize: layout.fonteAlternativaEfetiva),
          ),
        ),
    ];

    final espacos = <pw.Widget>[];
    if (layout.tipoEspaco != TipoEspacoQuestao.nenhum) {
      for (var i = 0; i < layout.espacoEfetivo; i++) {
        espacos.add(
          pw.Container(
            height: layout.alturaLinha,
            decoration: layout.tipoEspaco == TipoEspacoQuestao.linhasCalculo
                ? const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }
    }

    // Mantém a questão inteira na mesma página; questões muito longas vão
    // em partes para não estourar a página.
    final tamanho =
        questao.questao.enunciado.length +
        questao.alternativas.fold<int>(0, (t, a) => t + a.length);
    if (tamanho > 1500) {
      return [
        pw.SizedBox(height: 10),
        enunciado,
        pw.SizedBox(height: 3),
        ...alternativas,
        ...espacos,
      ];
    }
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            enunciado,
            pw.SizedBox(height: 3),
            ...alternativas,
            ...espacos,
          ],
        ),
      ),
    ];
  }

  // ---------------------------------------------------- folha de respostas

  /// Folha lida pela câmera. Regras para a leitura funcionar:
  /// - os 4 quadrados pretos são os elementos mais nos cantos da folha;
  /// - nada de molduras em volta da grade (o leitor só vê contornos
  ///   externos, e uma moldura esconderia os marcadores).
  static pw.Page _folhaDeRespostas(
    pw.ThemeData tema,
    Prova prova,
    VersaoProva versao,
  ) {
    final totalQuestoes = versao.questoes.length;
    final alternativas = quantidadeAlternativasDaVersao(versao);
    final g = GeometriaFolha(
      totalQuestoes: totalQuestoes,
      quantidadeAlternativas: alternativas,
    );
    const m = GeometriaFolha.tamanhoMarcador;
    const meio = m / 2;

    pw.Widget marcador(double left, double top) => pw.Positioned(
      left: left,
      top: top,
      child: pw.Container(width: m, height: m, color: PdfColors.black),
    );

    final celulas = <pw.Widget>[];
    for (var q = 0; q < totalQuestoes; q++) {
      final primeira = g.caixa(q, 0);
      final fonte = (primeira.altura * 0.6).clamp(6.0, 10.0);

      celulas.add(
        pw.Positioned(
          left: meio + g.inicioGrade - 30,
          top: meio + primeira.y,
          child: pw.SizedBox(
            width: 24,
            height: primeira.altura,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${q + 1}',
                style: pw.TextStyle(
                  fontSize: fonte,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );

      // Questões com menos alternativas que a maior não ganham as caixas extras.
      final doQuestao = versao.questoes[q].alternativas.length;
      for (var a = 0; a < doQuestao; a++) {
        final c = g.caixa(q, a);
        final raio = c.altura / 2 < 5 ? c.altura / 2 : 5.0;
        celulas.add(
          pw.Positioned(
            left: meio + c.x,
            top: meio + c.y,
            child: pw.Container(
              width: c.largura,
              height: c.altura,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.6, color: PdfColors.grey600),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(raio)),
              ),
              child: pw.Text(
                _letra(a),
                style: pw.TextStyle(
                  fontSize: fonte * 0.8,
                  color: PdfColors.grey400,
                ),
              ),
            ),
          ),
        );
      }
    }

    return pw.Page(
      theme: tema,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'FOLHA DE RESPOSTAS',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${prova.titulo} • ${prova.turma.nomeTurma}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Aluno: ${versao.aluno.nome}   •   Código: ${versao.codigo}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: versao.codigo,
            width: 64,
            height: 64,
          ),
          pw.SizedBox(height: 10),
          pw.SizedBox(
            width: GeometriaFolha.largura + m,
            height: GeometriaFolha.altura + m,
            child: pw.Stack(
              children: [
                marcador(0, 0),
                marcador(GeometriaFolha.largura, 0),
                marcador(GeometriaFolha.largura, GeometriaFolha.altura),
                marcador(0, GeometriaFolha.altura),
                ...celulas,
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Pinte TODO o retângulo da alternativa escolhida, com caneta preta ou azul. '
            'Uma única marcação por questão. Não rasure e não dobre a folha.\n'
            'Na correção, fotografe a folha com os 4 quadrados pretos visíveis.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }
}
