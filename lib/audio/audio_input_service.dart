abstract interface class AudioInputService {
  Stream<List<int>> openMicrophoneStream();
  Future<void> close();
}
