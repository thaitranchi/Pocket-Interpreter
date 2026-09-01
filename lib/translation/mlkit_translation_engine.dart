import 'package:flutter/widgets.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../conversation/language.dart';
import 'translation_engine.dart';

class MlKitTranslationEngine implements TranslationEngine {
  MlKitTranslationEngine({OnDeviceTranslatorModelManager? modelManager})
      : _modelManager =
            modelManager ?? OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _modelManager;

  final Map<_LanguagePair, OnDeviceTranslator> _translators = {};

  static TranslateLanguage _toTranslateLanguage(SupportedLanguage language) {
    return switch (language) {
      SupportedLanguage.english => TranslateLanguage.english,
      SupportedLanguage.vietnamese => TranslateLanguage.vietnamese,
    };
  }

  bool _isTestEnvironment() {
    if (const bool.fromEnvironment('ENABLE_REAL_ENGINES')) {
      return false;
    }
    try {
      final bindingStr = WidgetsBinding.instance.toString();
      if (bindingStr.contains('Test')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _ensureModelDownloaded(String bcpCode) async {
    final isDownloaded = await _modelManager.isModelDownloaded(bcpCode);
    if (!isDownloaded) {
      await _modelManager.downloadModel(bcpCode);
    }
  }

  @override
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async {
    if (_isTestEnvironment() || from == to) {
      return text;
    }

    final source = _toTranslateLanguage(from);
    final target = _toTranslateLanguage(to);
    final pair = _LanguagePair(from, to);

    await _ensureModelDownloaded(source.bcpCode);
    await _ensureModelDownloaded(target.bcpCode);

    final translator =
        _translators.putIfAbsent(
            pair,
            () => OnDeviceTranslator(
              sourceLanguage: source,
              targetLanguage: target,
            ));

    return translator.translateText(text);
  }
}

class _LanguagePair {
  const _LanguagePair(this.from, this.to);

  final SupportedLanguage from;
  final SupportedLanguage to;

  @override
  bool operator ==(Object other) {
    return other is _LanguagePair &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(from, to);
}