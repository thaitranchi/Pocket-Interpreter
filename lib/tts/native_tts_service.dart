import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../conversation/language.dart';
import 'tts_service.dart';

class NativeTtsService implements TtsService {
  NativeTtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, {required SupportedLanguage language}) async {
    if (text.trim().isEmpty) {
      return;
    }
    final locale = language == SupportedLanguage.english ? 'en-US' : 'vi-VN';
    try {
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } catch (error) {
      debugPrint('NativeTtsService: failed to speak ($locale): $error');
    }
  }
}
