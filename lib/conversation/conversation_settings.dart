import 'language.dart';

enum InterpreterMode {
  conversation('Conversation'),
  subtitles('Subtitles'),
  pushToTalk('Push-to-talk');

  const InterpreterMode(this.label);

  final String label;
}

enum SpeechModelProfile {
  tiny('tiny', 'Fastest'),
  base('base', 'Balanced'),
  smallInt8('small-int8', 'Better quality');

  const SpeechModelProfile(this.label, this.description);

  final String label;
  final String description;
}

class ConversationSettings {
  const ConversationSettings({
    this.sourceLanguage = SupportedLanguage.english,
    this.targetLanguage = SupportedLanguage.vietnamese,
    this.mode = InterpreterMode.pushToTalk,
    this.speechModel = SpeechModelProfile.base,
    this.voicePlaybackEnabled = true,
  });

  final SupportedLanguage sourceLanguage;
  final SupportedLanguage targetLanguage;
  final InterpreterMode mode;
  final SpeechModelProfile speechModel;
  final bool voicePlaybackEnabled;

  ConversationSettings copyWith({
    SupportedLanguage? sourceLanguage,
    SupportedLanguage? targetLanguage,
    InterpreterMode? mode,
    SpeechModelProfile? speechModel,
    bool? voicePlaybackEnabled,
  }) {
    return ConversationSettings(
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      mode: mode ?? this.mode,
      speechModel: speechModel ?? this.speechModel,
      voicePlaybackEnabled: voicePlaybackEnabled ?? this.voicePlaybackEnabled,
    );
  }

  ConversationSettings reversed() {
    return copyWith(
      sourceLanguage: targetLanguage,
      targetLanguage: sourceLanguage,
    );
  }
}
