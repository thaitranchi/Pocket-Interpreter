import '../conversation/conversation_message.dart';

abstract interface class StreamingSession {
  Stream<ConversationMessage> start();
  Future<void> stop();
}
