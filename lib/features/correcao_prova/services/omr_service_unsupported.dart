import 'dart:typed_data';
import 'omr_service_models.dart';

class OmrService {
  Future<ResultadoLeituraOmr> lerFolhaDeRespostas({
    required Uint8List imageBytes,
    required int totalQuestoes,
    required int quantidadeAlternativas,
  }) {
    throw const OmrException('A leitura automática da folha não é suportada na Web.');
  }
}