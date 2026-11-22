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

  // ------------------------------------------------- redefinição de senha
  //
  // Fluxo: o Firebase envia o e-mail de redefinição; o professor copia o
  // link (ou só o código) do e-mail e cola no app; o app valida o código e
  // troca a senha. Não precisa de servidor próprio.

  /// Envia o e-mail de redefinição. Por segurança, o Firebase pode não
  /// avisar quando o e-mail não tem conta: a tela usa mensagem neutra.
  Future<void> enviarEmailRedefinicao(String email) async {
    try {
      await _auth.setLanguageCode('pt');
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_traduzirErroAuth(e.code));
    }
  }

  /// Aceita o link inteiro do e-mail ou só o código (`oobCode`).
  static String extrairCodigoRedefinicao(String texto) {
    final limpo = texto.trim();
    final uri = Uri.tryParse(limpo);
    if (uri != null) {
      final direto = uri.queryParameters['oobCode'];
      if (direto != null && direto.isNotEmpty) return direto;
      // Alguns provedores de e-mail embrulham o link num redirecionamento.
      for (final valor in uri.queryParameters.values) {
        final interno = Uri.tryParse(valor)?.queryParameters['oobCode'];
        if (interno != null && interno.isNotEmpty) return interno;
      }
    }
    final achado = RegExp(r'oobCode=([^&\s]+)').firstMatch(limpo);
    if (achado != null) return Uri.decodeComponent(achado.group(1)!);
    return limpo;
  }

  /// Confere o código e retorna o e-mail da conta que será alterada.
  Future<String> verificarCodigoRedefinicao(String codigo) async {
    try {
      return await _auth.verifyPasswordResetCode(codigo);
    } on FirebaseAuthException catch (e) {
      throw Exception(_traduzirErroAuth(e.code));
    }
  }

  Future<void> redefinirSenha({required String codigo, required String novaSenha}) async {
    try {
      await _auth.confirmPasswordReset(code: codigo, newPassword: novaSenha);
    } on FirebaseAuthException catch (e) {
      throw Exception(_traduzirErroAuth(e.code));
    }
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
      case 'expired-action-code':
        return 'O código expirou. Peça um novo e-mail de redefinição.';
      case 'invalid-action-code':
        return 'Código inválido ou já utilizado. Confira o link copiado ou peça um novo e-mail.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
      case 'missing-email':
        return 'Informe o e-mail.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique a rede e tente de novo.';
      default:
        return 'Ocorreu um erro desconhecido. Tente novamente. ($codigo)';
    }
  }
}
