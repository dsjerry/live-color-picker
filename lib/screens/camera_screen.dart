import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../generated/app_localizations.dart';
import '../providers/locale_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  Color _detectedColor = Colors.white;
  bool _hasFrame = false;
  String? _error;

  // Zoom state — Ticker continuously eases the preview zoom toward the target
  late final Ticker _zoomTicker;
  double _zoom = 1.0;
  double _zoomTarget = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _scaleBaseZoom = 1.0;
  int _lastZoomTickMicros = 0;
  double _lastAppliedZoom = -1;
  double? _queuedZoom;
  bool _isApplyingZoom = false;

  // Temporal smoothing state
  double _smoothedR = 255, _smoothedG = 255, _smoothedB = 255;
  bool _smoothed = false;
  double _stability = 0.5; // 0 = responsive, 1 = max stable

  double get _smoothingFactor => _stability <= 0
      ? 1.0
      : _stability >= 1
          ? 0.01
          : 1.0 / (1.0 + 99.0 * _stability * _stability);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _zoomTicker = createTicker(_onZoomTick);
    _zoomTicker.start();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoomTicker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller!.dispose();
      _controller = null;
      _isInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = AppLocalizations.of(context).noCameraAvailable);
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      if (!mounted) return;

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _zoom = _minZoom;
      _zoomTarget = _minZoom;
      _lastZoomTickMicros = 0;
      _lastAppliedZoom = -1;
      _queuedZoom = null;
      _isApplyingZoom = false;

      await _controller!.setZoomLevel(_zoom);
      _lastAppliedZoom = _zoom;

      await _controller!.startImageStream(_processImage);

      setState(() => _isInitialized = true);
    } on CameraException catch (e) {
      setState(() => _error = AppLocalizations.of(context).cameraError(description: e.description ?? ''));
    } catch (e) {
      setState(() => _error = AppLocalizations.of(context).cameraInitFailed(error: e.toString()));
    }
  }

  void _processImage(CameraImage image) {
    final raw = _extractColor(image);
    if (!mounted) return;

    final r = (raw.r * 255).round().toDouble();
    final g = (raw.g * 255).round().toDouble();
    final b = (raw.b * 255).round().toDouble();

    if (!_smoothed) {
      _smoothedR = r;
      _smoothedG = g;
      _smoothedB = b;
      _smoothed = true;
    } else {
      _smoothedR = _smoothedR * (1 - _smoothingFactor) + r * _smoothingFactor;
      _smoothedG = _smoothedG * (1 - _smoothingFactor) + g * _smoothingFactor;
      _smoothedB = _smoothedB * (1 - _smoothingFactor) + b * _smoothingFactor;
    }

    setState(() {
      _detectedColor = Color.fromARGB(
        255,
        _smoothedR.round().clamp(0, 255),
        _smoothedG.round().clamp(0, 255),
        _smoothedB.round().clamp(0, 255),
      );
      _hasFrame = true;
    });
  }

  Color _extractColor(CameraImage image) {
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final sampleSize = 5;
    final halfSample = sampleSize ~/ 2;

    int totalR = 0, totalG = 0, totalB = 0;
    int count = 0;

    for (int dy = -halfSample; dy <= halfSample; dy++) {
      for (int dx = -halfSample; dx <= halfSample; dx++) {
        final px = (centerX + dx).clamp(0, image.width - 1);
        final py = (centerY + dy).clamp(0, image.height - 1);

        int r, g, b;
        if (image.format.group == ImageFormatGroup.bgra8888) {
          final plane = image.planes[0];
          final offset = py * plane.bytesPerRow + px * 4;
          final bytes = plane.bytes;
          b = bytes[offset];
          g = bytes[offset + 1];
          r = bytes[offset + 2];
        } else {
          // NV21 / YUV420
          final yPlane = image.planes[0];
          final y = yPlane.bytes[py * yPlane.bytesPerRow + px];

          if (image.planes.length >= 2) {
            final uvPlane = image.planes[1];
            final uvOffset = (py ~/ 2) * uvPlane.bytesPerRow + (px ~/ 2) * 2;
            final v = uvPlane.bytes[uvOffset];
            final u = uvPlane.bytes[uvOffset + 1];

            final yNorm = y - 16;
            final uNorm = u - 128;
            final vNorm = v - 128;

            r = (1.164 * yNorm + 1.596 * vNorm).round().clamp(0, 255);
            g = (1.164 * yNorm - 0.392 * uNorm - 0.813 * vNorm).round().clamp(0, 255);
            b = (1.164 * yNorm + 2.017 * uNorm).round().clamp(0, 255);
          } else {
            // Single-plane NV21: U/V data packed after Y in the same buffer.
            // Y plane bytes contain both Y and interleaved VU data.
            final uvOffset = yPlane.bytesPerRow * image.height +
                (py ~/ 2) * yPlane.bytesPerRow +
                (px ~/ 2) * 2;
            final v = yPlane.bytes[uvOffset];
            final u = yPlane.bytes[uvOffset + 1];

            final yNorm = y - 16;
            final uNorm = u - 128;
            final vNorm = v - 128;

            r = (1.164 * yNorm + 1.596 * vNorm).round().clamp(0, 255);
            g = (1.164 * yNorm - 0.392 * uNorm - 0.813 * vNorm).round().clamp(0, 255);
            b = (1.164 * yNorm + 2.017 * uNorm).round().clamp(0, 255);
          }
        }

        totalR += r;
        totalG += g;
        totalB += b;
        count++;
      }
    }

    return Color.fromARGB(
      255,
      (totalR ~/ count).clamp(0, 255),
      (totalG ~/ count).clamp(0, 255),
      (totalB ~/ count).clamp(0, 255),
    );
  }

  int get _r => (_detectedColor.r * 255).round() & 0xff;
  int get _g => (_detectedColor.g * 255).round() & 0xff;
  int get _b => (_detectedColor.b * 255).round() & 0xff;

  String get hexString =>
      '#${_r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${_g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${_b.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  String get rgbString => 'rgb($_r, $_g, $_b)';

  Future<void> _applyZoom(double zoom) async {
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    if ((_lastAppliedZoom - clamped).abs() < 0.001) return;
    _queuedZoom = clamped;
    if (_isApplyingZoom) return;

    _isApplyingZoom = true;
    while (_queuedZoom != null) {
      final nextZoom = _queuedZoom!;
      _queuedZoom = null;

      if ((_lastAppliedZoom - nextZoom).abs() < 0.001) {
        continue;
      }

      _lastAppliedZoom = nextZoom;

      try {
        final controller = _controller;
        if (controller != null && controller.value.isInitialized) {
          await controller.setZoomLevel(nextZoom);
        }
      } catch (_) {
        break;
      }
    }
    _isApplyingZoom = false;
  }

  void _onZoomTick(Duration elapsed) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final previousTick = _lastZoomTickMicros;
    _lastZoomTickMicros = elapsed.inMicroseconds;
    final dt = previousTick == 0
        ? 1 / 60
        : ((_lastZoomTickMicros - previousTick) / 1000000.0).clamp(0.0, 0.05);

    final error = _zoomTarget - _zoom;
    const followSpeed = 14.0;
    final smoothing = 1 - exp(-followSpeed * dt);
    final nextZoom = lerpDouble(_zoom, _zoomTarget, smoothing)!;
    if ((nextZoom - _zoom).abs() < 0.0001) {
      if (error.abs() < 0.0005 && (_zoomTarget - _lastAppliedZoom).abs() >= 0.001) {
        _applyZoom(_zoomTarget);
      }
      return;
    }
    _zoom = nextZoom;
    _applyZoom(nextZoom);
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SettingsSheet(
        stability: _stability,
        onChanged: (v) => setState(() {
          _stability = v;
          _smoothed = false; // reset smoothing on change
        }),
      ),
    );
  }
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).copied(text: text)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 280,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _error = null);
                  _initCamera();
                },
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cameraAspectRatio = _controller!.value.aspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (pinch-to-zoom)
          Center(
            child: AspectRatio(
              aspectRatio: 1 / cameraAspectRatio,
              child: GestureDetector(
                onScaleStart: (_) => _scaleBaseZoom = _zoomTarget,
                onScaleUpdate: (details) {
                  final curvedScale = pow(details.scale, 0.85).toDouble();
                  final target = (_scaleBaseZoom * curvedScale).clamp(_minZoom, _maxZoom);
                  if ((target - _zoomTarget).abs() < 0.0005) return;
                  _zoomTarget = target;
                },
                child: ClipRect(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(
                      _controller!.description.lensDirection ==
                              CameraLensDirection.front
                          ? pi
                          : 0,
                    ),
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            ),
          ),

          // Settings button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: _showSettings,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune, size: 22, color: Colors.white70),
              ),
            ),
          ),

          // Center crosshair
          Center(
            child: IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _CrosshairPainter(),
              ),
            ),
          ),

          // Color info panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ColorInfoPanel(
              color: _detectedColor,
              hex: hexString,
              rgb: rgbString,
              hasFrame: _hasFrame,
              onCopy: _copyToClipboard,
            ),
          ),
        ],
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = 24.0;
    final outerRingRadius = 28.0;

    // Outer glow ring
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, outerRingRadius, glowPaint);

    // Main ring
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Crosshair lines extending from ring
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    const gap = 32.0;
    const ext = 12.0;

    canvas.drawLine(
      Offset(center.dx, center.dy - gap),
      Offset(center.dx, center.dy - gap - ext),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + gap + ext),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx - gap, center.dy),
      Offset(center.dx - gap - ext, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + gap + ext, center.dy),
      linePaint,
    );

    // Center dot
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ColorInfoPanel extends StatelessWidget {
  final Color color;
  final String hex;
  final String rgb;
  final bool hasFrame;
  final void Function(String) onCopy;

  const _ColorInfoPanel({
    required this.color,
    required this.hex,
    required this.rgb,
    required this.hasFrame,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.95),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color swatch
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: hasFrame ? color : Colors.grey.shade800,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (hasFrame ? color : Colors.grey).withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hex value
          _ColorValueRow(
            label: AppLocalizations.of(context).hexLabel,
            value: hasFrame ? hex : '--',
            onCopy: hasFrame ? () => onCopy(hex) : null,
          ),
          const SizedBox(height: 8),

          // RGB value
          _ColorValueRow(
            label: AppLocalizations.of(context).rgbLabel,
            value: hasFrame ? rgb : '--',
            onCopy: hasFrame ? () => onCopy(rgb) : null,
          ),
        ],
      ),
    );
  }
}

