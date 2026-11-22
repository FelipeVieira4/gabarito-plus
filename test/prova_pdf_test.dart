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
    for (final total in [5, 10, 25, 50]) {
      test('$total questões', () {
        final g = GeometriaFolha(totalQuestoes: total, quantidadeAlternativas: 5);

        // Proporção 2:3 entre os centros dos marcadores, como na retificação.
        expect(g.largura / g.altura, closeTo(800 / 1200, 1e-9));

        // Primeira célula e fim da grade nas mesmas frações do leitor.
        expect(g.xCelula(0) / g.largura,
            closeTo(LayoutFolhaOmr.margemEsquerda / LayoutFolhaOmr.largura, 1e-9));
        expect(g.yCelula(0) / g.altura,
            closeTo(LayoutFolhaOmr.margemSuperior / LayoutFolhaOmr.altura, 1e-9));
        expect(
          g.xCelula(5) / g.largura,
          closeTo(
            (LayoutFolhaOmr.largura - LayoutFolhaOmr.margemDireita) / LayoutFolhaOmr.largura,
            1e-9,
          ),
        );
        expect(
          g.yCelula(total) / g.altura,
          closeTo(
            (LayoutFolhaOmr.altura - LayoutFolhaOmr.margemInferior) / LayoutFolhaOmr.altura,
            1e-9,
          ),
        );

        // Folha cabe numa página A4 (842 pt de altura) com o cabeçalho.
        expect(g.altura, lessThanOrEqualTo(560));
        // QR centralizado acima não pode virar "canto" (ver GeometriaFolha).
        expect(g.largura / 2 - 32, greaterThan(85));
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
