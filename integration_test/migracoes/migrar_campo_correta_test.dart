// Migração única: nas alternativas de `questoes`, troca o campo "correta" por
// "isCorreta" (booleano), que é o nome que o app lê. Questões gravadas com
// "correta" aparecem sem alternativa correta e geram gabaritos com "@".
//
// NÃO roda junto com os outros testes: só executa com MIGRAR=true.
// Por padrão é uma SIMULAÇÃO (só lista o que mudaria). Para gravar, acrescente
// APLICAR=true. As credenciais vêm por --dart-define e nunca devem ser
// escritas aqui.
//
// 1. Faça backup da coleção `questoes` (exportação no Console/gcloud).
// 2. Simule e confira o relatório:
//      fvm flutter test integration_test/migracoes/migrar_campo_correta_test.dart -d windows \
//        --dart-define=MIGRAR=true \
//        --dart-define=TEST_EMAIL=<email> --dart-define=TEST_PASSWORD=<senha>
// 3. Aplique (mesmo comando com --dart-define=APLICAR=true).
// 4. Rode a simulação de novo: deve dizer que nada precisa mudar.
//
// Para testar contra o emulador local, acrescente --dart-define=USE_EMULATOR=true.
//
// Provas já geradas guardam uma cópia congelada das questões e NÃO são
// corrigidas por esta migração: regere-as em Provas > Provas Geradas.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabarito_plus/firebase_options.dart';
import 'package:integration_test/integration_test.dart';

import 'normalizar_alternativas.dart';

const _migrar = bool.fromEnvironment('MIGRAR');
const _aplicar = bool.fromEnvironment('APLICAR');
const _email = String.fromEnvironment('TEST_EMAIL');
const _senha = String.fromEnvironment('TEST_PASSWORD');
const _usarEmulador = bool.fromEnvironment('USE_EMULATOR');

const _naoExecutar = !_migrar || _email == '' || _senha == '';

/// Abaixo do limite de 500 operações por batch do Firestore.
const _tamanhoLote = 400;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'migra "correta" para "isCorreta" nas alternativas das questões',
    skip: _naoExecutar,
    (tester) async {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      if (_usarEmulador) {
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      }

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email,
          password: _senha,
        );
      } on FirebaseAuthException catch (e) {
        fail('Login falhou: ${e.code} - ${e.message}');
      }

      final db = FirebaseFirestore.instance;
      final snap = await db.collection('questoes').get();

      final aAlterar = <(DocumentReference, List<Map<String, dynamic>>)>[];
      final comProblema = <String>[];
      final semUmaCorreta = <String>[];

      for (final doc in snap.docs) {
        final r = normalizarAlternativas(doc.data()['alternativas']);
        if (r.problema != null) {
          comProblema.add('${doc.id}: ${r.problema}');
          continue;
        }
        if (r.corretas != 1) {
          semUmaCorreta.add('${doc.id}: ${r.corretas} alternativas corretas');
        }
        if (r.alterada) aAlterar.add((doc.reference, r.alternativas));
      }

      debugPrint('');
      debugPrint('=== Migração "correta" -> "isCorreta" '
          '(${_aplicar ? 'APLICANDO' : 'SIMULAÇÃO'}) ===');
      debugPrint('Questões lidas: ${snap.docs.length}');
      debugPrint('A alterar: ${aAlterar.length}');
      for (final (ref, _) in aAlterar) {
        debugPrint('  - ${ref.id}');
      }
      debugPrint('Ignoradas por problema (revise à mão): ${comProblema.length}');
      for (final linha in comProblema) {
        debugPrint('  - $linha');
      }
      debugPrint('Sem exatamente uma correta (revise no app): ${semUmaCorreta.length}');
      for (final linha in semUmaCorreta) {
        debugPrint('  - $linha');
      }

      if (_aplicar && aAlterar.isNotEmpty) {
        for (var i = 0; i < aAlterar.length; i += _tamanhoLote) {
          final batch = db.batch();
          for (final (ref, alternativas) in aAlterar.skip(i).take(_tamanhoLote)) {
            // só o campo "alternativas": o resto da questão fica intacto
            batch.update(ref, {'alternativas': alternativas});
          }
          await batch.commit();
        }
        debugPrint('Gravadas: ${aAlterar.length} questões.');
      } else if (!_aplicar) {
        debugPrint('Nada foi gravado. Para aplicar, rode com --dart-define=APLICAR=true.');
      }

      await FirebaseAuth.instance.signOut();
    },
  );
}
