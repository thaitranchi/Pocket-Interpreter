enum OfflineModelType {
  speech('Speech recognition'),
  translation('Translation'),
  vad('Voice activity'),
  tts('Text to speech');

  const OfflineModelType(this.label);

  final String label;
}

enum OfflineModelStatus {
  installed('Installed'),
  missing('Missing'),
  optional('Optional');

  const OfflineModelStatus(this.label);

  final String label;
}

class OfflineModel {
  const OfflineModel({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeMb,
    required this.status,
  });

  final String id;
  final String name;
  final OfflineModelType type;
  final int sizeMb;
  final OfflineModelStatus status;

  bool get isReady {
    return status == OfflineModelStatus.installed ||
        status == OfflineModelStatus.optional;
  }
}
