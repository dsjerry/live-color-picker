# Live Color Picker

Real-time color picker using the device camera. Point your camera at anything and get the HEX / RGB color instantly.

## Features

- Camera-based live color detection (center crosshair sampling)
- HEX and RGB display with one-tap copy
- Temporal smoothing for stable readings (adjustable in settings)
- Chinese / English i18n, defaults to system language
- Manual language switch in settings

## Tech Stack

- **Flutter** (stable channel)
- **camera** plugin for image stream capture
- YUV → RGB conversion (NV21 / BGRA8888)
- Flutter `gen-l10n` for localization (ARB files)

## Getting Started

```bash
flutter pub get
flutter run
```

Requires a device with a camera (physical or emulator with camera support).

## Build (GitHub Actions)

Manually triggered via [workflow_dispatch](.github/workflows/build-android.yml):

- **apk** — release APK split per ABI (arm64-v8a, armeabi-v7a, x86_64)
- **appbundle** — release AAB

Each run creates a GitHub Release with the artifact attached.

## Localization

UI strings are defined in `lib/l10n/`. To regenerate after editing ARB files:

```bash
flutter gen-l10n
```

Supported languages: English (`en`), Chinese (`zh`).

## Project Structure

```
lib/
  main.dart                  App entry, locale setup
  screens/
    camera_screen.dart       Main camera UI + settings sheet
  providers/
    locale_provider.dart     Locale state & persistence
  l10n/
    app_en.arb / app_zh.arb  Translation files
  generated/                 Generated localization code
```
