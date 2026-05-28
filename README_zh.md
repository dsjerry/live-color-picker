# 实时取色器

[English](README.md)

使用摄像头实时取色。对准任何物体，即时获取 HEX / RGB 颜色值。

## 功能

- 摄像头实时取色（中心十字准星采样）
- HEX 和 RGB 颜色值显示，点击即可复制
- 时间平滑算法，读数稳定可调（设置中调节稳定性滑块）
- 中/英文国际化，默认跟随系统语言
- 设置中可手动切换语言

## 技术栈

- **Flutter**（stable 渠道）
- **camera** 插件获取图像流
- YUV → RGB 转换（NV21 / BGRA8888）
- Flutter `gen-l10n` 实现国际化（ARB 文件）

## 快速开始

```bash
flutter pub get
flutter run
```

需要带有摄像头的设备（真机或支持摄像头的模拟器）。

## 构建（GitHub Actions）

通过 [workflow_dispatch](.github/workflows/build-android.yml) 手动触发：

- **apk** — release APK，按 ABI 拆分（arm64-v8a、armeabi-v7a、x86_64）
- **appbundle** — release AAB

每次构建会自动创建 GitHub Release 并附带产物。

## 本地化

界面文本定义在 `lib/l10n/` 目录下。编辑 ARB 文件后，运行以下命令重新生成：

```bash
flutter gen-l10n
```

支持语言：英文（`en`）、中文（`zh`）。

## 贡献者

- **dsjerry** — 作者
- **Claude (Anthropic)** — AI 助手，代码共同作者

## 项目结构

```
lib/
  main.dart                  应用入口，语言环境配置
  screens/
    camera_screen.dart       主相机界面 + 设置面板
  providers/
    locale_provider.dart     语言状态与持久化
  l10n/
    app_en.arb / app_zh.arb  翻译文件
  generated/                 生成的本地化代码
```
