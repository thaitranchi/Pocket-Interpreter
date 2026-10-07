import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_buffer.dart';
import '../audio/audio_input_service.dart';
import '../conversation/conversation_message.dart';
import '../conversation/conversation_settings.dart';
import '../translation/translation_engine.dart';
import '../tts/tts_service.dart';
import '../vad/vad_service.dart';
import '../whisper/speech_recognizer.dart';
import 'streaming_session.dart';

class ContinuousStreamingSession implements StreamingSession {
  ContinuousStreamingSession({
    required AudioInputService audioInputService,
    required SpeechRecognizer speechRecognizer,
    required TranslationEngine translationEngine,
    required TtsService ttsService,
    required VadService vadService,
    required ConversationSettings settings,
    required ValueChanged<String> onStatusChanged,
    required ValueChanged<bool> onBusyChanged,
    required ValueChanged<String> onPhaseChanged,
  }) : _audioInputService = audioInputService,
       _speechRecognizer = speechRecognizer,
       _translationEngine = translationEngine,
       _ttsService = ttsService,
       _vadService = vadService,
       _settings = settings,
       _onStatusChanged = onStatusChanged,
       _onBusyChanged = onBusyChanged,
       _onPhaseChanged = onPhaseChanged;

  /// Hard cap on one buffered utterance (~30s at 16 kHz PCM16) so a long
  /// stretch of continuous speech cannot exhaust memory.
  static const int maxBufferBytes = 16000 * 2 * 30;

  /// Silence after the last detected speech chunk that closes an utterance.
  static const Duration trailingSilence = Duration(milliseconds: 600);

  /// How long to discard mic audio after finishing an utterance so TTS playback
  /// and decode backlog are not treated as the next phrase.
  static const Duration postUtteranceFlush = Duration(milliseconds: 350);

  final AudioInputService _audioInputService;
  final SpeechRecognizer _speechRecognizer;
  final TranslationEngine _translationEngine;
  final TtsService _ttsService;
  final VadService _vadService;
  final ConversationSettings _settings;

  final ValueChanged<String> _onStatusChanged;
  final ValueChanged<bool> _onBusyChanged;
  final ValueChanged<String> _onPhaseChanged;

  StreamController<ConversationMessage> _messageController =
      StreamController<ConversationMessage>();

  bool _isActive = false;
  bool _isStopping = false;

  @override
  Stream<ConversationMessage> start() {
    if (_isActive) {
      return _messageController.stream;
    }

    // A previous run closes the controller to signal completion. Recreate it so
    // the session can be started again.
    if (_messageController.isClosed) {
      _messageController = StreamController<ConversationMessage>();
    }
    _isStopping = false;
    _isActive = true;
    unawaited(_runLoop());
    return _messageController.stream;
  }

  Future<void> _runLoop() async {
    try {
      _onBusyChanged(true);
      _onPhaseChanged('idle');
      _onStatusChanged('Listening for speech...');

      final micStream = _audioInputService.openMicrophoneStream();
      final iterator = StreamIterator<List<int>>(micStream);
      final buffer = AudioBuffer();

      try {
        while (_isActive && await iterator.moveNext()) {
          final chunk = iterator.current;
          if (chunk.isEmpty) {
            continue;
          }

          final hasSpeech = await _vadService.detectSpeech(chunk);
          if (!_isActive) break;

          if (!hasSpeech) {
            continue;
          }

          _onPhaseChanged('listening');
          _onStatusChanged('Speech detected, listening...');

          buffer.add(chunk);
          var lastSpeechAt = DateTime.now();

          while (_isActive && await iterator.moveNext()) {
            final nextChunk = iterator.current;
            if (nextChunk.isNotEmpty) {
              buffer.add(nextChunk);
            }

            final stillSpeech = await _vadService.detectSpeech(nextChunk);
            if (!_isActive) break;

            if (stillSpeech) {
              lastSpeechAt = DateTime.now();
            } else if (DateTime.now().difference(lastSpeechAt) >=
                trailingSilence) {
              break;
            }

            if (buffer.length >= maxBufferBytes) {
              _onStatusChanged('Utterance is too long, splitting it up.');
              break;
            }
          }

          if (!_isActive) break;
          if (buffer.isEmpty) continue;

          final audio = buffer.toList();
          buffer.clear();
          final spoke = await _processUtterance(audio);
          if (!_isActive) break;

          // Only flush after TTS. Flushing after every utterance ate the next
          // speech window in subtitle/hands-free mode.
          if (spoke) {
            await _flushBufferedAudio(iterator);
            if (!_isActive) break;
          }

          _onPhaseChanged('idle');
          _onStatusChanged('Listening for speech...');
        }
      } finally {
        await iterator.cancel();
      }
    } catch (error) {
      _onStatusChanged('Session error: $error');
    } finally {
      await stop();
    }
  }

