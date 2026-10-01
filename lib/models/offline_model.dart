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
  downloading('Downloading'),
  missing('Missing'),
  failed('Download failed'),
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
    this.progress = 0,
  });

  final String id;
  final String name;
  final OfflineModelType type;
  final int sizeMb;
  final OfflineModelStatus status;

  /// 0..1 while [status] is [OfflineModelStatus.downloading].
  final double progress;

  bool get isReady {
    return status == OfflineModelStatus.installed ||
        status == OfflineModelStatus.optional;
  }

  bool get isBusy => status == OfflineModelStatus.downloading;

  OfflineModel copyWith({
    OfflineModelStatus? status,
    double? progress,
  }) {
    return OfflineModel(
      id: id,
      name: name,
      type: type,
      sizeMb: sizeMb,
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }
}
