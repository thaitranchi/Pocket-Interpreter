import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_interpreter/vad/energy_vad_service.dart';

void main() {
  group('EnergyVadService', () {
    test('detects silence for zero audio', () async {
      final vad = EnergyVadService(threshold: 500);
      final silence = List.filled(320, 0);
      expect(await vad.detectSpeech(silence), isFalse);
    });

    test('rejects chunks smaller than minChunkBytes', () async {
      final vad = EnergyVadService(threshold: 500, minChunkBytes: 320);
      final small = List.filled(100, 255);
      expect(await vad.detectSpeech(small), isFalse);
    });

    test('detects speech for high-energy audio', () async {
      final vad = EnergyVadService(threshold: 500);
      final samples = List<int>.generate(
        320,
        (i) => (sin(i * 0.5) * 127 + 128).round().clamp(0, 255),
      );
      expect(await vad.detectSpeech(samples), isTrue);
    });

    test('detects constant mid-level audio above threshold', () async {
      final vad = EnergyVadService(threshold: 500);
      final constant = List.filled(320, 64);
      expect(await vad.detectSpeech(constant), isTrue);
    });

    test('respects custom threshold', () async {
      final lowThreshold = EnergyVadService(threshold: 100);
      final highThreshold = EnergyVadService(threshold: 50000);
      final samples = List.filled(320, 64);
      expect(await lowThreshold.detectSpeech(samples), isTrue);
      expect(await highThreshold.detectSpeech(samples), isFalse);
    });

    test('handles single sine wave period', () async {
      final vad = EnergyVadService(threshold: 500);
      final samples = List<int>.generate(
        320,
        (i) => (sin(i * 2 * pi / 160) * 100 + 128).round().clamp(0, 255),
      );
      expect(await vad.detectSpeech(samples), isTrue);
    });
  });
}
