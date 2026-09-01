import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pocket_interpreter/conversation/conversation_settings.dart';
import 'package:pocket_interpreter/conversation/language.dart';
import 'package:pocket_interpreter/translation/mlkit_translation_engine.dart';
import 'package:pocket_interpreter/whisper/whisper_speech_recognizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'whisper model downloads and transcribes on device',
    (tester) async {
      final recognizer = WhisperSpeechRecognizer();

      final result = await recognizer.transcribe(
        audioData: List<int>.filled(16000, 0),
        language: SupportedLanguage.english,
        model: SpeechModelProfile.tiny,
      );

      expect(result, isNotNull);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  testWidgets(
    'ml kit translation models download and translate on device',
    (tester) async {
      final engine = MlKitTranslationEngine();

      final result = await engine.translate(
        'Hello, can you help me find the station?',
        from: SupportedLanguage.english,
        to: SupportedLanguage.vietnamese,
      );

      expect(result, isNotNull);
      expect(result, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}