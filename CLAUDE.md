# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Flutter mobile app that uses the device camera to detect colors in real-time. The center crosshair samples a 5x5 pixel grid from the camera feed, converts YUV/BGRA pixel formats to RGB, and displays HEX/RGB values with one-tap copy.

## Commands

```bash
flutter pub get                    # Install dependencies
flutter run                        # Run on connected device/emulator
flutter build apk --release        # Build release APK
flutter build appbundle --release  # Build AAB for Play Store
flutter analyze                    # Static analysis (uses flutter_lints)
flutter gen-l10n                   # Regenerate localization code from ARB files
flutter test                       # Run widget tests
```

## Architecture

Single-screen app with minimal state management:

- **[lib/main.dart](lib/main.dart)** — App entry point. Locks to portrait orientation, initializes `LocaleProvider`, wraps `MaterialApp` with `LocaleScope` (an `InheritedNotifier`) for locale propagation.
- **[lib/screens/camera_screen.dart](lib/screens/camera_screen.dart)** — The entire UI lives here. Handles camera lifecycle, image stream processing, color extraction, temporal smoothing, pinch-to-zoom, crosshair overlay, color info panel, and a bottom-sheet settings panel (stability slider + language picker).
- **[lib/providers/locale_provider.dart](lib/providers/locale_provider.dart)** — `ChangeNotifier`-based locale state with a lightweight in-memory persistence shim (`_Prefs` class, no SharedPreferences dependency). Exposes `LocaleScope` as an `InheritedNotifier` so the settings sheet can call `LocaleScope.of(context)` to get/set the locale.
- **[lib/l10n/](lib/l10n/)** — ARB translation files (`app_en.arb`, `app_zh.arb`). Generated code goes to `lib/generated/`. Run `flutter gen-l10n` after editing ARB files. Config in [l10n.yaml](l10n.yaml) (template: `app_en.arb`, output: `lib/generated/`, named params, non-nullable getter).

### Color Extraction Pipeline

`_extractColor()` in camera_screen.dart handles two pixel formats:
- **BGRA8888** (iOS): Direct byte offset into plane[0], stride = bytesPerRow * 4.
- **NV21/YUV420** (Android): Reads Y from plane[0], U/V from plane[1] (or packed after Y when single-plane). Uses standard YUV→RGB coefficients.

Temporal smoothing uses exponential moving average with `_smoothingFactor` derived from a `_stability` slider (0 = responsive, 1 = max stable).

### Pinch-to-Zoom

Uses `AnimationController` (200ms, `Curves.easeOut`) for smooth eased interpolation rather than direct `setZoomLevel` calls. Key state: `_scaleBaseZoom` captures zoom at gesture start, `_zoomTarget` is the desired level, `_zoom` is the animation start point. `_applyZoom` deduplicates platform channel calls via `_lastAppliedZoom`. No `setState` in the gesture handler — the native camera preview handles zoom rendering independently.

## Key Dependencies

- **camera** (`^0.11.1`) — Image stream capture and preview
- **flutter_localizations** (SDK) — i10n delegates
- **flutter_lints** (`^5.0.0`) — Lint rules (extends `package:flutter_lints/flutter.yaml`)
- **flutter_launcher_icons** (`^0.14.3`) — App icon generation from `assets/icon/app-icon-1024.png`

## CI

GitHub Actions workflow at [.github/workflows/build-android.yml](.github/workflows/build-android.yml) — manually triggered (`workflow_dispatch`), supports `apk` (split per ABI) and `appbundle` builds. Creates a GitHub Release with the artifact.

## Platform-Specific Notes

- Android namespace: `com.example.live_color_picker`
- Camera image format is selected per platform: `bgra8888` for iOS, `nv21` for Android (in `_initCamera()`)
- App is portrait-locked via `SystemChrome.setPreferredOrientations`
