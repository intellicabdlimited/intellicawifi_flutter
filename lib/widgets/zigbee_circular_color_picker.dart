import 'dart:math';
import 'package:flutter/material.dart';

/// Circular color wheel for Zigbee xy color space. Same UI as [CircularColorPicker].
class ZigbeeCircularColorPicker extends StatefulWidget {
  final Function(String name, double x, double y) onColorSelected;
  /// Restore last selected color when reopening the picker.
  final double? initialX;
  final double? initialY;

  const ZigbeeCircularColorPicker({
    Key? key,
    required this.onColorSelected,
    this.initialX,
    this.initialY,
  }) : super(key: key);

  @override
  State<ZigbeeCircularColorPicker> createState() => _ZigbeeCircularColorPickerState();
}

class _ZigbeeCircularColorPickerState extends State<ZigbeeCircularColorPicker> {
  static const List<ZigbeeColorSegment> _colors = [
    ZigbeeColorSegment("Red", 0.700, 0.300, Color(0xFFE53935)),
    ZigbeeColorSegment("Green", 0.170, 0.700, Color(0xFF43A047)),
    ZigbeeColorSegment("Blue", 0.150, 0.060, Color(0xFF1E88E5)),
    ZigbeeColorSegment("Orange", 0.620, 0.370, Color(0xFFFB8C00)),
    ZigbeeColorSegment("Yellow", 0.440, 0.500, Color(0xFFFDD835)),
    ZigbeeColorSegment("Purple", 0.270, 0.150, Color(0xFF8E24AA)),
    ZigbeeColorSegment("Pink", 0.380, 0.200, Color(0xFFEC407A)),
    ZigbeeColorSegment("Aqua", 0.240, 0.330, Color(0xFF26C6DA)),
    ZigbeeColorSegment("Red-Orange", 0.650, 0.340, Color(0xFFE64A19)),
    ZigbeeColorSegment("Cyan", 0.170, 0.340, Color(0xFF00ACC1)),
    ZigbeeColorSegment("Spring-Green", 0.300, 0.600, Color(0xFF66BB6A)),
    ZigbeeColorSegment("Violet", 0.250, 0.100, Color(0xFF7B1FA2)),
  ];

  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.initialX != null && widget.initialY != null) {
      double minDist = double.infinity;
      for (int i = 0; i < _colors.length; i++) {
        final dx = _colors[i].x - widget.initialX!;
        final dy = _colors[i].y - widget.initialY!;
        final d = dx * dx + dy * dy;
        if (d < minDist) {
          minDist = d;
          _selectedIndex = i;
        }
      }
    } else {
      _selectedIndex = 0;
    }
  }

  void _handlePan(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final angle = atan2(dy, dx);

    double adjustedAngle = angle + pi / 2;
    if (adjustedAngle < 0) adjustedAngle += 2 * pi;

    final segmentAngle = 2 * pi / _colors.length;
    int index = (adjustedAngle / segmentAngle).round() % _colors.length;
    index = index.clamp(0, _colors.length - 1);

    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      final seg = _colors[index];
      widget.onColorSelected(seg.name, seg.x, seg.y);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: GestureDetector(
        onPanUpdate: (details) {
          _handlePan(details.localPosition, const Size(300, 300));
        },
        onTapDown: (details) {
          _handlePan(details.localPosition, const Size(300, 300));
        },
        child: CustomPaint(
          painter: _ZigbeeColorWheelPainter(
            colors: _colors,
            selectedIndex: _selectedIndex,
          ),
          child: Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor,
                border: Border.all(color: Colors.grey, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                _colors[_selectedIndex].name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ZigbeeColorSegment {
  final String name;
  final double x;
  final double y;
  final Color color;

  const ZigbeeColorSegment(this.name, this.x, this.y, this.color);
}

class _ZigbeeColorWheelPainter extends CustomPainter {
  final List<ZigbeeColorSegment> colors;
  final int selectedIndex;

  _ZigbeeColorWheelPainter({required this.colors, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = 70.0;
    final wheelRadius = radius - strokeWidth / 4;

    final segmentAngle = 2 * pi / colors.length;

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i].color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      final startAngle = (i * segmentAngle) - (pi / 2) - (segmentAngle / 2);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: wheelRadius),
        startAngle,
        segmentAngle,
        false,
        paint,
      );
    }

    final selectionAngle = (selectedIndex * segmentAngle) - (pi / 2);
    final indicatorDistance = wheelRadius + 5;
    final indicatorX = center.dx + indicatorDistance * cos(selectionAngle);
    final indicatorY = center.dy + indicatorDistance * sin(selectionAngle);

    final indicatorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    final indicatorFill = Paint()
      ..color = Colors.transparent
      ..strokeWidth = 5
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(indicatorX, indicatorY), 15, indicatorFill);
    canvas.drawCircle(Offset(indicatorX, indicatorY), 15, indicatorPaint);

    final primaryPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(indicatorX, indicatorY), 15, primaryPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
