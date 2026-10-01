import 'dart:async';

import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'audio/record_audio_input_service.dart';
import 'conversation/conversation_controller.dart';
import 'models/model_download_coordinator.dart';
import 'models/model_inventory.dart';
import 'release/app_release.dart';
import 'translation/mlkit_translation_engine.dart';
import 'tts/native_tts_service.dart';
import 'ui/conversation_screen.dart';
import 'vad/energy_vad_service.dart';
import 'whisper/whisper_speech_recognizer.dart';

class PocketInterpreterApp extends StatefulWidget {
  const PocketInterpreterApp({super.key, this.dependencies});

  final AppDependencies? dependencies;

  @override
  State<PocketInterpreterApp> createState() => _PocketInterpreterAppState();
}

class _PocketInterpreterAppState extends State<PocketInterpreterApp> {
  late final ModelInventory _modelInventory;
  late final RecordAudioInputService? _ownedAudioInputService;
  late final WhisperSpeechRecognizer? _ownedSpeechRecognizer;
  late final MlKitTranslationEngine? _ownedTranslationEngine;
  late final ConversationController _controller;
  ModelDownloadCoordinator? _modelCoordinator;

  @override
  void initState() {
    super.initState();
    final dependencies = widget.dependencies;

    _modelInventory = dependencies?.modelInventory ?? ModelInventory.pending();

    _ownedAudioInputService =
        dependencies?.audioInputService == null ? RecordAudioInputService() : null;
    _ownedSpeechRecognizer = dependencies?.speechRecognizer == null
        ? WhisperSpeechRecognizer()
        : null;
    _ownedTranslationEngine = dependencies?.translationEngine == null
        ? MlKitTranslationEngine()
        : null;

    _controller = ConversationController(
      audioInputService:
          dependencies?.audioInputService ?? _ownedAudioInputService!,
      speechRecognizer:
          dependencies?.speechRecognizer ?? _ownedSpeechRecognizer!,
      translationEngine:
          dependencies?.translationEngine ?? _ownedTranslationEngine!,
      ttsService: dependencies?.ttsService ?? NativeTtsService(),
      vadService: dependencies?.vadService ?? const EnergyVadService(),
      modelInventory: _modelInventory,
    );

    if (_ownedSpeechRecognizer != null && _ownedTranslationEngine != null) {
      _modelCoordinator = ModelDownloadCoordinator(
        inventory: _modelInventory,
        speechRecognizer: _ownedSpeechRecognizer,
        translationEngine: _ownedTranslationEngine,
      );
    }
  }

  /// Downloads whatever the current settings need. Safe to call repeatedly;
  /// already-present models are skipped.
  Future<void> ensureModelsReady() async {
    final coordinator = _modelCoordinator;
    if (coordinator == null) {
      return;
    }
    final settings = _controller.settings;
    await coordinator.prepare(
      profile: settings.speechModel,
      from: settings.sourceLanguage,
      to: settings.targetLanguage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.dependencies?.modelInventory == null) {
      _modelInventory.dispose();
    }
    unawaited(_ownedAudioInputService?.close());
    unawaited(_ownedSpeechRecognizer?.dispose());
    unawaited(_ownedTranslationEngine?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppRelease.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff0f766e),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7faf9),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2dd4bf),
          brightness: Brightness.dark,
        ),
      ),
      home: ConversationScreen(
        controller: _controller,
        ensureModelsReady: ensureModelsReady,
      ),
    );
  }
}
