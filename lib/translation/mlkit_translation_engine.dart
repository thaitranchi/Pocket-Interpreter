import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../conversation/language.dart';
import '../models/model_download_coordinator.dart';
import 'translation_engine.dart';

class MlKitTranslationEngine
    implements TranslationEngine, TranslationModelPreparer {
  MlKitTranslationEngine({OnDeviceTranslatorModelManager? modelManager})
    : _modelManager = modelManager ?? OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _modelManager;

  final Map<_LanguagePair, OnDeviceTranslator> _translators = {};

  static TranslateLanguage _toTranslateLanguage(SupportedLanguage language) {
    return switch (language) {
      SupportedLanguage.english => TranslateLanguage.english,
      SupportedLanguage.vietnamese => TranslateLanguage.vietnamese,
    };
  }

  Future<void> _ensureModelDownloaded(
    String bcpCode, {
    void Function(double progress)? onProgress,
  }) async {
    if (await _modelManager.isModelDownloaded(bcpCode)) {
      onProgress?.call(1);
      return;
    }
    await _modelManager.downloadModel(bcpCode);
    onProgress?.call(1);
  }

  @override
  Future<void> prepareTranslationModels(
    SupportedLanguage from,
    SupportedLanguage to, {
    void Function(double progress)? onProgress,
  }) async {
    final codes = <String>{
      _toTranslateLanguage(from).bcpCode,
      _toTranslateLanguage(to).bcpCode,
    }.toList();

    for (var i = 0; i < codes.length; i++) {
      await _ensureModelDownloaded(
        codes[i],
        onProgress: (value) => onProgress?.call((i + value) / codes.length),
      );
    }
  }

  @override
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async {
    if (text.trim().isEmpty || from == to) {
      return text;
    }

    final source = _toTranslateLanguage(from);
    final target = _toTranslateLanguage(to);
    final pair = _LanguagePair(from, to);

    await _ensureModelDownloaded(source.bcpCode);
    await _ensureModelDownloaded(target.bcpCode);

    final translator = _translators.putIfAbsent(
      pair,
      () => OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      ),
    );

    return translator.translateText(text);
  }

  /// Releases the native translators. Required to avoid leaking native
  /// handles across long-running sessions.
  Future<void> dispose() async {
    final translators = _translators.values.toList();
    _translators.clear();
    for (final translator in translators) {
      try {
        await translator.close();
      } catch (_) {}
    }
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
