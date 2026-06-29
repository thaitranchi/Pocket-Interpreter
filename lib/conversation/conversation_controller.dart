import 'dart:async';
import 'package:flutter/foundation.dart';

import '../audio/audio_buffer.dart';
import '../audio/audio_input_service.dart';
import '../streaming/streaming_session.dart';
import '../streaming/continuous_streaming_session.dart';
import '../translation/translation_engine.dart';
import '../tts/tts_service.dart';
import '../vad/vad_service.dart';
import '../whisper/speech_recognizer.dart';
import '../models/model_inventory.dart';
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

  List<ConversationMessage> get messages => List.unmodifiable(_messages);
  ConversationSettings get settings => _settings;
  InterpreterPhase get phase => _phase;
  bool get isBusy => _phase != InterpreterPhase.idle;
  String get status => _status;
  ModelInventory get modelInventory => _modelInventory;
  bool get isReady => _modelInventory.isReady;

  bool get isStreaming => _activeSession != null;

  bool get isStreamingMode =>
      _settings.mode == InterpreterMode.conversation ||
      _settings.mode == InterpreterMode.subtitles;

  void toggleDirection() {
    _settings = _settings.reversed();
    _status =
        'Direction changed to ${_settings.sourceLanguage.label} -> '
        '${_settings.targetLanguage.label}';
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  void setMode(InterpreterMode mode) {
    if (isStreaming) {
      stopStreaming();
    }
    _settings = _settings.copyWith(mode: mode);
    _status = '${mode.label} enabled';
    notifyListeners();
  }

  void setSpeechModel(SpeechModelProfile model) {
    _settings = _settings.copyWith(speechModel: model);
    _status = '${model.label} speech model selected';
    notifyListeners();
  }

  void setVoicePlaybackEnabled(bool enabled) {
    _settings = _settings.copyWith(voicePlaybackEnabled: enabled);
    _status = enabled ? 'Voice playback enabled' : 'Voice playback muted';
    notifyListeners();
  }

  void clearHistory() {
    _messages.clear();
    _status = 'Conversation cleared';
    notifyListeners();
  }

  Future<void> startPushToTalk() async {
    if (isBusy || isStreaming) {
      return;
    }

    if (!isReady) {
      _status = 'Install required offline models before interpreting';
      notifyListeners();
      return;
    }

    final startedAt = DateTime.now();
    _phase = InterpreterPhase.listening;
    _status = 'Listening...';
    notifyListeners();

    StreamSubscription<List<int>>? micSub;
    final buffer = AudioBuffer();

    try {
      final micStream = _audioInputService.openMicrophoneStream();
      micSub = micStream.listen((data) {
        buffer.add(data);
      });
    } catch (e) {
      _status = 'Microphone error: $e';
      _phase = InterpreterPhase.idle;
      notifyListeners();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));

    await micSub?.cancel();
    await _audioInputService.close();

    if (buffer.isEmpty) {
      _phase = InterpreterPhase.idle;
      _status = 'No audio captured';
      notifyListeners();
      return;
    }

    _phase = InterpreterPhase.detectingSpeech;
    _status = 'Analyzing audio...';
    notifyListeners();

    final hasSpeech = await _vadService.detectSpeech(buffer.toList());
    if (!hasSpeech) {
      _phase = InterpreterPhase.idle;
      _status = 'No speech detected';
      notifyListeners();
      return;
    }

    _phase = InterpreterPhase.transcribing;
    _status = 'Running local speech recognition...';
    notifyListeners();

    final transcript = await _speechRecognizer.transcribe(
      audioData: buffer.toList(),
      language: _settings.sourceLanguage,
      model: _settings.speechModel,
    );

    _phase = InterpreterPhase.translating;
    _status = 'Translating offline...';
    notifyListeners();

    final translation = await _translationEngine.translate(
      transcript,
      from: _settings.sourceLanguage,
      to: _settings.targetLanguage,
    );

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
      notifyListeners();
      await _ttsService.speak(translation, language: _settings.targetLanguage);
    }

    _phase = InterpreterPhase.idle;
    _status = 'Translated on device';
    notifyListeners();
  }

  Future<void> startStreaming() async {
    if (isBusy || isStreaming) {
      return;
    }

    if (!isReady) {
      _status = 'Install required offline models before interpreting';
      notifyListeners();
      return;
    }

    final session = ContinuousStreamingSession(
      audioInputService: _audioInputService,
      speechRecognizer: _speechRecognizer,
      translationEngine: _translationEngine,
      ttsService: _ttsService,
      vadService: _vadService,
      settings: _settings,
      onBusyChanged: (busy) {},
      onStatusChanged: (status) {
        _status = status;
        notifyListeners();
      },
      onPhaseChanged: (phaseLabel) {
        _phase = switch (phaseLabel) {
          'listening' => InterpreterPhase.listening,
          'transcribing' => InterpreterPhase.transcribing,
          'translating' => InterpreterPhase.translating,
          'speaking' => InterpreterPhase.speaking,
          _ => InterpreterPhase.idle,
        };
        notifyListeners();
      },
    );

    _activeSession = session;
    notifyListeners();

    session.start().listen(
      (message) {
        _messages.insert(0, message);
        notifyListeners();
      },
      onError: (err) {
        _status = 'Session error: $err';
        stopStreaming();
      },
      onDone: () {
        stopStreaming();
      },
    );
  }

  Future<void> stopStreaming() async {
    if (_activeSession == null) {
      return;
    }

    final session = _activeSession;
    _activeSession = null;
    await session?.stop();
    _phase = InterpreterPhase.idle;
    _status = 'Session stopped';
    notifyListeners();
  }

  @override
  void dispose() {
    stopStreaming();
    super.dispose();
  }
}
