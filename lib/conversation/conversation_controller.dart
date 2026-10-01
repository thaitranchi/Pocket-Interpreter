import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_buffer.dart';
import '../audio/audio_input_service.dart';
import '../audio/record_audio_input_service.dart';
import '../models/model_inventory.dart';
import '../streaming/continuous_streaming_session.dart';
import '../streaming/streaming_session.dart';
import '../translation/translation_engine.dart';
import '../tts/tts_service.dart';
import '../vad/vad_service.dart';
import '../whisper/speech_recognizer.dart';
import 'conversation_message.dart';
import 'conversation_settings.dart';
import 'language.dart';

enum InterpreterPhase {
  idle('Ready'),
  listening('Listening'),
  detectingSpeech('Detecting speech'),
  transcribing('Transcribing'),
  translating('Translating'),
  speaking('Speaking');

  const InterpreterPhase(this.label);

  final String label;
}

class ConversationController extends ChangeNotifier {
  ConversationController({
    required AudioInputService audioInputService,
    required SpeechRecognizer speechRecognizer,
    required TranslationEngine translationEngine,
    required TtsService ttsService,
    required VadService vadService,
    required ModelInventory modelInventory,
  }) : _audioInputService = audioInputService,
       _speechRecognizer = speechRecognizer,
       _translationEngine = translationEngine,
       _ttsService = ttsService,
       _vadService = vadService,
       _modelInventory = modelInventory;

  final AudioInputService _audioInputService;
  final SpeechRecognizer _speechRecognizer;
  final TranslationEngine _translationEngine;
  final TtsService _ttsService;
  final VadService _vadService;
  final ModelInventory _modelInventory;

  final List<ConversationMessage> _messages = [];

  ConversationSettings _settings = const ConversationSettings();
  InterpreterPhase _phase = InterpreterPhase.idle;
  String _status = 'Ready for offline interpreting';
  StreamingSession? _activeSession;
  bool _releaseRequested = false;
  bool _isDisposed = false;

  /// Trailing silence after the last detected speech chunk that ends an
  /// utterance.
  static const Duration pushToTalkTrailingSilence = Duration(
    milliseconds: 700,
  );

  /// Upper bound on a single push-to-talk capture.
  static const Duration pushToTalkMaxDuration = Duration(seconds: 12);

  /// Lower bound, so a single loud syllable is not treated as a full phrase.
  static const Duration pushToTalkMinDuration = Duration(milliseconds: 800);

  List<ConversationMessage> get messages => List.unmodifiable(_messages);
  ConversationSettings get settings => _settings;
  InterpreterPhase get phase => _phase;
  bool get isBusy => _phase != InterpreterPhase.idle;
  String get status => _status;
  ModelInventory get modelInventory => _modelInventory;
  bool get isReady => _modelInventory.isReady;

  void _notify() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  bool get isStreaming => _activeSession != null;

  bool get isStreamingMode =>
      _settings.mode == InterpreterMode.conversation ||
      _settings.mode == InterpreterMode.subtitles;

  void toggleDirection() {
    _settings = _settings.reversed();
    _status =
        'Direction changed to ${_settings.sourceLanguage.label} -> '
        '${_settings.targetLanguage.label}';
    _notify();
  }

  void setSourceLanguage(SupportedLanguage language) {
    if (language == _settings.sourceLanguage) {
      return;
    }

    _settings = _settings.copyWith(
      sourceLanguage: language,
      targetLanguage: language == _settings.targetLanguage
          ? _settings.sourceLanguage
          : _settings.targetLanguage,
    );
    _status = 'Source language set to ${_settings.sourceLanguage.label}';
    _notify();
  }

  void setTargetLanguage(SupportedLanguage language) {
    if (language == _settings.targetLanguage) {
      return;
    }

    _settings = _settings.copyWith(
      sourceLanguage: language == _settings.sourceLanguage
          ? _settings.targetLanguage
          : _settings.sourceLanguage,
      targetLanguage: language,
    );
    _status = 'Target language set to ${_settings.targetLanguage.label}';
    _notify();
  }

