import 'dart:async';
import 'package:flutter/foundation.dart';
import '../audio/audio_buffer.dart';
import '../audio/audio_input_service.dart';
import '../conversation/conversation_message.dart';
import '../conversation/conversation_settings.dart';
import '../conversation/language.dart';
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
  })  : _audioInputService = audioInputService,
        _speechRecognizer = speechRecognizer,
        _translationEngine = translationEngine,
        _ttsService = ttsService,
        _vadService = vadService,
        _settings = settings,
        _onStatusChanged = onStatusChanged,
        _onBusyChanged = onBusyChanged,
        _onPhaseChanged = onPhaseChanged;

  final AudioInputService _audioInputService;
  final SpeechRecognizer _speechRecognizer;
  final TranslationEngine _translationEngine;
  final TtsService _ttsService;
  final VadService _vadService;
  final ConversationSettings _settings;

  final ValueChanged<String> _onStatusChanged;
  final ValueChanged<bool> _onBusyChanged;
  final ValueChanged<String> _onPhaseChanged;

  final StreamController<ConversationMessage> _messageController =
      StreamController<ConversationMessage>();

  bool _isActive = false;

  @override
  Stream<ConversationMessage> start() {
    if (_isActive) {
      return _messageController.stream;
    }
    _isActive = true;
    _runLoop();
    return _messageController.stream;
  }

  Future<void> _runLoop() async {
    try {
      _onBusyChanged(true);

      final micStream = _audioInputService.openMicrophoneStream();
      final iterator = StreamIterator<List<int>>(micStream);
      final buffer = AudioBuffer();

      while (_isActive && await iterator.moveNext()) {
        final chunk = iterator.current;

        final hasSpeech = await _vadService.detectSpeech(chunk);
        if (!_isActive) break;

        if (!hasSpeech) {
          continue;
        }

        _onPhaseChanged('listening');
        _onStatusChanged('Speech detected, listening...');

        buffer.add(chunk);

        while (_isActive && await iterator.moveNext()) {
          final nextChunk = iterator.current;
          buffer.add(nextChunk);

          final stillSpeech = await _vadService.detectSpeech(nextChunk);
          if (!_isActive) break;

          if (!stillSpeech) {
            await Future.delayed(const Duration(milliseconds: 300));
            if (!_isActive) break;

            if (await iterator.moveNext()) {
              final silenceChunk = iterator.current;
              buffer.add(silenceChunk);
            }
            break;
          }
        }

        if (!_isActive) break;
        if (buffer.isEmpty) continue;

        _onPhaseChanged('transcribing');
        _onStatusChanged('Transcribing...');
        final transcript = await _speechRecognizer.transcribe(
          audioData: buffer.toList(),
          language: _settings.sourceLanguage,
          model: _settings.speechModel,
        );
        buffer.clear();
        if (!_isActive) break;

        _onPhaseChanged('translating');
        _onStatusChanged('Translating...');
        final translation = await _translationEngine.translate(
          transcript,
          from: _settings.sourceLanguage,
          to: _settings.targetLanguage,
        );
        if (!_isActive) break;

        final shouldSpeak =
            _settings.mode == InterpreterMode.conversation &&
            _settings.voicePlaybackEnabled;

        final message = ConversationMessage(
          sourceLanguage: _settings.sourceLanguage,
          targetLanguage: _settings.targetLanguage,
          transcript: transcript,
          translation: translation,
          createdAt: DateTime.now(),
          latency: const Duration(milliseconds: 800),
          spoken: shouldSpeak,
        );

        _messageController.add(message);

        if (shouldSpeak) {
          _onPhaseChanged('speaking');
          _onStatusChanged('Speaking translation...');
          await _ttsService.speak(translation, language: _settings.targetLanguage);
        }
      }
    } catch (e) {
      _onStatusChanged('Session error: $e');
    } finally {
      await stop();
    }
  }

  @override
  Future<void> stop() async {
    if (!_isActive) return;
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
