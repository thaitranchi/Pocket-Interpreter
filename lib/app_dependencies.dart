import 'package:flutter/foundation.dart';

import 'audio/audio_input_service.dart';
import 'models/model_inventory.dart';
import 'tts/tts_service.dart';
import 'translation/translation_engine.dart';
import 'vad/vad_service.dart';
import 'whisper/speech_recognizer.dart';

/// Injectable collaborators for [PocketInterpreterApp].
///
/// Production passes nothing and gets the real on-device engines. Tests inject
/// fakes explicitly, which is why the app no longer has to guess whether it is
/// running inside a test harness.
@immutable
class AppDependencies {
  const AppDependencies({
    this.audioInputService,
    this.speechRecognizer,
    this.translationEngine,
    this.ttsService,
    this.vadService,
    this.modelInventory,
  });

  final AudioInputService? audioInputService;
  final SpeechRecognizer? speechRecognizer;
  final TranslationEngine? translationEngine;
  final TtsService? ttsService;
  final VadService? vadService;
  final ModelInventory? modelInventory;
}
