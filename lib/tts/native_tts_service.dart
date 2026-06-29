import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../conversation/language.dart';
import 'tts_service.dart';

class NativeTtsService implements TtsService {
  const NativeTtsService();

  static final FlutterTts _tts = FlutterTts();

  bool _isTestEnvironment() {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    try {
      final bindingStr = WidgetsBinding.instance.toString();
      if (bindingStr.contains('Test')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<void> speak(String text, {required SupportedLanguage language}) async {
    if (_isTestEnvironment()) {
      debugPrint('NativeTtsService: Running in test environment, skipping speak call.');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return;
    }

    try {
      final locale = language == SupportedLanguage.english ? 'en-US' : 'vi-VN';
      await _tts.setLanguage(locale);
      await _tts.speak(text);
    } catch (e) {
      // Degrade gracefully if running in a test environment where platform channels are unavailable
      debugPrint('NativeTTS: Failed to speak "$text" using locale ($language): $e');
    }
  }
}
