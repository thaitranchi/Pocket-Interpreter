# Pocket Interpreter

Pocket Interpreter is an offline-first Flutter app for real-time conversation translation. Speech recognition, translation, and text-to-speech all run fully on device — no cloud APIs required.

## Implemented

- Flutter Android/iOS project structure
- Push-to-talk interpreter flow
- EN -> VI and VI -> EN on-device translation via Google ML Kit (downloaded on first use)
- On-device speech recognition via Whisper.cpp (whisper_ggml), `tiny`/`base`/`small` model profiles
- Source and target language selectors
- Conversation, subtitle, and push-to-talk mode controls
- Speech model profile selector: `tiny`, `base`, `small`
- Offline pack readiness panel
- Pipeline phases: listening, VAD, transcription, translation, TTS
- Conversation history with latency metadata
- Unit and widget tests for the release baseline

Types used in production:

- Microphone input: `record` (PCM 16-bit, 16 kHz mono)
- Voice activity detection: `record` power-based energy gate
- Speech recognition: Whisper.cpp via `whisper_ggml`
- Translation: `google_mlkit_translation` on-device models
- Text-to-speech: `flutter_tts`
- Streaming conversation sessions: `StreamingConversationSession`

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
- Android NDK 29 and CMake 3.22+ (bundled by whisper_ggml)

## Setup

```bash
flutter pub get
flutter test
flutter run
```

## Build

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

## Version

Current release baseline:

```text
1.0.0+1 MVP
```

## Privacy Goal

Pocket Interpreter runs speech recognition (Whisper.cpp) and translation (Google ML Kit) fully on device. Network access is used only to download the ML Kit translation model on first use; no audio or text ever leaves the device.

## License

MIT License
