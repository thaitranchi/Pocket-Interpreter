abstract interface class VadService {
  Future<bool> detectSpeech(List<int> audioChunk);
}