  /// Returns true when translated audio was spoken (mic may contain echo).
  Future<bool> _processUtterance(List<int> audio) async {
    final transcript = (await _runStep(
      'transcribing',
      'Transcribing...',
      () => _speechRecognizer.transcribe(
        audioData: audio,
        language: _settings.sourceLanguage,
        model: _settings.speechModel,
      ),
    ))?.trim();
    if (!_isActive) {
      return false;
    }

    if (transcript == null || transcript.isEmpty) {
      return false;
    }

    final translation = (await _runStep(
      'translating',
      'Translating...',
      () => _translationEngine.translate(
        transcript,
        from: _settings.sourceLanguage,
        to: _settings.targetLanguage,
      ),
    ))?.trim();
    if (!_isActive) {
      return false;
    }

    if (translation == null || translation.isEmpty) {
      return false;
    }

    final shouldSpeak =
        _settings.mode == InterpreterMode.conversation &&
        _settings.voicePlaybackEnabled;

    if (!_messageController.isClosed) {
      _messageController.add(
        ConversationMessage(
          sourceLanguage: _settings.sourceLanguage,
          targetLanguage: _settings.targetLanguage,
          transcript: transcript,
          translation: translation,
          createdAt: DateTime.now(),
          latency: const Duration(milliseconds: 800),
          spoken: shouldSpeak,
        ),
      );
    }

    if (!shouldSpeak) {
      return false;
    }

    _onPhaseChanged('speaking');
    _onStatusChanged('Speaking translation...');
    try {
      await _ttsService.speak(
        translation,
        language: _settings.targetLanguage,
      );
    } catch (_) {}
    return true;
  }

  /// Drops mic chunks that arrived while we were busy (and a short tail after)
  /// so speaker playback is not immediately re-transcribed.
  Future<void> _flushBufferedAudio(StreamIterator<List<int>> iterator) async {
    final deadline = DateTime.now().add(postUtteranceFlush);
    while (_isActive && DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative) {
        break;
      }
      final hasNext = await iterator.moveNext().timeout(
        remaining,
        onTimeout: () => false,
      );
      if (!hasNext) {
        break;
      }
    }
  }

  /// Runs one pipeline step, reporting phase and status. Returns null when the
  /// step fails so a single bad utterance cannot kill the whole session.
  Future<String?> _runStep(
    String phase,
    String status,
    Future<String> Function() action,
  ) async {
    _onPhaseChanged(phase);
    _onStatusChanged(status);
    try {
      return await action();
    } catch (error) {
      _onStatusChanged('$status failed: $error');
      return null;
    }
  }

  @override
  Future<void> stop() async {
    if (!_isActive || _isStopping) {
      return;
    }
    _isStopping = true;
    _isActive = false;

    await _audioInputService.close();

    _onBusyChanged(false);
    _onPhaseChanged('idle');
    _onStatusChanged('Session stopped');

    if (!_messageController.isClosed) {
      await _messageController.close();
    }
  }
}
