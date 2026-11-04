import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _violet = Color(0xFFB9A4F5);
const _deep = Color(0xFF3B2A66);

/// Quét QR và trả về chuỗi thô (mã tham gia hoặc đường dẫn tham gia).
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  bool _handled = false;
  bool _torch = false;

  @override
  void dispose() {
    _scanLine.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {}
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap,
      {bool active = false}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? _violet : Colors.white.withValues(alpha: .16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: active ? _deep : Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final box = math.min(size.width * .68, 280.0);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Không thể mở camera. Hãy cấp quyền camera cho TeamUp trong Cài đặt rồi thử lại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          // Lớp phủ tối có khoảng trống ở giữa.
          CustomPaint(painter: _ScrimPainter(box)),
          // Góc khung + vạch quét.
          Center(
            child: SizedBox(
              width: box,
              height: box,
              child: AnimatedBuilder(
                animation: _scanLine,
                builder: (context, _) => CustomPaint(
                  painter: _FramePainter(_scanLine.value),
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _roundButton(
                  Icons.arrow_back_rounded,
                  'Quay lại',
                  () => Navigator.maybePop(context),
                ),
                const Expanded(
                  child: Text(
                    'Quét mã QR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _roundButton(
                  _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  'Đèn pin',
                  _toggleTorch,
                  active: _torch,
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),
                  child: const Text(
                    'Đặt mã QR của dự án vào giữa khung\nTeamUp sẽ tự nhận diện và tham gia',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _roundButton(
                  Icons.cameraswitch_outlined,
                  'Đổi camera',
                  () => _controller.switchCamera(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.box);
  final double box;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: box,
        height: box,
      ),
      const Radius.circular(32),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = _deep.withValues(alpha: .62));
  }

  @override
  bool shouldRepaint(covariant _ScrimPainter old) => old.box != box;
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 32.0, len = 44.0;
    final corner = Paint()
      ..color = _violet
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final p = Path()
      ..moveTo(0, len)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(len, 0)
      ..moveTo(w - len, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, len)
      ..moveTo(w, h - len)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(w - len, h)
      ..moveTo(len, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, h - len);
    canvas.drawPath(p, corner);

    final y = 18 + (h - 36) * Curves.easeInOut.transform(t);
    final line = Rect.fromLTWH(16, y - 1.5, w - 32, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(line, const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            _violet.withValues(alpha: 0),
            _violet,
            _violet.withValues(alpha: 0),
          ],
        ).createShader(line)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.t != t;
}
