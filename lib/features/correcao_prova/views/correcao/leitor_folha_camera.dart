import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class LeitorFolhaCamera extends StatefulWidget {
  const LeitorFolhaCamera({
    super.key,
    required this.instrucao,
    required this.onImagemCapturada,
  });

  final String instrucao;
  final Future<void> Function(Uint8List bytes) onImagemCapturada;

  @override
  State<LeitorFolhaCamera> createState() => _LeitorFolhaCameraState();
}

class _LeitorFolhaCameraState extends State<LeitorFolhaCamera> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _inicializando = true;
  bool _processando = false;
  String? _erroCamera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _erroCamera = 'Nenhuma câmera encontrada no dispositivo.';
          _inicializando = false;
        });
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
    } catch (e) {
      _erroCamera = 'Erro ao inicializar a câmera: $e';
    } finally {
      if (mounted) {
        setState(() => _inicializando = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _capturar() async {
    if (_controller == null || !_controller!.value.isInitialized || _processando) {
      return;
    }

    setState(() => _processando = true);
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      await widget.onImagemCapturada(bytes);
    } catch (e) {
      // Ignore ou mostre erro se aplicável. O processamento vai resetar depois.
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inicializando) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_erroCamera != null || _controller == null) {
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
                  _erroCamera ?? 'Erro desconhecido',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final proporcaoMoldura = 3 / 4;
          
          final widthBase = constraints.maxWidth * 0.8;
          final heightBase = widthBase / proporcaoMoldura;

          var w = widthBase;
          var h = heightBase;
          
          if (h > constraints.maxHeight * 0.8) {
            h = constraints.maxHeight * 0.8;
            w = h * proporcaoMoldura;
          }

          final janela = Rect.fromCenter(
            center: constraints.biggest.center(Offset.zero),
            width: w,
            height: h,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: CameraPreview(_controller!),
              ),
              IgnorePointer(
                child: CustomPaint(painter: _MolduraPainter(janela)),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: janela.bottom + 20,
                child: Text(
                  widget.instrucao,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.extended(
                    onPressed: _processando ? null : _capturar,
                    icon: _processando 
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.camera_alt),
                    label: Text(_processando ? 'Processando...' : 'Capturar e ler folha'),
                  ),
                ),
              ),
            ],
          );
        },
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
