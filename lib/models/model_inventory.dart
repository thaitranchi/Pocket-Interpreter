import 'package:flutter/foundation.dart';

import 'offline_model.dart';

/// Tracks whether the offline models the app depends on are actually on the
/// device.
///
/// Production code must start from [ModelInventory.pending] so the UI reflects
/// reality: nothing is downloaded until [ModelDownloadCoordinator] reports it.
class ModelInventory extends ChangeNotifier {
  ModelInventory({required List<OfflineModel> models})
    : _models = List<OfflineModel>.of(models);

  /// Every required model present. Used by tests and previews that inject
  /// fake engines, where no real download is possible.
  factory ModelInventory.mvpDefaults() {
    return ModelInventory(
      models: [
        const OfflineModel(
          id: 'whisper',
          name: 'Whisper speech',
          type: OfflineModelType.speech,
          sizeMb: 142,
          status: OfflineModelStatus.installed,
        ),
        const OfflineModel(
          id: 'mlkit-en-vi',
          name: 'ML Kit translation',
          type: OfflineModelType.translation,
          sizeMb: 96,
          status: OfflineModelStatus.installed,
        ),
        const OfflineModel(
          id: 'energy-vad',
          name: 'Built-in voice activity detection',
          type: OfflineModelType.vad,
          sizeMb: 0,
          status: OfflineModelStatus.optional,
        ),
        const OfflineModel(
          id: 'native-tts',
          name: 'Native platform TTS',
          type: OfflineModelType.tts,
          sizeMb: 0,
          status: OfflineModelStatus.optional,
        ),
      ],
    );
  }

  /// Nothing downloaded yet. The honest starting state for a real device.
  factory ModelInventory.pending() {
    return ModelInventory(
      models: [
        const OfflineModel(
          id: 'whisper',
          name: 'Whisper speech',
          type: OfflineModelType.speech,
          sizeMb: 142,
          status: OfflineModelStatus.missing,
        ),
        const OfflineModel(
          id: 'mlkit-en-vi',
          name: 'ML Kit translation',
          type: OfflineModelType.translation,
          sizeMb: 96,
          status: OfflineModelStatus.missing,
        ),
        const OfflineModel(
          id: 'energy-vad',
          name: 'Built-in voice activity detection',
          type: OfflineModelType.vad,
          sizeMb: 0,
          status: OfflineModelStatus.optional,
        ),
        const OfflineModel(
          id: 'native-tts',
          name: 'Native platform TTS',
          type: OfflineModelType.tts,
          sizeMb: 0,
          status: OfflineModelStatus.optional,
        ),
      ],
    );
  }

  final List<OfflineModel> _models;

  List<OfflineModel> get models => List.unmodifiable(_models);

  bool get isReady => _models.every((model) => model.isReady);

  bool get isDownloading => _models.any((model) => model.isBusy);

  bool get hasFailure => _models.any(
    (model) => model.status == OfflineModelStatus.failed,
  );

  /// Aggregate 0..1 download progress across the non-optional models.
  double get progress {
    final required = _models.where(
      (model) => model.status != OfflineModelStatus.optional,
    );
    if (required.isEmpty) {
      return 1;
    }
    final total = required.fold<double>(0, (sum, model) {
      if (model.status == OfflineModelStatus.installed) {
        return sum + 1;
      }
      if (model.status == OfflineModelStatus.missing) {
        return sum;
      }
      if (model.status == OfflineModelStatus.failed) {
        return sum;
      }
      return sum + model.progress.clamp(0.0, 1.0);
    });
    return total / required.length;
  }

  int get installedSizeMb {
    return _models
        .where((model) => model.status == OfflineModelStatus.installed)
        .fold(0, (total, model) => total + model.sizeMb);
  }

  int get missingCount {
    return _models
        .where(
          (model) =>
              model.status == OfflineModelStatus.missing ||
              model.status == OfflineModelStatus.failed,
        )
        .length;
  }

  void setStatus(String id, OfflineModelStatus status, {double progress = 0}) {
    final index = _models.indexWhere((model) => model.id == id);
    if (index == -1) {
      return;
    }
    final updated = _models[index].copyWith(
      status: status,
      progress: status == OfflineModelStatus.installed ? 1 : progress,
    );
    if (updated.status == _models[index].status &&
        updated.progress == _models[index].progress) {
      return;
    }
    _models[index] = updated;
    notifyListeners();
  }

  void setProgress(String id, double progress) {
    final index = _models.indexWhere((model) => model.id == id);
    if (index == -1) {
      return;
    }
    if (_models[index].status != OfflineModelStatus.downloading) {
      return;
    }
    _models[index] = _models[index].copyWith(progress: progress.clamp(0.0, 1.0));
    notifyListeners();
  }
}
