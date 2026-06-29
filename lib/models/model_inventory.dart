import 'offline_model.dart';

class ModelInventory {
  const ModelInventory({required List<OfflineModel> models}) : _models = models;

  factory ModelInventory.mvpDefaults() {
    return const ModelInventory(
      models: [
        OfflineModel(
          id: 'whisper-base',
          name: 'Whisper base',
          type: OfflineModelType.speech,
          sizeMb: 142,
          status: OfflineModelStatus.installed,
        ),
        OfflineModel(
          id: 'argos-en-vi',
          name: 'Argos EN-VI',
          type: OfflineModelType.translation,
          sizeMb: 96,
          status: OfflineModelStatus.installed,
        ),
        OfflineModel(
          id: 'silero-vad',
          name: 'Silero VAD',
          type: OfflineModelType.vad,
          sizeMb: 3,
          status: OfflineModelStatus.installed,
        ),
        OfflineModel(
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

  int get installedSizeMb {
    return _models
        .where((model) => model.status == OfflineModelStatus.installed)
        .fold(0, (total, model) => total + model.sizeMb);
  }

  int get missingCount {
    return _models
        .where((model) => model.status == OfflineModelStatus.missing)
        .length;
  }
}
