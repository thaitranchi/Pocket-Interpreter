import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_interpreter/audio/audio_buffer.dart';

void main() {
  group('AudioBuffer', () {
    test('starts empty', () {
      final buffer = AudioBuffer();
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, equals(0));
    });

    test('accumulates chunks', () {
      final buffer = AudioBuffer();
      buffer.add([1, 2, 3]);
      expect(buffer.isEmpty, isFalse);
      expect(buffer.length, equals(3));
      buffer.add([4, 5, 6]);
      expect(buffer.length, equals(6));
    });

    test('toList returns a copy of the accumulated data', () {
      final buffer = AudioBuffer();
      buffer.add([1, 2, 3]);
      final list = buffer.toList();
      expect(list, equals([1, 2, 3]));
      list.add(4);
      expect(buffer.length, equals(3));
    });

    test('clear resets the buffer', () {
      final buffer = AudioBuffer();
      buffer.add([1, 2, 3]);
      buffer.clear();
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, equals(0));
    });

    test('accumulates multiple chunks in order', () {
      final buffer = AudioBuffer();
      buffer.add([1, 2]);
      buffer.add([3, 4]);
      buffer.add([5, 6]);
      expect(buffer.toList(), equals([1, 2, 3, 4, 5, 6]));
    });
  });
}
