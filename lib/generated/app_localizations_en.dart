// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Live Color Picker';

  @override
  String get noCameraAvailable => 'No camera available';

  @override
  String cameraError({required Object description}) {
    return 'Camera error: $description';
  }

  @override
  String cameraInitFailed({required Object error}) {
    return 'Failed to initialize camera: $error';
  }

  @override
  String copied({required Object text}) {
    return 'Copied: $text';
  }

  @override
  String get capturePhoto => 'Capture photo and create palette';

  @override
  String get captureFailed => 'Could not capture photo';

  @override
  String get paletteTitle => 'Color study';

  @override
  String get dominantColors => 'Dominant colors';

  @override
  String get tapToCopyColor => 'Tap a color to copy its HEX value';

  @override
  String get sharePalette => 'Share palette as PNG';

  @override
  String get shareFailed => 'Could not share palette';

  @override
  String get retry => 'Retry';

  @override
  String get hexLabel => 'HEX';

  @override
  String get rgbLabel => 'RGB';

  @override
  String get stability => 'Stability';

  @override
  String get stabilityDescription =>
      'Higher values reduce color jitter but respond slower to changes.';

  @override
  String get responsive => 'Responsive';

  @override
  String get stable => 'Stable';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get systemLanguage => 'System';
}
