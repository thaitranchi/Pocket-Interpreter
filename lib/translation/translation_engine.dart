import '../conversation/language.dart';

abstract interface class TranslationEngine {
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  });
}
