import '../conversation/language.dart';
import '../conversation/conversation_settings.dart';
import 'speech_recognizer.dart';

class MockSpeechRecognizer implements SpeechRecognizer {
  const MockSpeechRecognizer();

  @override
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  }) async {
    final delay = switch (model) {
      SpeechModelProfile.tiny => const Duration(milliseconds: 250),
      SpeechModelProfile.base => const Duration(milliseconds: 450),
      SpeechModelProfile.smallInt8 => const Duration(milliseconds: 700),
    };
    await Future.delayed(delay);
    return switch (language) {
      SupportedLanguage.english => 'Hello, can you help me find the station?',
      SupportedLanguage.vietnamese => 'Xin chao, ban co the giup toi khong?',
    };
  }
}