  void setMode(InterpreterMode mode) {
    if (isStreaming) {
      unawaited(stopStreaming());
    }
    _settings = _settings.copyWith(mode: mode);
    _status = '${mode.label} enabled';
    _notify();
  }

  void setSpeechModel(SpeechModelProfile model) {
    _settings = _settings.copyWith(speechModel: model);
    _status = '${model.label} speech model selected';
    _notify();
  }

  void setVoicePlaybackEnabled(bool enabled) {
    _settings = _settings.copyWith(voicePlaybackEnabled: enabled);
    _status = enabled ? 'Voice playback enabled' : 'Voice playback muted';
    _notify();
  }

  void clearHistory() {
    _messages.clear();
    _status = 'Conversation cleared';
    _notify();
  }

  @visibleForTesting
  void injectMessage(ConversationMessage message) {
    _messages.insert(0, message);
    _notify();
  }

  /// Ends an in-flight push-to-talk capture early. Wired to the release of the
  /// press-and-hold button so the capture length matches how long the user
  /// actually held the button.
  void requestPushToTalkRelease() {
    _releaseRequested = true;
  }

  Future<void> startPushToTalk({Duration? maxDuration}) async {
    if (isBusy || isStreaming) {
      return;
    }

    if (!isReady) {
      _status = 'Install required offline models before interpreting';
      _notify();
      return;
    }

    final startedAt = DateTime.now();
    _releaseRequested = false;
    _phase = InterpreterPhase.listening;
    _status = 'Listening...';
    _notify();

    AudioBuffer buffer;
    try {
      buffer = await _captureUtterance(maxDuration: maxDuration);
    } on MicrophonePermissionDenied {
      _phase = InterpreterPhase.idle;
      _status =
          'Microphone permission denied. Enable it in system settings to '
          'interpret speech.';
      _notify();
      return;
    } catch (error) {
      _phase = InterpreterPhase.idle;
      _status = 'Microphone error: $error';
      _notify();
      return;
    }

    if (buffer.isEmpty) {
      _phase = InterpreterPhase.idle;
      _status = 'No audio captured. Check the microphone and try again.';
      _notify();
      return;
    }

    try {
      _phase = InterpreterPhase.detectingSpeech;
      _status = 'Analyzing audio...';
      _notify();

      final hasSpeech = await _vadService.detectSpeech(buffer.toList());
      if (!hasSpeech) {
        _status = 'No speech detected';
        return;
      }

      _phase = InterpreterPhase.transcribing;
      _status = 'Running local speech recognition...';
      _notify();

      final transcript = (await _speechRecognizer.transcribe(
        audioData: buffer.toList(),
        language: _settings.sourceLanguage,
        model: _settings.speechModel,
      ))
          .trim();

      if (transcript.isEmpty) {
        _status = 'No speech recognised. Try again a little closer to the mic.';
        return;
      }

      _phase = InterpreterPhase.translating;
      _status = 'Translating offline...';
      _notify();

      final translation = (await _translationEngine.translate(
        transcript,
        from: _settings.sourceLanguage,
        to: _settings.targetLanguage,
      ))
          .trim();

      if (translation.isEmpty) {
        _status = 'Translation came back empty. Try again.';
        return;
      }

      final shouldSpeak =
          _settings.mode == InterpreterMode.conversation &&
          _settings.voicePlaybackEnabled;
      final message = ConversationMessage(
        sourceLanguage: _settings.sourceLanguage,
        targetLanguage: _settings.targetLanguage,
        transcript: transcript,
        translation: translation,
        createdAt: DateTime.now(),
        latency: DateTime.now().difference(startedAt),
        spoken: shouldSpeak,
      );

      _messages.insert(0, message);

      if (shouldSpeak) {
        _phase = InterpreterPhase.speaking;
        _status = 'Playing translated voice...';
        _notify();
        await _ttsService.speak(translation, language: _settings.targetLanguage);
      }

      _status = 'Translated on device';
    } catch (error) {
      _status = _describeFailure(error);
    } finally {
      _phase = InterpreterPhase.idle;
      _notify();
    }
  }

