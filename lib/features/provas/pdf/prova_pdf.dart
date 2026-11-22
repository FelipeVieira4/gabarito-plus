import 'dart:typed_data';

import 'package:gabarito_plus/features/correcao_prova/services/omr_service_models.dart';
import 'package:gabarito_plus/features/provas/data/prova.dart';
import 'package:gabarito_plus/features/provas/data/versao_prova.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String _letra(int indice) => String.fromCharCode(65 + indice);

/// Maior quantidade de alternativas entre as questões da versão. É o mesmo
/// cálculo de `GabaritoLido.daVersao`, que a leitura da folha usa para
/// dividir as colunas: precisa bater com a folha impressa.
int quantidadeAlternativasDaVersao(VersaoProva versao) => versao.questoes.fold<int>(
      0,
      (maior, q) => q.alternativas.length > maior ? q.alternativas.length : maior,
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
  GeometriaFolha({required this.totalQuestoes, required this.quantidadeAlternativas});

  final int totalQuestoes;
  final int quantidadeAlternativas;

  static const tamanhoMarcador = 22.0;

  /// Distância vertical entre os centros dos marcadores.
  static const altura = 560.0;

  /// Distância horizontal entre os centros dos marcadores (proporção 2:3).
  static const largura = altura * LayoutFolhaOmr.largura / LayoutFolhaOmr.altura;

  static const _escala = altura / LayoutFolhaOmr.altura;

  /// Caixa de marcação em pontos do PDF.
  ({double x, double y, double largura, double altura}) caixa(int questao, int alternativa) {
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
    // Roboto cobre acentos e símbolos que a Helvetica padrão do PDF não tem.
    // Sem internet, cai na fonte padrão (acentos do português funcionam).
    try {
      final fontes = await Future.wait([
        PdfGoogleFonts.robotoRegular(),
        PdfGoogleFonts.robotoBold(),
      ]).timeout(const Duration(seconds: 10));
      return pw.ThemeData.withFont(base: fontes[0], bold: fontes[1]);
    } catch (_) {
      return pw.ThemeData.base();
    }
  }

  /// Todas as provas da turma (uma por aluno, cada uma com sua folha de
  /// respostas) e, no fim, os gabaritos de todos em forma de matriz.
  static Future<Uint8List> todasAsProvas(Prova prova, List<VersaoProva> versoes) async {
    final tema = await _tema();
    final doc = pw.Document(title: prova.titulo, author: 'Gabarito Plus');
    for (final versao in versoes) {
      _adicionarProva(doc, tema, prova, versao);
    }
    _adicionarMatrizGabaritos(doc, tema, prova, versoes);
    return doc.save();
  }

  /// Prova e folha de respostas de um único aluno. Sem a página de
  /// gabarito: este PDF pode ir para a mão do aluno.
  static Future<Uint8List> provaDoAluno(Prova prova, VersaoProva versao) async {
    final tema = await _tema();
    final doc = pw.Document(
      title: '${prova.titulo} - ${versao.aluno.nome}',
      author: 'Gabarito Plus',
    );
    _adicionarProva(doc, tema, prova, versao);
    return doc.save();
  }

  // ---------------------------------------------------------------- prova

  static void _adicionarProva(
    pw.Document doc,
    pw.ThemeData tema,
    Prova prova,
    VersaoProva versao,
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
          _cabecalhoProva(prova, versao),
          pw.SizedBox(height: 8),
          pw.Text(
            'Marque suas respostas na FOLHA DE RESPOSTAS (página seguinte às questões).',
            style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 6),
          for (var i = 0; i < versao.questoes.length; i++)
            ..._questao(i + 1, versao.questoes[i]),
        ],
      ),
    );

    doc.addPage(_folhaDeRespostas(tema, prova, versao));
  }

  static pw.Widget _cabecalhoProva(Prova prova, VersaoProva versao) {
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
          pw.Text(
            prova.titulo,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            campo('Disciplina', prova.nomeDisciplina.isEmpty ? '—' : prova.nomeDisciplina),
            campo('Assunto', prova.assunto.nome),
          ]),
          pw.SizedBox(height: 3),
          pw.Row(children: [
            campo('Turma', prova.turma.nomeTurma),
            campo('Código', versao.codigo),
          ]),
          pw.SizedBox(height: 3),
          pw.Row(children: [campo('Aluno', versao.aluno.nome)]),
          pw.SizedBox(height: 3),
          pw.Row(children: [
            campo('Data', '____/____/________'),
            campo('Nota', '__________'),
          ]),
        ],
      ),
    );
  }

  static List<pw.Widget> _questao(int numero, QuestaoEmbaralhada questao) {
    final enunciado = pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$numero. ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5),
          ),
          pw.TextSpan(
            text: questao.questao.enunciado,
            style: const pw.TextStyle(fontSize: 10.5),
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
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
    ];

    // Mantém a questão inteira na mesma página; questões muito longas vão
    // em partes para não estourar a página.
    final tamanho = questao.questao.enunciado.length +
        questao.alternativas.fold<int>(0, (t, a) => t + a.length);
    if (tamanho > 1500) {
      return [
        pw.SizedBox(height: 10),
        enunciado,
        pw.SizedBox(height: 3),
        ...alternativas,
      ];
    }
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [enunciado, pw.SizedBox(height: 3), ...alternativas],
        ),
      ),
    ];
  }

  // ---------------------------------------------------- folha de respostas

  /// Folha lida pela câmera. Regras para a leitura funcionar:
  /// - os 4 quadrados pretos são os elementos mais nos cantos da folha;
  /// - nada de molduras em volta da grade (o leitor só vê contornos
  ///   externos, e uma moldura esconderia os marcadores).
  static pw.Page _folhaDeRespostas(pw.ThemeData tema, Prova prova, VersaoProva versao) {
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
                style: pw.TextStyle(fontSize: fonte, fontWeight: pw.FontWeight.bold),
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
                style: pw.TextStyle(fontSize: fonte * 0.8, color: PdfColors.grey400),
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
            barcode: pw.Barcode.qrCode(),
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

  // ------------------------------------------------- gabaritos em matriz

  /// Uma linha por aluno e uma coluna por questão, para economizar papel.
  /// Muitas questões: página em paisagem e a matriz é quebrada em blocos.
  static void _adicionarMatrizGabaritos(
    pw.Document doc,
    pw.ThemeData tema,
    Prova prova,
    List<VersaoProva> versoes,
  ) {
    final totalQuestoes = versoes.fold<int>(
      0,
      (maior, v) => v.questoes.length > maior ? v.questoes.length : maior,
    );
    final paisagem = totalQuestoes > 20;
    final porBloco = paisagem ? 30 : 20;

    final blocos = <pw.Widget>[];
    for (var inicio = 0; inicio < totalQuestoes || inicio == 0; inicio += porBloco) {
      final fim = (inicio + porBloco) < totalQuestoes ? inicio + porBloco : totalQuestoes;
      final colunasQuestoes = fim - inicio;

      blocos.add(
        pw.TableHelper.fromTextArray(
          headers: [
            'Aluno',
            'Código',
            for (var q = inicio; q < fim; q++) '${q + 1}',
          ],
          data: [
            for (final v in versoes)
              [
                v.aluno.nome,
                v.codigo,
                for (var q = inicio; q < fim; q++)
                  q < v.questoes.length ? _letra(v.questoes[q].respostaCorreta) : '',
              ],
          ],
          headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 7.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey500),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          cellAlignment: pw.Alignment.center,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
          },
          columnWidths: {
            0: const pw.FixedColumnWidth(120),
            1: const pw.FixedColumnWidth(58),
            for (var c = 0; c < colunasQuestoes; c++) c + 2: const pw.FlexColumnWidth(1),
          },
        ),
      );
      blocos.add(pw.SizedBox(height: 10));
      if (totalQuestoes == 0) break;
    }

    doc.addPage(
      pw.MultiPage(
        theme: tema,
        pageFormat: paisagem ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            versoes.length == 1 ? 'Gabarito' : 'Gabaritos',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            [
              prova.titulo,
              prova.turma.nomeTurma,
              if (prova.nomeDisciplina.isNotEmpty) prova.nomeDisciplina,
              prova.assunto.nome,
              '${versoes.length} ${versoes.length == 1 ? 'versão' : 'versões'}',
            ].join(' • '),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 8),
          ...blocos,
          pw.Text(
            'Uso do professor: não distribuir aos alunos.',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
}
