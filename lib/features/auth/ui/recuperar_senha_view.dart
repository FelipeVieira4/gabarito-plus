import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gabarito_plus/features/auth/service/auth_service.dart';

String _mensagemErro(Object e) => e.toString().replaceAll('Exception: ', '');

/// Recuperação de senha em duas etapas:
/// 1. informa o e-mail e recebe o e-mail de redefinição do Firebase;
/// 2. cola o link (ou código) recebido; se for válido, abre
///    [RedefinirSenhaView] para escolher a nova senha.
class RecuperarSenhaView extends StatefulWidget {
  const RecuperarSenhaView({super.key, this.emailInicial = ''});

  final String emailInicial;

  @override
  State<RecuperarSenhaView> createState() => _RecuperarSenhaViewState();
}

class _RecuperarSenhaViewState extends State<RecuperarSenhaView> {
  final _authService = AuthService();
  final _formEmail = GlobalKey<FormState>();
  final _formCodigo = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.emailInicial);
  final _codigoController = TextEditingController();

  bool _emailEnviado = false;
  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  void _avisar(String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: erro ? Colors.red : null),
      );
  }

  Future<void> _enviarEmail() async {
    if (!_formEmail.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await _authService.enviarEmailRedefinicao(_emailController.text);
      if (!mounted) return;
      setState(() => _emailEnviado = true);
      _avisar('Se houver uma conta com este e-mail, a mensagem foi enviada.');
    } catch (e) {
      if (mounted) _avisar(_mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _colar() async {
    final dados = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = dados?.text?.trim() ?? '';
    if (texto.isEmpty) {
      _avisar('A área de transferência está vazia.');
      return;
    }
    setState(() => _codigoController.text = texto);
  }

  Future<void> _verificarCodigo() async {
    if (!_formCodigo.currentState!.validate()) return;
    final codigo = AuthService.extrairCodigoRedefinicao(_codigoController.text);
    setState(() => _carregando = true);
    try {
      final email = await _authService.verificarCodigoRedefinicao(codigo);
      if (!mounted) return;
      final redefinida = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RedefinirSenhaView(codigo: codigo, email: email),
        ),
      );
      if (redefinida == true && mounted) {
        // Volta ao login avisando que já pode entrar com a nova senha.
        Navigator.pop(context, email);
      }
    } catch (e) {
      if (mounted) _avisar(_mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Etapa(
                  numero: 1,
                  titulo: 'Receber o e-mail de redefinição',
                  concluida: _emailEnviado,
                ),
                const SizedBox(height: 12),
                Form(
                  key: _formEmail,
                  child: TextFormField(
                    controller: _emailController,
                    enabled: !_carregando,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail da conta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) {
                      final valor = v?.trim() ?? '';
                      if (valor.isEmpty) return 'Informe o e-mail.';
                      if (!valor.contains('@')) return 'Informe um e-mail válido.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (_emailEnviado)
                  OutlinedButton.icon(
                    onPressed: _carregando ? null : _enviarEmail,
                    icon: const Icon(Icons.send),
                    label: const Text('Reenviar e-mail'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _carregando ? null : _enviarEmail,
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar e-mail'),
                  ),
                if (_emailEnviado) ...[
                  const SizedBox(height: 32),
                  const _Etapa(numero: 2, titulo: 'Informar o código', concluida: false),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cores.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Abra o e-mail "Redefinir senha" (confira também o spam). '
                      'Toque e segure no link, escolha "Copiar link" e cole aqui. '
                      'Não é preciso abrir o link.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: _formCodigo,
                    child: TextFormField(
                      controller: _codigoController,
                      enabled: !_carregando,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Link ou código recebido',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.vpn_key),
                        suffixIcon: IconButton(
                          tooltip: 'Colar',
                          icon: const Icon(Icons.content_paste),
                          onPressed: _carregando ? null : _colar,
                        ),
                      ),
                      validator: (v) => (v?.trim() ?? '').isEmpty
                          ? 'Cole o link ou o código do e-mail.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _carregando ? null : _verificarCodigo,
                    icon: _carregando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user),
                    label: const Text('Verificar código'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Etapa extends StatelessWidget {
  const _Etapa({required this.numero, required this.titulo, required this.concluida});

  final int numero;
  final String titulo;
  final bool concluida;

  @override
  Widget build(BuildContext context) {
    final cor = concluida ? Colors.green.shade700 : Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: cor,
          child: concluida
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$numero',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Escolha da nova senha, depois que o código foi validado.
/// Retorna true (via Navigator.pop) quando a senha foi trocada.
class RedefinirSenhaView extends StatefulWidget {
  const RedefinirSenhaView({super.key, required this.codigo, required this.email});

  final String codigo;
  final String email;

  @override
  State<RedefinirSenhaView> createState() => _RedefinirSenhaViewState();
}

class _RedefinirSenhaViewState extends State<RedefinirSenhaView> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();
  bool _ocultar = true;
  bool _carregando = false;

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await _authService.redefinirSenha(
        codigo: widget.codigo,
        novaSenha: _senhaController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mensagemErro(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final olho = IconButton(
      icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
      onPressed: () => setState(() => _ocultar = !_ocultar),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Nova senha')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_reset, size: 64, color: Colors.green.shade600),
                  const SizedBox(height: 12),
                  const Text(
                    'Código confirmado!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Escolha a nova senha de ${widget.email}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _senhaController,
                    obscureText: _ocultar,
                    enabled: !_carregando,
                    decoration: InputDecoration(
                      labelText: 'Nova senha',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: olho,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe a nova senha.';
                      if (v.length < 6) return 'A senha deve ter no mínimo 6 caracteres.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmacaoController,
                    obscureText: _ocultar,
                    enabled: !_carregando,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar nova senha',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        v != _senhaController.text ? 'As senhas não conferem.' : null,
                    onFieldSubmitted: (_) => _salvar(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _carregando ? null : _salvar,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _carregando
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar nova senha', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
