
import 'dart:math';

import 'package:flutter/material.dart';

class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key, required this.title});

  final String title;

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  List<Offset> points = [];
  final Random _random = Random();
  final int zigs = 10;
  final double width = 3.0;

  @override
  void initState() {
    super.initState();
  }

  void _paintZigZagLine() {
    setState(() {
      points.add(
        Offset(_random.nextDouble() * 400, _random.nextDouble() * 400),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(400, 400),
              painter: ZigZagLinePainter(
                points: points,
                zigs: zigs,
                color: Colors.deepPurple,
                width: width,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _paintZigZagLine,
        tooltip: 'Paint',
        child: const Icon(Icons.brush),
      ),
    );
  }
}

class ZigZagLinePainter extends CustomPainter {
  final List<Offset> points;
  final int zigs;
  final Color color;
  final double width;

  ZigZagLinePainter({
    required this.points,
    required this.zigs,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final Path path = Path()..moveTo(points[0].dx, points[0].dy);

    for (int seg = 0; seg < points.length - 1; seg++) {
      final Offset start = points[seg];
      final Offset end = points[seg + 1];
      final double dx = end.dx - start.dx;
      final double dy = end.dy - start.dy;

      for (int i = 1; i <= zigs; i++) {
        final double t = i / zigs;
        final double xOffset = dx * t;
        final double yOffset = dy * t;
        final double perpendicularX = -dy;
        final double perpendicularY = dx;
        final double magnitude = sqrt(
          perpendicularX * perpendicularX + perpendicularY * perpendicularY,
        );
        final double normalizedX = perpendicularX / magnitude;
        final double normalizedY = perpendicularY / magnitude;
        final double zigZagOffset = (i % 2 == 0) ? 20 : -20;

        path.lineTo(
          start.dx + xOffset + normalizedX * zigZagOffset,
          start.dy + yOffset + normalizedY * zigZagOffset,
        );
      }

      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ZigZagLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.zigs != zigs ||
        oldDelegate.color != color ||
        oldDelegate.width != width;
  }
}
