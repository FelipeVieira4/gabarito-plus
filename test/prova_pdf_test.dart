import 'package:flutter_test/flutter_test.dart';
import 'package:gabarito_plus/features/correcao_prova/services/omr_service_models.dart';
import 'package:gabarito_plus/features/geracao_prova/data/embaralhador.dart';
import 'package:gabarito_plus/features/provas/pdf/exportar_pdf.dart';
import 'package:gabarito_plus/features/provas/pdf/prova_pdf.dart';

import 'helpers/fixtures_correcao.dart';

void main() {
  // Com o binding de teste, o download da fonte falha na hora e o PDF usa a
  // fonte padrão (sem depender de internet).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeometriaFolha bate com o leitor da câmera', () {
    const escala = GeometriaFolha.altura / LayoutFolhaOmr.altura;

    test('proporção 2:3 entre os marcadores, como na retificação', () {
      expect(GeometriaFolha.largura / GeometriaFolha.altura, closeTo(800 / 1200, 1e-9));
    });

    for (final total in [2, 10, 25, 50]) {
      test('$total questões', () {
        final g = GeometriaFolha(totalQuestoes: total, quantidadeAlternativas: 4);

        for (var q = 0; q < total; q++) {
          for (var a = 0; a < 4; a++) {
            final pdf = g.caixa(q, a);
            final leitor = LayoutFolhaOmr.caixa(
              questao: q,
              alternativa: a,
              totalQuestoes: total,
              quantidadeAlternativas: 4,
            );
            // Mesma caixa, só que em pontos.
            expect(pdf.x, closeTo(leitor.x * escala, 1e-9));
            expect(pdf.y, closeTo(leitor.y * escala, 1e-9));
            expect(pdf.largura, closeTo(leitor.largura * escala, 1e-9));

            // Dentro da área útil da folha.
            expect(leitor.x + leitor.largura,
                lessThanOrEqualTo(LayoutFolhaOmr.largura - LayoutFolhaOmr.margemDireita));
            expect(leitor.y + leitor.altura,
                lessThanOrEqualTo(LayoutFolhaOmr.altura - LayoutFolhaOmr.margemInferior));
          }
        }

        // Caixas com tamanho limitado: com poucas questões não esticam.
        final c = g.caixa(0, 0);
        expect(c.altura, lessThanOrEqualTo(LayoutFolhaOmr.alturaMaximaCaixa * escala));
        expect(c.largura, lessThanOrEqualTo(LayoutFolhaOmr.larguraMaximaCaixa * escala));
      });
    }
  });

  test('gera o PDF de todas as provas e o de um aluno', () async {
    final prova = provaDeTeste();
    final versoes = Embaralhador.gerarVersoes(prova);

    final todas = await ProvaPdf.todasAsProvas(prova, versoes);
    final doAluno = await ProvaPdf.provaDoAluno(prova, versoes.first);

    expect(String.fromCharCodes(todas.take(4)), '%PDF');
    expect(String.fromCharCodes(doAluno.take(4)), '%PDF');
    expect(todas.length, greaterThan(doAluno.length));
  });

  test('nome de arquivo sem caracteres problemáticos', () {
    expect(nomeArquivoPdf('Prova 1/2: POO'), 'Prova_1_2_POO.pdf');
    expect(nomeArquivoPdf('  '), 'prova.pdf');
  });
}
