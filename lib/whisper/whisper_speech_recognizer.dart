import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../conversation/conversation_settings.dart';
import '../conversation/language.dart';
import '../models/model_download_coordinator.dart';
import 'speech_recognizer.dart';

class WhisperSpeechRecognizer
    implements SpeechRecognizer, SpeechModelPreparer {
  WhisperSpeechRecognizer({WhisperController? controller})
    : _controller = controller ?? WhisperController();

  final WhisperController _controller;

  static WhisperModel _toWhisperModel(SpeechModelProfile profile) {
    return switch (profile) {
      SpeechModelProfile.tiny => WhisperModel.tiny,
      SpeechModelProfile.base => WhisperModel.base,
      SpeechModelProfile.smallInt8 => WhisperModel.small,
    };
  }

  static Uint8List _toWav(List<int> pcm, {int sampleRate = 16000}) {
    final data = Uint8List.fromList(pcm);
    final builder = BytesBuilder();
    void writeStr(String value) => builder.add(value.codeUnits);
    void write32(int value) {
      builder.add([
        value & 0xff,
        (value >> 8) & 0xff,
        (value >> 16) & 0xff,
        (value >> 24) & 0xff,
      ]);
    }

    void write16(int value) {
      builder.add([value & 0xff, (value >> 8) & 0xff]);
    }

    writeStr('RIFF');
    write32(36 + data.length);
    writeStr('WAVE');
    writeStr('fmt ');
    write32(16);
    write16(1);
    write16(1);
    write32(sampleRate);
    write32(sampleRate * 2);
    write16(2);
    write16(16);
    writeStr('data');
    write32(data.length);
    builder.add(data);
    return builder.toBytes();
  }

  @override
  Future<void> prepareSpeechModel(
    SpeechModelProfile profile, {
    void Function(double progress)? onProgress,
  }) {
    return _ensureModelDownloaded(
      _controller,
      _toWhisperModel(profile),
      onProgress: onProgress,
    );
  }

  static Future<void> _ensureModelDownloaded(
    WhisperController controller,
    WhisperModel model, {
    void Function(double progress)? onProgress,
  }) async {
    final modelPath = await controller.getPath(model);
    if (File(modelPath).existsSync()) {
      onProgress?.call(1);
      return;
    }

    final tempPath = '$modelPath.partial';
    final partial = File(tempPath);
    if (await partial.exists()) {
      await partial.delete();
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(model.modelUri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download whisper model ${model.modelName}: '
          'HTTP ${response.statusCode}',
          uri: model.modelUri,
        );
      }

      final total = response.contentLength;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final block in response) {
          sink.add(block);
          received += block.length;
          if (total > 0) {
            onProgress?.call(received / total);
          }
        }
        await sink.flush();
      } catch (_) {
        await sink.close();
        if (await partial.exists()) {
          await partial.delete();
        }
        rethrow;
      }
      await sink.close();
    } finally {
      client.close(force: true);
    }

    await partial.rename(modelPath);
    onProgress?.call(1);
  }

  @override
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  }) async {
    if (audioData.isEmpty) {
      return '';
    }

    final whisperModel = _toWhisperModel(model);
    await _ensureModelDownloaded(_controller, whisperModel);

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/pocket_interpreter_capture_'
      '${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(_toWav(audioData));

    try {
      final result = await _controller.transcribe(
        model: whisperModel,
        audioPath: file.path,
        lang: language.code,
        keepModelLoaded: true,
        noContext: true,
      );
      return (result?.transcription.text ?? '').trim();
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Frees the model parked in native memory by `keepModelLoaded: true`.
  Future<void> dispose() => _controller.releaseModel();
}
