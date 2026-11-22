import 'package:flutter_test/flutter_test.dart';
import 'package:gabarito_plus/features/auth/service/auth_service.dart';

void main() {
  group('extrairCodigoRedefinicao', () {
    test('link do e-mail do Firebase', () {
      const link = 'https://projeto.firebaseapp.com/__/auth/action'
          '?mode=resetPassword&oobCode=AbC-123_xyz&apiKey=KEY&lang=pt';
      expect(AuthService.extrairCodigoRedefinicao(link), 'AbC-123_xyz');
    });

    test('link embrulhado em redirecionamento do provedor de e-mail', () {
      final interno = Uri.encodeComponent(
        'https://projeto.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=COD42',
      );
      final link = 'https://safelinks.exemplo.com/?url=$interno&data=1';
      expect(AuthService.extrairCodigoRedefinicao(link), 'COD42');
    });

    test('só o código, com espaços em volta', () {
      expect(AuthService.extrairCodigoRedefinicao('  COD42  '), 'COD42');
    });

    test('texto com o link no meio', () {
      expect(
        AuthService.extrairCodigoRedefinicao(
          'Clique: https://x.firebaseapp.com/__/auth/action?oobCode=XYZ9&mode=resetPassword fim',
        ),
        'XYZ9',
      );
    });
  });
}
