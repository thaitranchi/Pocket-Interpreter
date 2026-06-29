import '../conversation/language.dart';
import 'translation_engine.dart';

class MockTranslationEngine implements TranslationEngine {
  const MockTranslationEngine();

  @override
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (from == SupportedLanguage.english &&
        to == SupportedLanguage.vietnamese) {
      return 'Xin chao, ban co the giup toi tim nha ga khong?';
    }

    if (from == SupportedLanguage.vietnamese &&
        to == SupportedLanguage.english) {
      return 'Hello, can you help me?';
    }

    return text;
  }
}
