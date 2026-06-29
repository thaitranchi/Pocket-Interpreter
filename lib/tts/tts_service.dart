import '../conversation/language.dart';

abstract interface class TtsService {
  Future<void> speak(String text, {required SupportedLanguage language});
}
