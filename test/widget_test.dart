import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_interpreter/app.dart';
import 'package:pocket_interpreter/app_dependencies.dart';
import 'package:pocket_interpreter/audio/audio_input_service.dart';
import 'package:pocket_interpreter/conversation/conversation_controller.dart';
import 'package:pocket_interpreter/conversation/conversation_settings.dart';
import 'package:pocket_interpreter/conversation/language.dart';
import 'package:pocket_interpreter/models/model_inventory.dart';
import 'package:pocket_interpreter/translation/translation_engine.dart';
import 'package:pocket_interpreter/tts/tts_service.dart';
import 'package:pocket_interpreter/ui/conversation_screen.dart';
import 'package:pocket_interpreter/vad/vad_service.dart';
import 'package:pocket_interpreter/whisper/speech_recognizer.dart';

void main() {
  testWidgets('shows the Pocket Interpreter home screen', (tester) async {
    await tester.pumpWidget(PocketInterpreterApp(dependencies: _dependencies()));

    expect(find.text('Pocket Interpreter'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Hold to interpret'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Offline pack ready'), findsOneWidget);
  });

  testWidgets('shows release information', (tester) async {
    await tester.pumpWidget(PocketInterpreterApp(dependencies: _dependencies()));

    await tester.tap(find.byTooltip('About release'));
    await tester.pumpAndSettle();

    expect(find.text('Pocket Interpreter'), findsWidgets);
    expect(find.text('1.0.0+3 MVP'), findsOneWidget);
  });

  testWidgets('does not claim models are ready before they are downloaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      PocketInterpreterApp(
        dependencies: _dependencies(inventory: ModelInventory.pending()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline models required'), findsOneWidget);
    expect(find.text('Hold to interpret'), findsNothing);
  });

  testWidgets('holding the button starts a capture and releasing ends it', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ConversationScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hold to interpret'), findsOneWidget);
    expect(controller.isBusy, isFalse);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold to interpret')),
    );
    await tester.pump();

    // Pointer down starts recording.
    expect(controller.phase, isNot(InterpreterPhase.idle));

    await gesture.up();

    // Releasing kicks off the decode/translate pipeline, which runs on the
    // real event loop rather than the fake test clock. Drain it so the
    // controller settles back to idle.
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && controller.isBusy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(controller.phase, InterpreterPhase.idle);
  });

  testWidgets('re-downloads models when settings change mid-download', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    var calls = 0;
    final completers = <Completer<void>>[];
    Future<void> ensure() {
      calls++;
      final completer = Completer<void>();
      completers.add(completer);
      return completer.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          controller: controller,
          ensureModelsReady: ensure,
        ),
      ),
    );
    await tester.pump();

    expect(calls, 1);

    controller.setSpeechModel(SpeechModelProfile.smallInt8);
    await tester.pump();

    // The change arrived while the first download was still in flight, so it
    // has to be queued rather than silently dropped.
    expect(calls, 1);

    completers.first.complete();
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
  });
}

ConversationController _controller() {
  return ConversationController(
    audioInputService: const _FakeAudioInputService(),
    speechRecognizer: const _FakeSpeechRecognizer(),
    translationEngine: const _FakeTranslationEngine(),
    ttsService: const _FakeTtsService(),
    vadService: const _FakeVadService(),
    modelInventory: ModelInventory.mvpDefaults(),
  );
}

AppDependencies _dependencies({ModelInventory? inventory}) {
  return AppDependencies(
    modelInventory: inventory ?? ModelInventory.mvpDefaults(),
    audioInputService: const _FakeAudioInputService(),
    speechRecognizer: const _FakeSpeechRecognizer(),
    translationEngine: const _FakeTranslationEngine(),
    ttsService: const _FakeTtsService(),
    vadService: const _FakeVadService(),
  );
}

class _FakeAudioInputService implements AudioInputService {
  const _FakeAudioInputService();

  @override
  Stream<List<int>> openMicrophoneStream() async* {
    yield List.filled(16000 * 2, 8);
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
  Future<void> speak(String text, {required SupportedLanguage language}) async {}
}

class _FakeVadService implements VadService {
  const _FakeVadService();

  @override
  Future<bool> detectSpeech(List<int> audioChunk) async => true;
}
