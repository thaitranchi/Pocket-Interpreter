import 'dart:async';

import 'package:record/record.dart';

import 'audio_input_service.dart';

/// PCM16 mono at 16 kHz. The Whisper front-end and [EnergyVadService] both
/// assume this format, so the recorder must be configured to match.
const int kCaptureSampleRate = 16000;
const int kCaptureBytesPerSample = 2;

class MicrophonePermissionDenied implements Exception {
  const MicrophonePermissionDenied();

  @override
  String toString() => 'Microphone permission denied';
}

/// Records from the device microphone via `record`.
///
/// The service is reusable: every [openMicrophoneStream] call creates a fresh
/// [AudioRecorder] and [close] releases it, leaving the service ready for the
/// next recording. Callers are responsible for calling [close].
class RecordAudioInputService implements AudioInputService {
  AudioRecorder? _recorder;
  StreamController<List<int>>? _controller;
  StreamSubscription<List<int>>? _subscription;

  @override
  Stream<List<int>> openMicrophoneStream() {
    if (_controller != null) {
      throw StateError('A microphone stream is already open');
    }

    final controller = StreamController<List<int>>();
    _controller = controller;
    unawaited(_start(controller));
    return controller.stream;
  }

  Future<void> _start(StreamController<List<int>> controller) async {
    AudioRecorder? recorder;
    try {
      recorder = AudioRecorder();
      if (!await recorder.hasPermission()) {
        throw const MicrophonePermissionDenied();
      }

      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: kCaptureSampleRate,
          numChannels: 1,
        ),
      );

      if (controller.isClosed) {
        await recorder.dispose();
        return;
      }

      _recorder = recorder;
      _subscription = stream.listen(
        controller.add,
        onError: controller.addError,
      );
    } catch (error, stack) {
      await recorder?.dispose();
      if (!controller.isClosed) {
        controller.addError(error, stack);
        await controller.close();
      }
      if (identical(_controller, controller)) {
        _controller = null;
      }
    }
  }

  /// Stops the active recording and releases the recorder so that the service
  /// can be opened again.
  @override
  Future<void> close() async {
    final controller = _controller;
    final subscription = _subscription;
    final recorder = _recorder;

    _controller = null;
    _subscription = null;
    _recorder = null;

    await subscription?.cancel();

    if (recorder != null) {
      try {
        if (await recorder.isRecording()) {
          await recorder.stop();
        }
      } catch (_) {}
      await recorder.dispose();
    }

    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}
