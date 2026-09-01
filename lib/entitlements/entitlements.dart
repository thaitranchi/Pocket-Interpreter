import 'dart:async';

import 'package:flutter/foundation.dart';

import '../conversation/conversation_settings.dart';
import 'entitlement_storage.dart';
import 'subscription_tier.dart';

class Entitlements extends ChangeNotifier {
  Entitlements({
    EntitlementStorage? storage,
    int freeDailyVoiceMinutes = 5,
    DateTime Function()? clock,
  }) : _storage = storage ?? SharedPreferencesEntitlementStorage(),
       _freeDailyVoiceLimit = Duration(minutes: freeDailyVoiceMinutes),
       _clock = clock ?? DateTime.now;

  static const _kTier = 'entitlement_tier';
  static const _kVoiceUsedSeconds = 'entitlement_voice_used_seconds';
  static const _kUsageDay = 'entitlement_usage_day';

  final EntitlementStorage _storage;
  final Duration _freeDailyVoiceLimit;
  final DateTime Function() _clock;

  SubscriptionTier _tier = SubscriptionTier.free;
  Duration _voiceUsedToday = Duration.zero;
  DateTime? _usageDay;

  SubscriptionTier get tier => _tier;
  bool get isPro => _tier.isPro;
  Duration get freeDailyVoiceLimit => _freeDailyVoiceLimit;
  Duration get voiceUsedToday => _voiceUsedToday;

  Duration get remainingVoiceToday {
    if (isPro) {
      return _freeDailyVoiceLimit;
    }
    final remaining = _freeDailyVoiceLimit - _voiceUsedToday;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasUnlimitedVoice => isPro;
  bool get hasActiveDailyUsage => _voiceUsedToday > Duration.zero;

  bool canUseVoiceFeature() {
    if (isPro) {
      return true;
    }
    return _voiceUsedToday < _freeDailyVoiceLimit;
  }

  bool canAccess(SpeechModelProfile profile) {
    if (isPro) {
      return true;
    }
    return profile == SpeechModelProfile.tiny;
  }

  Set<SpeechModelProfile> get allowedSpeechProfiles {
    if (isPro) {
      return SpeechModelProfile.values.toSet();
    }
    return {SpeechModelProfile.tiny};
  }

  void consumeVoice(Duration amount) {
    if (isPro || amount <= Duration.zero) {
      return;
    }
    _resetIfNewDay();
    _voiceUsedToday += amount;
    if (_voiceUsedToday > _freeDailyVoiceLimit) {
      _voiceUsedToday = _freeDailyVoiceLimit;
    }
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> upgradeToPro() async {
    _tier = SubscriptionTier.pro;
    notifyListeners();
    await _persist();
  }

  Future<void> load() async {
    try {
      final tier = await _storage.read(_kTier);
      if (tier == SubscriptionTier.pro.name) {
        _tier = SubscriptionTier.pro;
      }
      final seconds = await _storage.read(_kVoiceUsedSeconds);
      if (seconds != null) {
        _voiceUsedToday = Duration(seconds: int.tryParse(seconds) ?? 0);
      }
      final day = await _storage.read(_kUsageDay);
      if (day != null) {
        _usageDay = DateTime.tryParse(day);
      }
      _resetIfNewDay();
      notifyListeners();
    } catch (_) {}
  }

  void _resetIfNewDay() {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    if (_usageDay == null || _usageDay != today) {
      _usageDay = today;
      _voiceUsedToday = Duration.zero;
    }
  }

  Future<void> _persist() async {
    await _storage.write(_kTier, _tier.name);
    await _storage.write(
      _kVoiceUsedSeconds,
      _voiceUsedToday.inSeconds.toString(),
    );
    await _storage.write(_kUsageDay, _usageDay?.toIso8601String() ?? '');
  }
}