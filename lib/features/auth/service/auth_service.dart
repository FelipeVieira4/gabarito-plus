import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gabarito_plus/core/professor_db.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get usuarioAtual => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> login({required String email, required String password}) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(_traduzirErroAuth(e.code));
    }
  }

  Future<UserCredential> cadastrar({
    required String email,
    required String password,
    String? nome,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (nome != null && nome.isNotEmpty) {
        await credential.user?.updateDisplayName(nome);
      }
      await _criarPerfil(email: email, nome: nome);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_traduzirErroAuth(e.code));
    }
  }

  /// Documento `professores/{uid}`. Os dados do professor (alunos, turmas...)
  /// são subcoleções dele e funcionam sem este documento; ele só guarda o
  /// perfil. Falha aqui não deve desfazer a criação da conta.
  Future<void> _criarPerfil({required String email, String? nome}) async {
    try {
      await ProfessorDb.raiz.set({
        'email': email,
        'nome': nome ?? '',
        'criadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String _traduzirErroAuth(String codigo) {
    switch (codigo) {
      case 'user-not-found':
        return 'Nenhum usuário encontrado para este e-mail.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'invalid-credential':
        return 'Credenciais inválidas. Verifique seu e-mail e senha.';
      case 'email-already-in-use':
        return 'Este e-mail já está sendo utilizado.';
      case 'weak-password':
        return 'A senha fornecida é muito fraca.';
      case 'invalid-email':
        return 'O e-mail fornecido é inválido.';
      case 'operation-not-allowed':
        return 'Operação não permitida. Contate o suporte.';
      case 'user-disabled':
        return 'Este usuário foi desabilitado.';
      default:
        return 'Ocorreu um erro desconhecido. Tente novamente. ($codigo)';
    }
  }
}
