import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_interpreter/audio/audio_input_service.dart';
import 'package:pocket_interpreter/conversation/conversation_controller.dart';
import 'package:pocket_interpreter/conversation/conversation_settings.dart';
import 'package:pocket_interpreter/conversation/language.dart';
import 'package:pocket_interpreter/models/model_inventory.dart';
import 'package:pocket_interpreter/models/offline_model.dart';
import 'package:pocket_interpreter/translation/translation_engine.dart';
import 'package:pocket_interpreter/tts/tts_service.dart';
import 'package:pocket_interpreter/vad/vad_service.dart';
import 'package:pocket_interpreter/whisper/speech_recognizer.dart';

void main() {
  test('blocks interpreting when required models are missing', () async {
    final controller = ConversationController(
      audioInputService: const _FakeAudioInputService(),
      speechRecognizer: const _FakeSpeechRecognizer(),
      translationEngine: const _FakeTranslationEngine(),
      ttsService: const _FakeTtsService(),
      vadService: const _FakeVadService(),
      modelInventory: const ModelInventory(
        models: [
          OfflineModel(
            id: 'missing-speech',
            name: 'Missing speech model',
            type: OfflineModelType.speech,
            sizeMb: 100,
            status: OfflineModelStatus.missing,
          ),
        ],
      ),
    );

    await controller.startPushToTalk();

    expect(controller.messages, isEmpty);
    expect(
      controller.status,
      'Install required offline models before interpreting',
    );
  });

  test('records a translated message when offline pack is ready', () async {
    final controller = ConversationController(
      audioInputService: const _FakeAudioInputService(),
      speechRecognizer: const _FakeSpeechRecognizer(),
      translationEngine: const _FakeTranslationEngine(),
      ttsService: const _FakeTtsService(),
      vadService: const _FakeVadService(),
      modelInventory: ModelInventory.mvpDefaults(),
    );

    await controller.startPushToTalk();

    expect(controller.messages, hasLength(1));
    expect(controller.messages.single.translation, 'translated text');
    expect(controller.phase, InterpreterPhase.idle);
  });

  test('continuous streaming session works and yields translated messages', () async {
    final controller = ConversationController(
      audioInputService: const _FakeAudioInputService(),
      speechRecognizer: const _FakeSpeechRecognizer(),
      translationEngine: const _FakeTranslationEngine(),
      ttsService: const _FakeTtsService(),
      vadService: const _FakeVadService(),
      modelInventory: ModelInventory.mvpDefaults(),
    );

    controller.setMode(InterpreterMode.subtitles);
    expect(controller.isStreamingMode, true);

    await controller.startStreaming();
    expect(controller.isStreaming, true);

    // Let the async loop run to produce at least one message
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(controller.messages, isNotEmpty);
    expect(controller.messages.first.translation, 'translated text');

    await controller.stopStreaming();
    expect(controller.isStreaming, false);
    expect(controller.phase, InterpreterPhase.idle);
  });
}

class _FakeAudioInputService implements AudioInputService {
  const _FakeAudioInputService();

  @override
  Stream<List<int>> openMicrophoneStream() async* {
    yield List.filled(320, 64);
  }

  @override
  Future<void> close() async {}
}

class _FakeSpeechRecognizer implements SpeechRecognizer {
  const _FakeSpeechRecognizer();

  @override
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  }) async {
    return 'source text';
  }
}

class _FakeTranslationEngine implements TranslationEngine {
  const _FakeTranslationEngine();

  @override
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async {
    return 'translated text';
  }
}

class _FakeTtsService implements TtsService {
  const _FakeTtsService();

  @override
  Future<void> speak(
    String text, {
    required SupportedLanguage language,
  }) async {}
}

class _FakeVadService implements VadService {
  const _FakeVadService();

  @override
  Future<bool> detectSpeech(List<int> audioChunk) async => true;
}

