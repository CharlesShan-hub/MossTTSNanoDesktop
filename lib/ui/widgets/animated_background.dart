import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _OrbsPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _OrbsPainter extends CustomPainter {
  final double animation;
  final List<_Orb> _orbs = [];
  final math.Random _random = math.Random();

  _OrbsPainter(this.animation) {
    // 创建几个光球
    _orbs.addAll([
      _Orb(
        color: const Color(0xFF4A7DA8).withOpacity(0.15),
        size: 200,
        speed: 0.5,
        offset: const Offset(0.2, 0.3),
      ),
      _Orb(
        color: const Color(0xFF8A5FAD).withOpacity(0.12),
        size: 250,
        speed: 0.7,
        offset: const Offset(0.7, 0.5),
      ),
      _Orb(
        color: const Color(0xFF4A9E62).withOpacity(0.1),
        size: 180,
        speed: 0.6,
        offset: const Offset(0.5, 0.8),
      ),
      _Orb(
        color: const Color(0xFFD48C30).withOpacity(0.13),
        size: 160,
        speed: 0.8,
        offset: const Offset(0.3, 0.7),
      ),
    ]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in _orbs) {
      // 计算移动位置
      final x = (math.sin(animation * math.pi * 2 * orb.speed + orb.offset.dx) * 0.5 + 0.5) * size.width;
      final y = (math.cos(animation * math.pi * 2 * orb.speed * 0.8 + orb.offset.dy) * 0.5 + 0.5) * size.height;
      
      final paint = Paint()
        ..color = orb.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

      canvas.drawCircle(
        Offset(x, y),
        orb.size / 2,
        paint,
      );
    }

    // 绘制一些波浪效果
    _drawWaves(canvas, size);
  }

  void _drawWaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final y = size.height * (0.6 + i * 0.1);
      
      path.moveTo(0, y);
      
      for (double x = 0; x <= size.width; x += 10) {
        final waveY = y + 
            math.sin((x / 100) + (animation * math.pi * 2) + i * 0.5) * 20;
        path.lineTo(x, waveY);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbsPainter oldDelegate) => oldDelegate.animation != animation;
}

class _Orb {
  final Color color;
  final double size;
  final double speed;
  final Offset offset;

  _Orb({
    required this.color,
    required this.size,
    required this.speed,
    required this.offset,
  });
}
