// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '实时取色器';

  @override
  String get noCameraAvailable => '没有可用摄像头';

  @override
  String cameraError({required Object description}) {
    return '摄像头错误：$description';
  }

  @override
  String cameraInitFailed({required Object error}) {
    return '摄像头初始化失败：$error';
  }

  @override
  String copied({required Object text}) {
    return '已复制：$text';
  }

  @override
  String get capturePhoto => '拍摄画面并生成调色板';

  @override
  String get captureFailed => '拍摄失败';

  @override
  String get paletteTitle => '画面色卡';

  @override
  String get dominantColors => '画面主要颜色';

  @override
  String get tapToCopyColor => '点击色卡复制 HEX 色值';

  @override
  String get sharePalette => '以 PNG 分享调色板';

  @override
  String get shareFailed => '分享调色板失败';

  @override
  String get retry => '重试';

  @override
  String get hexLabel => 'HEX';

  @override
  String get rgbLabel => 'RGB';

  @override
  String get stability => '稳定性';

  @override
  String get stabilityDescription => '数值越高颜色越稳定，但对变化响应更慢';

  @override
  String get responsive => '快速';

  @override
  String get stable => '稳定';

  @override
  String get languageLabel => '语言';

  @override
  String get languageEnglish => '英文';

  @override
  String get languageChinese => '中文';

  @override
  String get systemLanguage => '跟随系统';
}