class _ColorValueRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _ColorValueRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(minWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontFamily: 'Courier',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.copy,
                size: 18,
                color: Colors.white70,
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final double stability;
  final ValueChanged<double> onChanged;

  const _SettingsSheet({
    required this.stability,
    required this.onChanged,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.stability;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lp = LocaleScope.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            l10n.stability,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.stabilityDescription,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: Colors.white38),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    value: _value,
                    onChanged: (v) {
                      setState(() => _value = v);
                      widget.onChanged(v);
                    },
                  ),
                ),
              ),
              const Icon(Icons.lock, size: 18, color: Colors.white38),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.responsive,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
              Text(l10n.stable,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
            ],
          ),

          const SizedBox(height: 32),

          // Language section
          Text(
            l10n.languageLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _LanguageOption(
            label: l10n.systemLanguage,
            selected: lp.locale == null,
            onTap: () => lp.setLocale(null),
          ),
          _LanguageOption(
            label: l10n.languageEnglish,
            selected: lp.locale?.languageCode == 'en',
            onTap: () => lp.setLocale('en'),
          ),
          _LanguageOption(
            label: l10n.languageChinese,
            selected: lp.locale?.languageCode == 'zh',
            onTap: () => lp.setLocale('zh'),
          ),
        ],
      ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: selected ? 0.9 : 0.5),
                  fontSize: 16,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 20, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
