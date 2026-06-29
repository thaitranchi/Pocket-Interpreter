import 'language.dart';

class ConversationMessage {
  const ConversationMessage({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.transcript,
    required this.translation,
    required this.createdAt,
    required this.latency,
    required this.spoken,
  });

  final SupportedLanguage sourceLanguage;
  final SupportedLanguage targetLanguage;
  final String transcript;
  final String translation;
  final DateTime createdAt;
  final Duration latency;
  final bool spoken;
}
