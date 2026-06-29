import '../conversation/language.dart';
import '../conversation/conversation_settings.dart';

abstract interface class SpeechRecognizer {
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  });
}
