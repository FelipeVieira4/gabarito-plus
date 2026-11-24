import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';
import 'package:gabarito_plus/features/provas/service/desempenho_repository.dart';
import 'package:gabarito_plus/features/provas/ui/dashboard_provas_view.dart';

class DesempenhoRepositoryMemoria implements DesempenhoRepository {
  @override
  Future<AnaliseDesempenho> carregar() async {
    return AnaliseDesempenho.vazia();
  }
}

void main() {
  setUp(() {
    DesempenhoRepository.instancia = DesempenhoRepositoryMemoria();
  });

  testWidgets('DashboardProvasView renderiza sem transbordo (overflow) em tela mobile estreita',
      (tester) async {
    // Define um tamanho de tela de celular compacto (ex: 360x640)
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardProvasView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Provas e Desempenho'), findsOneWidget);
    expect(find.text('Acessos'), findsOneWidget);
    expect(find.text('Consulta de Provas'), findsOneWidget);
    expect(find.text('Desempenho das Turmas'), findsOneWidget);
    expect(find.text('Provas Corrigidas'), findsOneWidget);

    // Garante que não houve exceções de overflow no Flutter
    expect(tester.takeException(), isNull);
  });
}
