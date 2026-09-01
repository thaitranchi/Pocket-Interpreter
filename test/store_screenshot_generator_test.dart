import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_interpreter/audio/audio_input_service.dart';
import 'package:pocket_interpreter/conversation/conversation_controller.dart';
import 'package:pocket_interpreter/conversation/conversation_message.dart';
import 'package:pocket_interpreter/conversation/conversation_settings.dart';
import 'package:pocket_interpreter/conversation/language.dart';
import 'package:pocket_interpreter/entitlements/entitlements.dart';
import 'package:pocket_interpreter/entitlements/entitlement_storage.dart';
import 'package:pocket_interpreter/models/model_inventory.dart';
import 'package:pocket_interpreter/translation/translation_engine.dart';
import 'package:pocket_interpreter/tts/tts_service.dart';
import 'package:pocket_interpreter/ui/conversation_screen.dart';
import 'package:pocket_interpreter/vad/vad_service.dart';
import 'package:pocket_interpreter/whisper/speech_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  testWidgets('phone screenshots 1080x1920', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final free = _controller();
    final pro = _controller(isPro: true);
    final conversation = _controller();
    _injectMessages(conversation);
    final continuous = _controller(mode: InterpreterMode.conversation);
    _injectMessages(continuous);

    await _shot(tester, free, 'phone-home-free');
    await _shot(tester, pro, 'phone-home-pro');
    await _shot(tester, conversation, 'phone-conversation');
    await _shot(tester, continuous, 'phone-continuous');
  });

  testWidgets('tablet screenshots 1920x1080', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);

    await _shot(tester, _controller(isPro: true), 'tablet-home-pro');
    await _shot(tester, _controller(), 'tablet-home-free');
  });
}

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await File('$dir/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

ConversationController _controller({
  bool isPro = false,
  InterpreterMode mode = InterpreterMode.pushToTalk,
}) {
  final entitlements = Entitlements(
    storage: MemoryEntitlementStorage(),
    freeDailyVoiceMinutes: 5,
  );
  if (isPro) {
    unawaited(entitlements.upgradeToPro());
  }
  final controller = ConversationController(
    audioInputService: const _FakeAudioInputService(),
    speechRecognizer: const _FakeSpeechRecognizer(),
    translationEngine: const _FakeTranslationEngine(),
    ttsService: const _FakeTtsService(),
    vadService: const _FakeVadService(),
    modelInventory: ModelInventory.mvpDefaults(),
    entitlements: entitlements,
  );
  if (isPro) {
    controller.setSpeechModel(SpeechModelProfile.base);
  }
  if (mode != InterpreterMode.pushToTalk) {
    controller.setMode(mode);
  }
  return controller;
}

void _injectMessages(ConversationController controller) {
  controller.injectMessage(
    ConversationMessage(
      sourceLanguage: SupportedLanguage.english,
      targetLanguage: SupportedLanguage.vietnamese,
      transcript: 'How much does this cost?',
      translation: 'Cái này giá bao nhiêu?',
      createdAt: DateTime.now(),
      latency: const Duration(milliseconds: 640),
      spoken: false,
    ),
  );
  controller.injectMessage(
    ConversationMessage(
      sourceLanguage: SupportedLanguage.english,
      targetLanguage: SupportedLanguage.vietnamese,
      transcript: 'Hello, nice to meet you today.',
      translation: 'Xin chào, rất vui được gặp bạn hôm nay.',
      createdAt: DateTime.now(),
      latency: const Duration(milliseconds: 520),
      spoken: true,
    ),
  );
}

Future<void> _shot(
  WidgetTester tester,
  ConversationController controller,
  String name,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff0f766e),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7faf9),
        fontFamily: 'Roboto',
      ),
      home: ConversationScreen(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
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
    return language == SupportedLanguage.vietnamese
        ? 'Xin chào, rất vui được gặp bạn.'
        : 'Hello, nice to meet you today.';
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
    return from == SupportedLanguage.english
        ? 'Xin chào, rất vui được gặp bạn hôm nay.'
        : 'Hello, nice to meet you today.';
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