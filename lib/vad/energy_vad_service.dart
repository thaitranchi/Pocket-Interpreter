import 'dart:math';
import 'vad_service.dart';

class EnergyVadService implements VadService {
  const EnergyVadService({
    this.threshold = 500.0,
    this.minChunkBytes = 320,
  });

  final double threshold;
  final int minChunkBytes;

  @override
  Future<bool> detectSpeech(List<int> audioChunk) async {
    if (audioChunk.length < minChunkBytes) return false;

    int sampleCount = audioChunk.length ~/ 2;
    double sumSquares = 0;

    for (int i = 0; i < audioChunk.length - 1; i += 2) {
      int sample = audioChunk[i] | (audioChunk[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      sumSquares += sample * sample;
    }

    double rms = sqrt(sumSquares / sampleCount);
    return rms > threshold;
  }
}
