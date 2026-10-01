import 'dart:async';

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
    final controller = _controller(
      inventory: ModelInventory(
        models: const [
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
    final controller = _controller();

    await controller.startPushToTalk();

    expect(controller.messages, hasLength(1));
    expect(controller.messages.single.translation, 'translated text');
    expect(controller.phase, InterpreterPhase.idle);
  });

  // Regression: the audio service used to be permanently closed after the
  // first recording, so the second attempt always failed.
  test('the microphone can be opened again after a capture', () async {
    final audio = _FakeAudioInputService();
    final controller = _controller(audioInputService: audio);

    await controller.startPushToTalk();
    expect(controller.messages, hasLength(1));

    await controller.startPushToTalk();
    expect(controller.messages, hasLength(2));
    expect(audio.closeCount, 2);
    expect(audio.openCount, 2);
  });

  // Regression: an exception in transcribe/translate used to leave the phase
  // stuck on "translating", disabling the whole UI until restart.
  test('a translation failure reports a reason and unlocks the UI', () async {
    final controller = _controller(
      translationEngine: const _ThrowingTranslationEngine(),
    );

    await controller.startPushToTalk();

    expect(controller.phase, InterpreterPhase.idle);
    expect(controller.isBusy, isFalse);
    expect(controller.messages, isEmpty);
    expect(controller.status, isNot('Translated on device'));
    expect(controller.status, contains('Translation failed'));
  });

  test('a speech recognition failure does not wedge the controller', () async {
    final controller = _controller(
      speechRecognizer: const _ThrowingSpeechRecognizer(),
    );

    await controller.startPushToTalk();

    expect(controller.phase, InterpreterPhase.idle);
    expect(controller.isBusy, isFalse);
    expect(controller.status, contains('Interpreting failed'));
  });

  test('an empty transcript is reported instead of showing a blank line', () async {
    final controller = _controller(
      speechRecognizer: const _EmptySpeechRecognizer(),
    );

    await controller.startPushToTalk();

    expect(controller.phase, InterpreterPhase.idle);
    expect(controller.messages, isEmpty);
    expect(controller.status, contains('No speech recognised'));
  });

  test('silent audio is reported and never transcribed', () async {
    final controller = _controller(vadService: const _SilentVadService());

    await controller.startPushToTalk();

    expect(controller.messages, isEmpty);
    expect(controller.phase, InterpreterPhase.idle);
    expect(controller.status, 'No speech detected');
  });

  test('capture stops at the requested maximum duration', () async {
    final audio = _NeverEndingAudioInputService();
    final controller = _controller(audioInputService: audio);

    await controller.startPushToTalk(
      maxDuration: const Duration(milliseconds: 120),
    );

    expect(controller.phase, InterpreterPhase.idle);
    expect(controller.messages, hasLength(1));
    // The never-ending stream was cut off rather than waited on.
    expect(audio.wasClosed, isTrue);
  });

  test('requesting a release ends the capture early', () async {
    final controller = _controller(
      audioInputService: _NeverEndingAudioInputService(),
    );

    final capture = controller.startPushToTalk(
      maxDuration: const Duration(seconds: 30),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    controller.requestPushToTalkRelease();
    await capture;

    expect(controller.phase, InterpreterPhase.idle);
    expect(controller.messages, hasLength(1));
  });

  test('continuous streaming session works and yields translated messages', () async {
    final controller = _controller();

    controller.setMode(InterpreterMode.subtitles);
    expect(controller.isStreamingMode, true);

    await controller.startStreaming();
    expect(controller.isStreaming, true);

    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(controller.messages, isNotEmpty);
    expect(controller.messages.first.translation, 'translated text');

    await controller.stopStreaming();
    expect(controller.isStreaming, isFalse);
    expect(controller.phase, InterpreterPhase.idle);
  });

  // Regression: a failing utterance used to kill the whole stream.
  test('streaming survives a single failed translation', () async {
    var failNext = true;
    final controller = _controller(
      audioInputService: _UtteranceStreamAudioInputService(),
      vadService: const _ContentVadService(),
      translationEngine: _FlakyTranslationEngine(() {
        if (failNext) {
          failNext = false;
          return null;
        }
        return 'translated text';
      }),
    );

    controller.setMode(InterpreterMode.subtitles);
    await controller.startStreaming();
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    expect(controller.messages, isNotEmpty);
    expect(controller.messages.first.translation, 'translated text');

    await controller.stopStreaming();
  });

  test('streaming can be started again after being stopped', () async {
    final controller = _controller();

    controller.setMode(InterpreterMode.subtitles);

    await controller.startStreaming();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await controller.stopStreaming();
    expect(controller.isStreaming, isFalse);

    await controller.startStreaming();
    expect(controller.isStreaming, true);
    await controller.stopStreaming();
  });

  // Regression: dispose() used to call stopStreaming(), which notified
  // listeners on an already-disposed ChangeNotifier.
  test('dispose does not notify listeners', () async {
    final controller = _controller();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setMode(InterpreterMode.subtitles);
    await controller.startStreaming();
    controller.dispose();

    expect(notifications, greaterThan(0));
  });
}

ConversationController _controller({
  ModelInventory? inventory,
  AudioInputService? audioInputService,
  SpeechRecognizer? speechRecognizer,
  TranslationEngine? translationEngine,
  VadService? vadService,
}) {
  return ConversationController(
    audioInputService: audioInputService ?? _FakeAudioInputService(),
    speechRecognizer: speechRecognizer ?? const _FakeSpeechRecognizer(),
    translationEngine: translationEngine ?? const _FakeTranslationEngine(),
    ttsService: const _FakeTtsService(),
    vadService: vadService ?? const _FakeVadService(),
    modelInventory: inventory ?? ModelInventory.mvpDefaults(),
  );
}

class _FakeAudioInputService implements AudioInputService {
  int openCount = 0;
  int closeCount = 0;
  @override
  Stream<List<int>> openMicrophoneStream() async* {
    openCount++;
    yield List.filled(16000 * 2, 8);
  }

  @override
  Future<void> close() async {
    closeCount++;
  }
}

/// Never ends, like a real microphone. Exercises the duration and release caps.
class _NeverEndingAudioInputService implements AudioInputService {
  bool wasClosed = false;

  @override
  Stream<List<int>> openMicrophoneStream() {
    return Stream.periodic(
      const Duration(milliseconds: 10),
      (_) => List.filled(320, 64),
    );
  }

  @override
  Future<void> close() async {
    wasClosed = true;
  }
}

/// Emits repeating speech/silence utterances so the streaming session produces
/// more than one message. Silent chunks are all zeros; speech chunks are not.
/// Each cycle is ~20 ms of speech followed by ~680 ms of silence, which is long
/// enough to close an utterance.
class _UtteranceStreamAudioInputService implements AudioInputService {
  int _tick = 0;

  @override
  Stream<List<int>> openMicrophoneStream() {
    return Stream.periodic(const Duration(milliseconds: 10), (_) {
      final isSpeech = (_tick++ % 70) < 2;
      return List.filled(3200, isSpeech ? 64 : 0);
    });
  }

  @override
  Future<void> close() async {}
}

/// Treats an all-zero chunk as silence.
class _ContentVadService implements VadService {
  const _ContentVadService();

  @override
  Future<bool> detectSpeech(List<int> audioChunk) async {
    return audioChunk.any((byte) => byte != 0);
  }
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

class _EmptySpeechRecognizer implements SpeechRecognizer {
  const _EmptySpeechRecognizer();

  @override
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  }) async {
    return '   ';
  }
}

class _ThrowingSpeechRecognizer implements SpeechRecognizer {
  const _ThrowingSpeechRecognizer();

  @override
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  }) async {
    throw StateError('whisper native crash');
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

class _ThrowingTranslationEngine implements TranslationEngine {
  const _ThrowingTranslationEngine();

  @override
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async {
    throw StateError('MlKitException: model not downloaded');
  }
}

class _FlakyTranslationEngine implements TranslationEngine {
  _FlakyTranslationEngine(this._next);

  final String? Function() _next;

  @override
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async {
    final result = _next();
    if (result == null) {
      throw StateError('transient failure');
    }
    return result;
  }
}

class _FakeTtsService implements TtsService {
  const _FakeTtsService();

  @override
  Future<void> speak(String text, {required SupportedLanguage language}) async {}
}

class _FakeVadService implements VadService {
  const _FakeVadService();

  @override
  Future<bool> detectSpeech(List<int> audioChunk) async => true;
}

class _SilentVadService implements VadService {
  const _SilentVadService();

  @override
  Future<bool> detectSpeech(List<int> audioChunk) async => false;
}
