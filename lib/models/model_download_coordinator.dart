import '../conversation/conversation_settings.dart';
import '../conversation/language.dart';
import '../translation/translation_engine.dart';
import '../whisper/speech_recognizer.dart';
import 'model_inventory.dart';
import 'offline_model.dart';

/// Implemented by speech engines that can fetch their own weights ahead of use.
///
/// Kept separate from [SpeechRecognizer] so fakes used in tests do not have to
/// pretend they can download anything.
abstract interface class SpeechModelPreparer {
  /// Ensures the weights for [profile] are on the device, reporting 0..1
  /// progress. Completes without network access when already present.
  Future<void> prepareSpeechModel(
    SpeechModelProfile profile, {
    void Function(double progress)? onProgress,
  });
}

/// Implemented by translation engines that can fetch their own models.
abstract interface class TranslationModelPreparer {
  /// Ensures the models for [from] and [to] are on the device.
  Future<void> prepareTranslationModels(
    SupportedLanguage from,
    SupportedLanguage to, {
    void Function(double progress)? onProgress,
  });
}

/// Downloads the models the current session needs, keeping [ModelInventory]
/// in sync so the UI never claims a model is ready before it is.
class ModelDownloadCoordinator {
  ModelDownloadCoordinator({
    required ModelInventory inventory,
    required SpeechRecognizer speechRecognizer,
    required TranslationEngine translationEngine,
  }) : _inventory = inventory,
       _speechRecognizer = speechRecognizer,
       _translationEngine = translationEngine;

  static const String speechModelId = 'whisper';
  static const String translationModelId = 'mlkit-en-vi';

  final ModelInventory _inventory;
  final SpeechRecognizer _speechRecognizer;
  final TranslationEngine _translationEngine;

  /// Whether real preparation is possible. False for test doubles, in which
  /// case [prepare] is a no-op and the inventory is left untouched.
  bool get isSupported =>
      _speechRecognizer is SpeechModelPreparer &&
      _translationEngine is TranslationModelPreparer;

  /// Prepares the speech and translation models, reporting failures through
  /// [ModelInventory.hasFailure] rather than throwing.
  Future<bool> prepare({
    required SpeechModelProfile profile,
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async {
    final speech = _speechRecognizer;
    final translation = _translationEngine;
    if (speech is! SpeechModelPreparer) {
      return true;
    }
    if (translation is! TranslationModelPreparer) {
      return true;
    }
    final speechPreparer = speech as SpeechModelPreparer;
    final translationPreparer = translation as TranslationModelPreparer;

    var succeeded = true;

    _inventory.setStatus(speechModelId, OfflineModelStatus.downloading);
    try {
      await speechPreparer.prepareSpeechModel(
        profile,
        onProgress: (value) => _inventory.setProgress(speechModelId, value),
      );
      _inventory.setStatus(speechModelId, OfflineModelStatus.installed);
    } catch (_) {
      _inventory.setStatus(speechModelId, OfflineModelStatus.failed);
      succeeded = false;
    }

    _inventory.setStatus(translationModelId, OfflineModelStatus.downloading);
    try {
      await translationPreparer.prepareTranslationModels(
        from,
        to,
        onProgress: (value) =>
            _inventory.setProgress(translationModelId, value),
      );
      _inventory.setStatus(translationModelId, OfflineModelStatus.installed);
    } catch (_) {
      _inventory.setStatus(translationModelId, OfflineModelStatus.failed);
      succeeded = false;
    }

    return succeeded;
  }
}
