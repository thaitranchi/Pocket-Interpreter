# Pocket Interpreter

**Pocket Interpreter** is an offline-first, real-time English ↔ Vietnamese conversation translator. Speech recognition, translation, and text-to-speech all run **fully on device** — no cloud APIs, no audio leaves your phone, works without a network.

<!-- TABLE OF CONTENTS -->
- [Features](#features)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Requirements](#requirements)
- [Setup](#setup)
- [Testing](#testing)
- [Build & release](#build--release)
- [Monetization](#monetization)
- [Store assets](#store-assets)
- [Privacy](#privacy)
- [Versioning](#versioning)
- [License](#license)

## Features

- **Push-to-talk** real-time EN ↔ VI interpretation
- **Hands-free continuous mode** with streaming session
- **On-device Whisper** speech recognition (`tiny` / `base` / `small` model profiles)
- **On-device ML Kit** translation (models downloaded lazily on first use)
- **Natural voice playback** via Flutter TTS
- **Subtitle/mode controls**: conversation, subtitle, push-to-talk
- **Voice activity detection** (energy gate) for clean capture
- **Offline pack readiness** panel with model download status
- **Free + Pro tiers**: Free (daily voice limit, banner ads) / one-time Pro unlock
- **Conversation history** with latency metadata
- **Comprehensive test suite** (unit + widget + golden/screenshot)

## Architecture

```text
Microphone
  -> Voice Activity Detection          (energy gate)
  -> Speech Recognition                (Whisper.cpp via whisper_ggml)
  -> Translation Engine                (Google ML Kit on-device)
  -> Subtitle Rendering
  -> Text-to-Speech                    (flutter_tts)
  -> Speaker Output
```

All stages run on-device. The **conversation controller** (`ConversationController`) orchestrates the pipeline and enforces entitlements (per-minute voice budget on the Free tier).

## Project structure

```text
lib/
  main.dart                      # entry point
  app.dart                       # app widget, DI wiring
  audio/                         # input service + PCM buffer
  conversation/                  # controller, settings, messages, languages
  entitlements/                  # Free/Pro tiers, voice limits, persistence
  models/                        # Whisper model inventory / offline models
  monetization/                  # AdMob banner + Play Billing (Pro purchase)
  release/                       # app name/version metadata
  streaming/                     # continuous streaming sessions
  translation/                   # ML Kit engine + interface
  tts/                           # text-to-speech engine + interface
  ui/                            # conversation screen & widgets
  vad/                           # voice activity detection (energy)
  whisper/                       # Whisper recognizer + interface
test/
  audio_buffer_test.dart
  conversation_controller_test.dart
  entitlements_test.dart
  store_screenshot_generator_test.dart
  vad_test.dart
  widget_test.dart
store/                           # Play Console listing, privacy, graphics
tool/                            # asset generators
```

## Requirements

- **Flutter SDK** 3.x (stable)
- **Android**: Android Studio + **Android NDK 29** and **CMake 3.22+** (required by `whisper_ggml`)
- **iOS** (optional): Xcode.

> Speech models add significant size. The release AAB is intentionally large; Play automatically serves the correct model per device.

## Setup

```bash
flutter pub get
flutter test
flutter run          # launch on a connected device/emulator
```

## Testing

```bash
flutter analyze      # static analysis (0 issues expected)
flutter test         # unit + widget tests
```

## Build & release

Android release APK / AAB:

```bash
flutter build apk --release
flutter build appbundle --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

**Release signing** uses the upload keystore at `android/app/upload-keystore.jks`
referenced by `android/key.properties`. Both files are **gitignored** — back them up
separately and never commit them.

> The production AAB is signed with `com.tranchithai.poket_interpreter` and version
> `1.0.0+2`. If the Google Play Console requires the signing key during the first upload,
> Play is configured with your upload key.

## Monetization

| Tier | Included |
|------|----------|
| **Free** | Standard text/language translation; **limited voice**: 5 min/day; **banner ads**; `tiny` speech model |
| **Pro** (one-time) | Unlimited voice interpretation, no ads, all speech models (`tiny`/`base`/`small`), advanced features |

- **Ads**: `google_mobile_ads` banner shown only on the Free tier (`lib/monetization/ad_banner.dart`).
- **Play Billing**: `in_app_purchase` one-time non-consumable product `pro_unlock`
  (`lib/monetization/pro_purchase_service.dart`). Purchase persistence lives in
  `lib/entitlements/`. See `store/pricing_tiers.md`.

## Store assets

Generate screenshots and graphics from the committed generators:

```bash
# Screenshots (golden-based, renders the real UI)
flutter test test/store_screenshot_generator_test.dart --update-goldens
# copy test/goldens/*.png -> store/screenshots/

# Feature graphic (1024x500) & other graphics
pwsh tool/make_feature_graphic.ps1
```

Placeholders to replace before a production release (see `store/play_store_listing.md`):
validate your AdMob App ID / Ad Unit ID live.

## Privacy

Pocket Interpreter runs speech recognition (Whisper.cpp) and translation (Google ML Kit)
**fully on device**. Network access is used only to download the ML Kit translation model
and AdMob ads on first use. No audio or text is uploaded to a server.

Full privacy policy:
**https://thaitranchi.github.io/Pocket-Interpreter/store/privacy_policy.html**
(`store/privacy_policy.html`, published to GitHub Pages from this repo’s `main` branch).

## Versioning

Current release baseline:

```text
1.0.0+2 MVP
```

Follows [SemVer](https://semver.org/); the suffix is the Android/Play `versionCode`.

## License

MIT License — see [LICENSE](LICENSE).