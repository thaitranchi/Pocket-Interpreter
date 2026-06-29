import 'package:flutter/material.dart';

import 'audio/record_audio_input_service.dart';
import 'conversation/conversation_controller.dart';
import 'models/model_inventory.dart';
import 'release/app_release.dart';
import 'translation/mock_translation_engine.dart';
import 'tts/native_tts_service.dart';
import 'ui/conversation_screen.dart';
import 'vad/energy_vad_service.dart';
import 'whisper/mock_speech_recognizer.dart';

class PocketInterpreterApp extends StatelessWidget {
  const PocketInterpreterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ConversationController(
      audioInputService: RecordAudioInputService(),
      speechRecognizer: const MockSpeechRecognizer(),
      translationEngine: const MockTranslationEngine(),
      ttsService: const NativeTtsService(),
      vadService: const EnergyVadService(),
      modelInventory: ModelInventory.mvpDefaults(),
    );

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
      home: ConversationScreen(controller: controller),
    );
  }
}
