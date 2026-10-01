import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_interpreter/conversation/conversation_settings.dart';
import 'package:pocket_interpreter/conversation/language.dart';
import 'package:pocket_interpreter/models/model_download_coordinator.dart';
import 'package:pocket_interpreter/models/model_inventory.dart';
import 'package:pocket_interpreter/models/offline_model.dart';
import 'package:pocket_interpreter/translation/translation_engine.dart';
import 'package:pocket_interpreter/whisper/speech_recognizer.dart';

void main() {
  // Regression: the shipped catalog hardcoded every model as "installed", so
  // the UI claimed an offline pack existed before anything was downloaded.
  test('a fresh inventory reports nothing as installed', () {
    final inventory = ModelInventory.pending();

    expect(inventory.isReady, isFalse);
    expect(inventory.missingCount, 2);
    expect(inventory.installedSizeMb, 0);
    expect(inventory.hasFailure, isFalse);
  });

  test('optional components do not block readiness', () {
    final inventory = ModelInventory.pending();

    expect(
      inventory.models
          .where((m) => m.status == OfflineModelStatus.optional)
          .length,
      2,
    );
    // VAD and TTS are optional, but the two downloadable models are not.
    expect(inventory.isReady, isFalse);
  });

  test('progress aggregates across the required models only', () {
    final inventory = ModelInventory.pending();

    expect(inventory.progress, 0);

    inventory.setStatus(
      ModelDownloadCoordinator.speechModelId,
      OfflineModelStatus.downloading,
    );
    inventory.setProgress(ModelDownloadCoordinator.speechModelId, 0.5);
    expect(inventory.progress, closeTo(0.25, 0.001));
    expect(inventory.isDownloading, isTrue);

    inventory.setStatus(
      ModelDownloadCoordinator.speechModelId,
      OfflineModelStatus.installed,
    );
    inventory.setStatus(
      ModelDownloadCoordinator.translationModelId,
      OfflineModelStatus.installed,
    );

    expect(inventory.progress, 1);
    expect(inventory.isReady, isTrue);
    expect(inventory.installedSizeMb, 238);
  });

  test('a failed download is surfaced and can be retried', () {
    final inventory = ModelInventory.pending();

    inventory.setStatus(
      ModelDownloadCoordinator.speechModelId,
      OfflineModelStatus.failed,
    );

    expect(inventory.hasFailure, isTrue);
    expect(inventory.isReady, isFalse);

    // Retrying puts it back into the downloading state so the failure clears.
    inventory.setStatus(
      ModelDownloadCoordinator.speechModelId,
      OfflineModelStatus.downloading,
    );
    expect(inventory.hasFailure, isFalse);
    // Only the translation model is still outstanding.
    expect(inventory.missingCount, 1);
  });

  test('progress is ignored unless the model is downloading', () {
    final inventory = ModelInventory.pending();

    inventory.setProgress(ModelDownloadCoordinator.speechModelId, 0.5);

    expect(inventory.progress, 0);
  });

  // Regression: a failed model used to keep contributing its last progress
  // value, so the aggregate bar stalled at a fraction that would never move.
  test('a failed model does not contribute stale progress', () {
    final inventory = ModelInventory.pending();

    inventory.setStatus(
      ModelDownloadCoordinator.speechModelId,
      OfflineModelStatus.downloading,
    );
    inventory.setProgress(ModelDownloadCoordinator.speechModelId, 0.6);
    expect(inventory.progress, closeTo(0.3, 0.001));

    inventory.setStatus(
      ModelDownloadCoordinator.speechModelId,
      OfflineModelStatus.failed,
    );

    expect(inventory.progress, 0);
  });

  test('prepare marks models installed and reports progress', () async {
    final inventory = ModelInventory.pending();
    final speech = _FakeSpeechRecognizer();
    final translation = _FakeTranslationEngine();
    final coordinator = ModelDownloadCoordinator(
      inventory: inventory,
      speechRecognizer: speech,
      translationEngine: translation,
    );

    expect(coordinator.isSupported, isTrue);

    final ok = await coordinator.prepare(
      profile: SpeechModelProfile.tiny,
      from: SupportedLanguage.english,
      to: SupportedLanguage.vietnamese,
    );

    expect(ok, isTrue);
    expect(inventory.isReady, isTrue);
    expect(speech.preparedProfiles, [SpeechModelProfile.tiny]);
    expect(
      translation.preparedPairs,
      [(SupportedLanguage.english, SupportedLanguage.vietnamese)],
    );
  });

  test('prepare reports failure instead of throwing', () async {
    final inventory = ModelInventory.pending();
    final coordinator = ModelDownloadCoordinator(
      inventory: inventory,
      speechRecognizer: _FailingSpeechRecognizer(),
      translationEngine: _FakeTranslationEngine(),
    );

    final ok = await coordinator.prepare(
      profile: SpeechModelProfile.tiny,
      from: SupportedLanguage.english,
      to: SupportedLanguage.vietnamese,
    );

    expect(ok, isFalse);
    expect(inventory.hasFailure, isTrue);
    expect(inventory.isReady, isFalse);
  });

  test('prepare is a no-op for engines that cannot download', () async {
    final inventory = ModelInventory.pending();
    final coordinator = ModelDownloadCoordinator(
      inventory: inventory,
      speechRecognizer: _PlainSpeechRecognizer(),
      translationEngine: _PlainTranslationEngine(),
    );

    expect(coordinator.isSupported, isFalse);
    final ok = await coordinator.prepare(
      profile: SpeechModelProfile.tiny,
      from: SupportedLanguage.english,
      to: SupportedLanguage.vietnamese,
    );

    expect(ok, isTrue);
    // Inventory is left exactly as it was.
    expect(inventory.isReady, isFalse);
    expect(inventory.hasFailure, isFalse);
  });
}

class _FakeSpeechRecognizer
    implements SpeechRecognizer, SpeechModelPreparer {
  final List<SpeechModelProfile> preparedProfiles = [];

  @override
  Future<void> prepareSpeechModel(
    SpeechModelProfile profile, {
    void Function(double progress)? onProgress,
  }) async {
    preparedProfiles.add(profile);
    onProgress?.call(0.5);
    onProgress?.call(1);
  }

  @override
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  }) async => '';
}

class _FailingSpeechRecognizer
    implements SpeechRecognizer, SpeechModelPreparer {
  @override
  Future<void> prepareSpeechModel(
    SpeechModelProfile profile, {
    void Function(double progress)? onProgress,
  }) async {
    throw StateError('no network');
  }

  @override
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  }) async => '';
}

class _PlainSpeechRecognizer implements SpeechRecognizer {
  @override
  Future<String> transcribe({
    required List<int> audioData,
    required SupportedLanguage language,
    required SpeechModelProfile model,
  }) async => '';
}

class _FakeTranslationEngine
    implements TranslationEngine, TranslationModelPreparer {
  final List<(SupportedLanguage, SupportedLanguage)> preparedPairs = [];

  @override
  Future<void> prepareTranslationModels(
    SupportedLanguage from,
    SupportedLanguage to, {
    void Function(double progress)? onProgress,
  }) async {
    preparedPairs.add((from, to));
    onProgress?.call(1);
  }

  @override
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async => text;
}

class _PlainTranslationEngine implements TranslationEngine {
  @override
  Future<String> translate(
    String text, {
    required SupportedLanguage from,
    required SupportedLanguage to,
  }) async => text;
}
