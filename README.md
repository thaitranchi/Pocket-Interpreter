# Pocket Interpreter

Pocket Interpreter is an offline-first Flutter app for real-time conversation translation. The v1.0.0 baseline provides the mobile app shell, EN-VI interpreter workflow, model readiness checks, and replaceable service boundaries for native offline AI integrations.

## v1.0.0 Scope

Implemented:

- Flutter Android/iOS project structure
- Push-to-talk interpreter flow
- EN -> VI and VI -> EN mock translation path
- Source and target language selectors
- Conversation, subtitle, and push-to-talk mode controls
- Speech model profile selector: `tiny`, `base`, `small-int8`
- Offline pack readiness panel
- Pipeline phases: listening, VAD, transcription, translation, TTS
- Conversation history with latency metadata
- Unit and widget tests for the release baseline

Integration boundaries are present for:

- Microphone input
- Voice activity detection
- Whisper-style speech recognition
- Argos-style translation
- Platform text-to-speech
- Streaming conversation sessions

Native Whisper.cpp, Argos Translate, Silero VAD, and platform TTS adapters are not wired yet. The current v1.0.0 build uses deterministic mock adapters so the product flow, UI, tests, and release structure can stabilize before native model integration.

## Architecture

```text
Microphone
  -> Voice Activity Detection
  -> Speech Recognition
  -> Translation Engine
  -> Subtitle Rendering
  -> Text-to-Speech
  -> Speaker Output
```

## Project Structure

```text
lib/
  app.dart
  main.dart
  audio/
  conversation/
  models/
  release/
  streaming/
  translation/
  tts/
  ui/
  vad/
  whisper/
test/
  conversation_controller_test.dart
  widget_test.dart
```

## Requirements

- Flutter SDK
- Android Studio for Android builds
- Xcode for iOS builds
- Android NDK and CMake for future native model adapters

## Setup

```bash
flutter pub get
flutter test
flutter run
```

## Build

Android release APK:

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Version

Current release baseline:

```text
1.0.0+1 MVP
```

## Privacy Goal

Pocket Interpreter is designed so speech recognition, translation, and playback can run fully on device. The current release does not call cloud APIs and does not include network-backed translation services.

## License

MIT License