  /// Records until the utterance ends, the caller releases the button, the
  /// microphone stream finishes, or [pushToTalkMaxDuration] is reached.
  Future<AudioBuffer> _captureUtterance({Duration? maxDuration}) async {
    final limit = maxDuration ?? pushToTalkMaxDuration;
    final buffer = AudioBuffer();
    final startedAt = DateTime.now();
    DateTime? lastSpeechAt;
    var heardSpeech = false;

    final micStream = _audioInputService.openMicrophoneStream();
    final iterator = StreamIterator<List<int>>(micStream);
    try {
      while (await iterator.moveNext()) {
        final chunk = iterator.current;
        if (chunk.isEmpty) {
          continue;
        }
        buffer.add(chunk);

        final now = DateTime.now();
        final elapsed = now.difference(startedAt);
        final isSpeech = await _vadService.detectSpeech(chunk);
        if (isSpeech) {
          heardSpeech = true;
          lastSpeechAt = now;
        } else if (heardSpeech &&
            lastSpeechAt != null &&
            elapsed >= pushToTalkMinDuration &&
            now.difference(lastSpeechAt) >= pushToTalkTrailingSilence) {
          break;
        }

        if (elapsed >= limit) {
          _status =
              'Reached the ${limit.inSeconds}s capture limit for one turn';
          break;
        }
        if (_releaseRequested) {
          break;
        }
      }
    } finally {
      await iterator.cancel();
      await _audioInputService.close();
    }

    return buffer;
  }

  String _describeFailure(Object error) {
    final text = error.toString();
    if (text.contains('MlKitException') ||
        text.contains('Translate') ||
        text.contains('model')) {
      return 'Translation failed. The offline model may be missing or '
          'corrupt - reinstall it from the offline pack panel.';
    }
    if (text.contains('HttpException') || text.contains('SocketException')) {
      return 'Model download failed. Check your connection and try again.';
    }
    return 'Interpreting failed: $error';
  }

  Future<void> startStreaming() async {
    if (isBusy || isStreaming) {
      return;
    }

    if (!isReady) {
      _status = 'Install required offline models before interpreting';
      _notify();
      return;
    }

    final session = ContinuousStreamingSession(
      audioInputService: _audioInputService,
      speechRecognizer: _speechRecognizer,
      translationEngine: _translationEngine,
      ttsService: _ttsService,
      vadService: _vadService,
      settings: _settings,
      onBusyChanged: (_) {},
      onStatusChanged: (status) {
        _status = status;
        _notify();
      },
      onPhaseChanged: (phaseLabel) {
        _phase = switch (phaseLabel) {
          'listening' => InterpreterPhase.listening,
          'transcribing' => InterpreterPhase.transcribing,
          'translating' => InterpreterPhase.translating,
          'speaking' => InterpreterPhase.speaking,
          _ => InterpreterPhase.idle,
        };
        _notify();
      },
    );

    _activeSession = session;
    _notify();

    session.start().listen(
      (message) {
        _messages.insert(0, message);
        _notify();
      },
      onError: (Object err) {
        _status = 'Session error: $err';
        _phase = InterpreterPhase.idle;
        unawaited(stopStreaming());
      },
      onDone: () {
        unawaited(stopStreaming());
      },
    );
  }

  Future<void> stopStreaming() async {
    final session = _activeSession;
    if (session == null) {
      return;
    }
    _activeSession = null;
    await session.stop();
    _phase = InterpreterPhase.idle;
    _status = 'Session stopped';
    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    final session = _activeSession;
    _activeSession = null;
    unawaited(session?.stop());
    super.dispose();
  }
}
