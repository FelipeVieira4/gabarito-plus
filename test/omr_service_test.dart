import 'package:flutter_test/flutter_test.dart';
import 'package:gabarito_plus/features/correcao_prova/services/omr_service.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() {
  group('OmrService', () {
    test('processar folha sintética e extrair respostas corretamente', () async {
      // Cria uma imagem sintética
      final img = cv.Mat.zeros(1400, 1000, cv.MatType.CV_8UC3);
      cv.rectangle(img, cv.Rect(0, 0, 1000, 1400), cv.Scalar(255, 255, 255, 255), thickness: cv.FILLED);
      
      // Desenha as 4 âncoras pretas (100x100) nos cantos. 
      // Seus centros ficarão em (150, 150), (850, 150), (150, 1250) e (850, 1250).
      cv.rectangle(img, cv.Rect(100, 100, 100, 100), cv.Scalar.black, thickness: cv.FILLED);
      cv.rectangle(img, cv.Rect(800, 100, 100, 100), cv.Scalar.black, thickness: cv.FILLED);
      cv.rectangle(img, cv.Rect(100, 1200, 100, 100), cv.Scalar.black, thickness: cv.FILLED);
      cv.rectangle(img, cv.Rect(800, 1200, 100, 100), cv.Scalar.black, thickness: cv.FILLED);
      
      void marcarBolha(int q, int alt) {
        // Mapeia coordenadas para o espaço original, transladando 150px
        int x = 150 + 140 + alt * 124 + 62;
        int y = 150 + 60 + q * 108 + 54;
        cv.circle(img, cv.Point(x, y), 35, cv.Scalar.black, thickness: cv.FILLED);
      }
      
      // Q0: Alt 0
      marcarBolha(0, 0);
      // Q1: Alt 1
      marcarBolha(1, 1);
      // Q2: Alt 2
      marcarBolha(2, 2);
      // Q3: Em branco (nenhuma bolha)
      
      // Q4: Dupla marcação (Alt 0 e 1)
      marcarBolha(4, 0);
      marcarBolha(4, 1);
      
      // Codifica para Uint8List
      final bytes = cv.imencode('.png', img).$2;
      img.dispose();

      final service = OmrService();
      final result = await service.lerFolhaDeRespostas(
        imageBytes: bytes,
        totalQuestoes: 10,
        quantidadeAlternativas: 5,
      );

      expect(result.respostasMarcadas.length, 10);
      expect(result.respostasMarcadas[0], 0);
      expect(result.respostasMarcadas[1], 1);
      expect(result.respostasMarcadas[2], 2);
      expect(result.respostasMarcadas[3], null);
      expect(result.respostasMarcadas[4], null);
      
      // Q5 a Q9 ficaram em branco
      expect(result.respostasMarcadas[5], null);
      expect(result.respostasMarcadas[6], null);
      expect(result.respostasMarcadas[7], null);
      expect(result.respostasMarcadas[8], null);
      expect(result.respostasMarcadas[9], null);
      
      // Alerta para Q4 (índice 4 = questão 5)
      expect(result.questoesComAlerta, [5]);
    });
  });
}