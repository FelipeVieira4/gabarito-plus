import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Ponto único que define onde ficam os dados de cada professor:
///
/// ```
/// professores/{uid}
///   ├─ alunos/{id}
///   ├─ turmas/{id}
///   ├─ disciplinas/{id}
///   ├─ assuntos/{id}
///   ├─ questoes/{id}
///   ├─ provas/{id}/versoes/{codigo}
///   └─ correcoes/{codigoVersao}
/// ```
///
/// Tudo é resolvido a cada acesso (nunca guardado em campo), porque
/// repositórios como `ProvaRepository.instancia` são estáticos e vivem mais
/// que a sessão: se o uid fosse guardado, um segundo professor que logasse
/// no mesmo aparelho leria e gravaria nos dados do primeiro.
class ProfessorDb {
  ProfessorDb._();

  static String get uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Nenhum professor autenticado.');
    }
    return uid;
  }

  static DocumentReference<Map<String, dynamic>> get raiz =>
      FirebaseFirestore.instance.collection('professores').doc(uid);

  static CollectionReference<Map<String, dynamic>> colecao(String nome) =>
      raiz.collection(nome);
}
