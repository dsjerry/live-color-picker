import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/app_localizations.dart';

class PaletteCaptureScreen extends StatelessWidget {
  static const _shareChannel = MethodChannel('live_color_picker/share');

  final String imagePath;
  final List<Color> colors;

  const PaletteCaptureScreen({
    super.key,
    required this.imagePath,
    required this.colors,
  });

  String _hex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${r + g + b}'.toUpperCase();
  }

  Future<void> _sharePalette(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    try {
      final png = await _renderSharePng(l10n);
      final directory = Directory(
        '${File(imagePath).parent.path}/palette_share',
      );
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}/palette-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png, flush: true);
      await _shareChannel.invokeMethod<void>('sharePng', {
        'path': file.path,
        'title': l10n.paletteTitle,
      });
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.shareFailed}: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<Uint8List> _renderSharePng(AppLocalizations l10n) async {
    final codec = await ui.instantiateImageCodec(
      await File(imagePath).readAsBytes(),
      targetWidth: 1080,
    );
    try {
      final frame = await codec.getNextFrame();
      final photo = frame.image;
      try {
        const canvasWidth = 1080.0;
        const sideMargin = 64.0;
        const contentWidth = canvasWidth - sideMargin * 2;
        const photoTop = 190.0;
        final photoHeight = contentWidth * photo.height / photo.width;
        final paletteTop = photoTop + photoHeight + 48;
        const paletteHeight = 244.0;
        final canvasHeight = (paletteTop + paletteHeight + 112).ceil();

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(
          recorder,
          Rect.fromLTWH(0, 0, canvasWidth, canvasHeight.toDouble()),
        );
        canvas.drawColor(const Color(0xFF111312), BlendMode.src);

        void drawText(
          String text,
          Offset offset, {
          required double maxWidth,
          required double fontSize,
          required Color color,
          FontWeight fontWeight = FontWeight.normal,
          double letterSpacing = 0,
          TextAlign textAlign = TextAlign.left,
        }) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: fontWeight,
                letterSpacing: letterSpacing,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: textAlign,
            maxLines: 1,
          )..layout(maxWidth: maxWidth);
          painter.paint(canvas, offset);
        }

        drawText(
          l10n.paletteTitle,
          const Offset(sideMargin, 50),
          maxWidth: contentWidth,
          fontSize: 42,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        );
        drawText(
          l10n.dominantColors.toUpperCase(),
          const Offset(sideMargin, 116),
          maxWidth: contentWidth,
          fontSize: 17,
          color: const Color(0xFF9BA39D),
          fontWeight: FontWeight.w600,
          letterSpacing: 3,
        );

        final photoRect = Rect.fromLTWH(
          sideMargin,
          photoTop,
          contentWidth,
          photoHeight,
        );
        final photoRRect = RRect.fromRectAndRadius(
          photoRect,
          const Radius.circular(24),
        );
        canvas.save();
        canvas.clipRRect(photoRRect);
        canvas.drawImageRect(
          photo,
          Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
          photoRect,
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();

        final palette = colors.isEmpty ? [Colors.white] : colors;
        const cardGap = 14.0;
        final cardWidth =
            (contentWidth - cardGap * (palette.length - 1)) / palette.length;
        for (var index = 0; index < palette.length; index++) {
          final left = sideMargin + index * (cardWidth + cardGap);
          final cardRect = Rect.fromLTWH(
            left,
            paletteTop,
            cardWidth,
            paletteHeight,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(cardRect, const Radius.circular(18)),
            Paint()..color = const Color(0xFF202320),
          );
          final swatchRect = Rect.fromLTWH(
            left + 10,
            paletteTop + 10,
            cardWidth - 20,
            150,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(swatchRect, const Radius.circular(12)),
            Paint()..color = palette[index],
          );
          drawText(
            _hex(palette[index]),
            Offset(left + 8, paletteTop + 180),
            maxWidth: cardWidth - 16,
            fontSize: 22,
            color: const Color(0xFFE6EAE6),
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          );
        }

        canvas.drawLine(
          Offset(sideMargin, paletteTop + paletteHeight + 30),
          Offset(sideMargin + contentWidth, paletteTop + paletteHeight + 30),
          Paint()
            ..color = const Color(0xFF343A35)
            ..strokeWidth = 1,
        );
        drawText(
          'LIVE COLOR PICKER',
          Offset(sideMargin, paletteTop + paletteHeight + 48),
          maxWidth: contentWidth,
          fontSize: 14,
          color: const Color(0xFF788079),
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        );

        final picture = recorder.endRecording();
        try {
          final rendered = await picture.toImage(
            canvasWidth.toInt(),
            canvasHeight,
          );
          try {
            final data = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data == null) {
              throw StateError('Could not encode palette as PNG');
            }
            return data.buffer.asUint8List();
          } finally {
            rendered.dispose();
          }
        } finally {
          picture.dispose();
        }
      } finally {
        photo.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF111312),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 19),
                      color: Colors.white,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.paletteTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.dominantColors.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF9BA39D),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _sharePalette(context, l10n),
                      icon: const Icon(Icons.ios_share_rounded),
                      color: const Color(0xFFD1E8D4),
                      tooltip: l10n.sharePalette,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 7,
                      child: ColoredBox(
                        color: const Color(0xFF222522),
                        child: ClipRect(
                          child: Image.file(
                            File(imagePath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.fitWidth,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white38,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            for (
                              var index = 0;
                              index < colors.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 6),
                              Expanded(
                                child: _PaletteColorCard(
                                  color: colors[index],
                                  hex: _hex(colors[index]),
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _hex(colors[index])),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.copied(
                                            text: _hex(colors[index]),
                                          ),
                                        ),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      color: Color(0xFF9BA39D),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.tapToCopyColor,
                      style: const TextStyle(
                        color: Color(0xFF9BA39D),
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${colors.length.toString().padLeft(2, '0')} / 05',
                      style: const TextStyle(
                        color: Color(0xFF788079),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteColorCard extends StatelessWidget {
  final Color color;
  final String hex;
  final VoidCallback onTap;

  const _PaletteColorCard({
    required this.color,
    required this.hex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF202320),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.content_copy,
                        color: Colors.white70,
                        size: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hex,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE6EAE6),
                  fontSize: 9,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
