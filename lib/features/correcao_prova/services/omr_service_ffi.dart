import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'omr_service_models.dart';

class OmrService {
  Future<ResultadoLeituraOmr> lerFolhaDeRespostas({
    required Uint8List imageBytes,
    required int totalQuestoes,
    required int quantidadeAlternativas,
  }) {
    return Isolate.run(
      () => _processarNoIsolate(
        imageBytes: imageBytes,
        totalQuestoes: totalQuestoes,
        quantidadeAlternativas: quantidadeAlternativas,
      ),
    );
  }

  static ResultadoLeituraOmr _processarNoIsolate({
    required Uint8List imageBytes,
    required int totalQuestoes,
    required int quantidadeAlternativas,
  }) {
    cv.Mat? src;
    cv.Mat? gray;
    cv.Mat? blurred;
    cv.Mat? thresh;
    cv.Mat? warped;
    cv.Mat? transformMatrix;

    try {
      src = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
      if (src.isEmpty) {
        throw const OmrException('Não foi possível decodificar a imagem capturada.');
      }

      // 1. Escala de cinza e redução de ruído
      gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);
      blurred = cv.gaussianBlur(gray, (5, 5), 0);

      // 2. Limiarização adaptativa invertida (marcações e âncoras ficam brancas = 255)
      thresh = cv.adaptiveThreshold(
        blurred,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY_INV,
        25,
        12,
      );

      // 3. Localizar os 4 marcadores fiduciais de canto
      final ancoras = _encontrarAncorasDeCanto(thresh, src.cols, src.rows);
      if (ancoras.length != 4) {
        throw const OmrException(
          'Não foi possível detectar os 4 marcadores de canto da folha. '
          'Enquadre toda a área de respostas e tente novamente.',
        );
      }

      // 4. Retificação de perspectiva para plano fixo
      const int larguraAlvo = LayoutFolhaOmr.largura;
      const int alturaAlvo = LayoutFolhaOmr.altura;

      final srcPts = cv.VecPoint.fromList(ancoras.map((p) => cv.Point(p.x.toInt(), p.y.toInt())).toList());
      final dstPts = cv.VecPoint.fromList([
        cv.Point(0, 0),
        cv.Point(larguraAlvo, 0),
        cv.Point(larguraAlvo, alturaAlvo),
        cv.Point(0, alturaAlvo),
      ]);

      transformMatrix = cv.getPerspectiveTransform(srcPts, dstPts);
      warped = cv.warpPerspective(thresh, transformMatrix, (larguraAlvo, alturaAlvo));

      // 5. Fatiar grade e avaliar preenchimento
      return _extrairRespostasDaGrade(
        warped: warped,
        totalQuestoes: totalQuestoes,
        quantidadeAlternativas: quantidadeAlternativas,
      );
    } finally {
      src?.dispose();
      gray?.dispose();
      blurred?.dispose();
      thresh?.dispose();
      warped?.dispose();
      transformMatrix?.dispose();
    }
  }

  /// Ordena os 4 centros: [Top-Left, Top-Right, Bottom-Right, Bottom-Left].
  static List<cv.Point2f> _encontrarAncorasDeCanto(
    cv.Mat thresh,
    int imgWidth,
    int imgHeight,
  ) {
    final (contours, _) = cv.findContours(
      thresh,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );

    final areaTotal = imgWidth * imgHeight;
    final candidatos = <cv.Point2f>[];

    for (var i = 0; i < contours.length; i++) {
      final contorno = contours[i];
      final area = cv.contourArea(contorno);

      if (area < areaTotal * 0.0005 || area > areaTotal * 0.03) continue;

      final perimetro = cv.arcLength(contorno, true);
      final aprox = cv.approxPolyDP(contorno, 0.04 * perimetro, true);

      if (aprox.length == 4) {
        final rect = cv.boundingRect(aprox);
        final aspectRatio = rect.width / rect.height;
        if (aspectRatio >= 0.75 && aspectRatio <= 1.33) {
          candidatos.add(
            cv.Point2f(rect.x + rect.width / 2.0, rect.y + rect.height / 2.0),
          );
        }
      }
      aprox.dispose();
    }
    contours.dispose();

    if (candidatos.length < 4) return [];

    cv.Point2f? topLeft;
    cv.Point2f? topRight;
    cv.Point2f? bottomRight;
    cv.Point2f? bottomLeft;

    var minSoma = double.infinity;
    var maxSoma = -double.infinity;
    var minDiff = double.infinity;
    var maxDiff = -double.infinity;

    for (final p in candidatos) {
      final soma = p.x + p.y;
      final diff = p.y - p.x;

      if (soma < minSoma) {
        minSoma = soma;
        topLeft = p;
      }
      if (soma > maxSoma) {
        maxSoma = soma;
        bottomRight = p;
      }
      if (diff < minDiff) {
        minDiff = diff;
        topRight = p;
      }
      if (diff > maxDiff) {
        maxDiff = diff;
        bottomLeft = p;
      }
    }

    final selecionados = [topLeft!, topRight!, bottomRight!, bottomLeft!];
    for (var i = 0; i < selecionados.length; i++) {
      for (var j = i + 1; j < selecionados.length; j++) {
        final dist = math.sqrt(
          math.pow(selecionados[i].x - selecionados[j].x, 2) +
          math.pow(selecionados[i].y - selecionados[j].y, 2)
        );
        if (dist < 50) return [];
      }
    }

    return selecionados;
  }

  static ResultadoLeituraOmr _extrairRespostasDaGrade({
    required cv.Mat warped,
    required int totalQuestoes,
    required int quantidadeAlternativas,
  }) {
    final respostas = <int?>[];
    final alertas = <int>[];
    const double limiarMarcado = LayoutFolhaOmr.limiarMarcado;

    for (var q = 0; q < totalQuestoes; q++) {
      final marcadasNaQuestao = <int>[];

      for (var alt = 0; alt < quantidadeAlternativas; alt++) {
        // Mede o miolo da caixa impressa (sem a borda), na mesma posição
        // em que o PDF desenha a caixa.
        final caixa = LayoutFolhaOmr.caixa(
          questao: q,
          alternativa: alt,
          totalQuestoes: totalQuestoes,
          quantidadeAlternativas: quantidadeAlternativas,
        );
        final recuoX = caixa.largura * 0.15;
        final recuoY = caixa.altura * 0.15;

        final x = (caixa.x + recuoX).round().clamp(0, warped.cols - 1);
        final y = (caixa.y + recuoY).round().clamp(0, warped.rows - 1);
        final w = math.max(1, math.min((caixa.largura - 2 * recuoX).round(), warped.cols - x));
        final h = math.max(1, math.min((caixa.altura - 2 * recuoY).round(), warped.rows - y));

        final celula = warped.region(cv.Rect(x, y, w, h));
        final pixelsPreenchidos = cv.countNonZero(celula);
        celula.dispose();

        if (pixelsPreenchidos / (w * h) >= limiarMarcado) {
          marcadasNaQuestao.add(alt);
        }
      }

      if (marcadasNaQuestao.length == 1) {
        respostas.add(marcadasNaQuestao.first);
      } else if (marcadasNaQuestao.isEmpty) {
        respostas.add(null);
      } else {
        respostas.add(null);
        alertas.add(q + 1);
      }
    }

    return ResultadoLeituraOmr(
      respostasMarcadas: respostas,
      questoesComAlerta: alertas,
    );
  }
}
