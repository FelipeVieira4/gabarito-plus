import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

bool get leitorQrSuportado {
  if (kIsWeb) return true;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

class LeitorQrCode extends StatefulWidget {
  const LeitorQrCode({
    super.key,
    required this.instrucao,
    required this.onCodigoLido,
  });

  final String instrucao;

  final Future<void> Function(String codigo) onCodigoLido;

  @override
  State<LeitorQrCode> createState() => _LeitorQrCodeState();
}

class _LeitorQrCodeState extends State<LeitorQrCode>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _processando = false;

  String? _ultimoCodigo;
  DateTime _ultimaLeitura = DateTime.fromMillisecondsSinceEpoch(0);
  static const _intervaloRepeticao = Duration(seconds: 3);

  bool _saiuDoApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final estado = _controller.value;

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _saiuDoApp = true;
      case AppLifecycleState.detached:
        return;
      case AppLifecycleState.inactive:
        if (estado.hasCameraPermission && estado.isRunning) {
          unawaited(_controller.stop().catchError((_) {}));
        }
      case AppLifecycleState.resumed:
        final voltouDasConfiguracoes =
            _saiuDoApp &&
            estado.error?.errorCode == MobileScannerErrorCode.permissionDenied;
        _saiuDoApp = false;
        if (estado.isStarting || estado.isRunning) return;
        if (estado.hasCameraPermission || voltouDasConfiguracoes) {
          unawaited(_controller.start().catchError((_) {}));
        }
    }
  }

  Future<void> _aoDetectar(BarcodeCapture captura) async {
    if (_processando) return;

    final codigo = captura.barcodes
        .map((b) => b.rawValue?.trim())
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (codigo == null) return;

    final agora = DateTime.now();
    if (codigo == _ultimoCodigo &&
        agora.difference(_ultimaLeitura) < _intervaloRepeticao) {
      return;
    }
    _ultimoCodigo = codigo;
    _ultimaLeitura = agora;

    setState(() => _processando = true);
    try {
      await widget.onCodigoLido(codigo);
    } finally {
      if (mounted) {
        _ultimaLeitura = DateTime.now();
        setState(() => _processando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final lado = (constraints.biggest.shortestSide * 0.7).clamp(
            120.0,
            320.0,
          );
          final janela = Rect.fromCenter(
            center: constraints.biggest.center(Offset.zero),
            width: lado,
            height: lado,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: janela,
                onDetect: _aoDetectar,
                errorBuilder: (context, erro) => _ErroCamera(erro: erro),
              ),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, estado, _) {
                  if (estado.error != null) return const SizedBox.shrink();

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: CustomPaint(painter: _MolduraPainter(janela)),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        top: janela.bottom + 20,
                        child: Text(
                          _processando ? 'Buscando prova...' : widget.instrucao,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (_processando)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _BotaoLanterna(controller: _controller),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BotaoLanterna extends StatelessWidget {
  const _BotaoLanterna({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, estado, _) {
        if (!estado.isInitialized ||
            estado.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }

        final ligada = estado.torchState == TorchState.on;
        return IconButton.filledTonal(
          tooltip: ligada ? 'Desligar lanterna' : 'Ligar lanterna',
          icon: Icon(ligada ? Icons.flash_on : Icons.flash_off),
          onPressed: controller.toggleTorch,
        );
      },
    );
  }
}

class _ErroCamera extends StatelessWidget {
  const _ErroCamera({required this.erro});

  final MobileScannerException erro;

  @override
  Widget build(BuildContext context) {
    final mensagem = switch (erro.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Sem permissão para usar a câmera. Libere o acesso nas '
            'configurações do aparelho ou digite o código da prova.',
      MobileScannerErrorCode.unsupported =>
        'Este aparelho não tem câmera compatível. Digite o código da prova.',
      _ => 'Não foi possível abrir a câmera. Digite o código da prova.',
    };

    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, size: 48, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MolduraPainter extends CustomPainter {
  _MolduraPainter(this.janela);

  final Rect janela;

  @override
  void paint(Canvas canvas, Size size) {
    final moldura = RRect.fromRectAndRadius(janela, const Radius.circular(12));

    final fundo = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(moldura);
    canvas.drawPath(fundo, Paint()..color = Colors.black54);

    canvas.drawRRect(
      moldura,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_MolduraPainter antigo) => antigo.janela != janela;
}
