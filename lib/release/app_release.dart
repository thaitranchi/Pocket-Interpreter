class AppRelease {
  const AppRelease._();

  static const String name = 'Pocket Interpreter';
  static const String version = '1.0.0';

  /// Must match the build number in pubspec.yaml.
  static const int buildNumber = 3;
  static const String channel = 'MVP';
  static const String summary =
      'Offline-first EN-VI conversation interpreter. Speech recognition runs '
      'on-device via whisper.cpp, translation via ML Kit on-device models.';
}
