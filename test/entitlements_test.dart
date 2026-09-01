import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_interpreter/conversation/conversation_settings.dart';
import 'package:pocket_interpreter/entitlements/entitlements.dart';
import 'package:pocket_interpreter/entitlements/entitlement_storage.dart';
import 'package:pocket_interpreter/entitlements/subscription_tier.dart';

void main() {
  test('free tier enforces the daily voice limit', () {
    final entitlements = Entitlements(
      storage: MemoryEntitlementStorage(),
      freeDailyVoiceMinutes: 5,
    );

    expect(entitlements.tier, SubscriptionTier.free);
    expect(entitlements.isPro, isFalse);
    expect(entitlements.canUseVoiceFeature(), isTrue);

    entitlements.consumeVoice(const Duration(minutes: 4, seconds: 59));
    expect(entitlements.canUseVoiceFeature(), isTrue);

    entitlements.consumeVoice(const Duration(seconds: 2));
    expect(entitlements.canUseVoiceFeature(), isFalse);
    expect(entitlements.remainingVoiceToday, Duration.zero);
    expect(entitlements.hasActiveDailyUsage, isTrue);
  });

  test('free tier voice usage clamps at the daily limit', () {
    final entitlements = Entitlements(
      storage: MemoryEntitlementStorage(),
      freeDailyVoiceMinutes: 5,
    );

    entitlements.consumeVoice(const Duration(hours: 2));
    expect(entitlements.voiceUsedToday, const Duration(minutes: 5));
    expect(entitlements.remainingVoiceToday, Duration.zero);
  });

  test('usage resets on a new day', () async {
    var now = DateTime(2026, 9, 1, 8);
    final entitlements = Entitlements(
      storage: MemoryEntitlementStorage(),
      freeDailyVoiceMinutes: 5,
      clock: () => now,
    );

    entitlements.consumeVoice(const Duration(minutes: 5));
    expect(entitlements.canUseVoiceFeature(), isFalse);

    now = now.add(const Duration(days: 1));
    await entitlements.load();
    expect(entitlements.canUseVoiceFeature(), isTrue);
    expect(entitlements.voiceUsedToday, Duration.zero);
  });

  test('pro tier has unlimited voice and ignores consumption', () async {
    final entitlements = Entitlements(storage: MemoryEntitlementStorage());

    await entitlements.upgradeToPro();
    expect(entitlements.isPro, isTrue);
    expect(entitlements.hasUnlimitedVoice, isTrue);

    entitlements.consumeVoice(const Duration(hours: 3));
    expect(entitlements.voiceUsedToday, Duration.zero);
    expect(entitlements.canUseVoiceFeature(), isTrue);
  });

  test('free tier can only access tiny speech model; pro unlocks all', () async {
    final entitlements = Entitlements(storage: MemoryEntitlementStorage());

    expect(entitlements.canAccess(SpeechModelProfile.tiny), isTrue);
    expect(entitlements.canAccess(SpeechModelProfile.base), isFalse);
    expect(entitlements.canAccess(SpeechModelProfile.smallInt8), isFalse);
    expect(entitlements.allowedSpeechProfiles, {SpeechModelProfile.tiny});

    await entitlements.upgradeToPro();
    expect(entitlements.canAccess(SpeechModelProfile.smallInt8), isTrue);
    expect(
      entitlements.allowedSpeechProfiles,
      SpeechModelProfile.values.toSet(),
    );
  });

  test('tier and usage persist across instances', () async {
    final storage = MemoryEntitlementStorage();
    final first = Entitlements(
      storage: storage,
      freeDailyVoiceMinutes: 5,
    );

    first.consumeVoice(const Duration(minutes: 3));
    await first.upgradeToPro();

    final second = Entitlements(
      storage: storage,
      freeDailyVoiceMinutes: 5,
    );
    await second.load();

    expect(second.tier, SubscriptionTier.pro);
    expect(second.voiceUsedToday, const Duration(minutes: 3));
    expect(second.canUseVoiceFeature(), isTrue);
  });
}