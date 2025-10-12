import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';

/// Custom van marker widget for map display
/// Shows a detailed top-view van with rotation based on heading
class VanMarker extends StatelessWidget {
  final double heading; // Vehicle heading in degrees (0 = North, 90 = East)
  final VanStatus status;
  final double size;
  final bool showPulse;

  const VanMarker({
    super.key,
    this.heading = 0,
    this.status = VanStatus.active,
    this.size = 48,
    this.showPulse = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse effect
          if (showPulse)
            _PulseRing(
              size: size,
              color: _getStatusColor(status),
            ),

          // Rotated van icon
          Transform.rotate(
            angle: heading * (math.pi / 180), // Convert degrees to radians
            child: SvgPicture.asset(
              'assets/images/van_top_view.svg',
              width: size,
              height: size,
              // colorFilter parameter removed - using original SVG colors
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(VanStatus status) {
    switch (status) {
      case VanStatus.active:
        return Colors.green;
      case VanStatus.idle:
        return Colors.orange;
      case VanStatus.stopped:
        return Colors.red;
      case VanStatus.offline:
        return Colors.grey;
    }
  }
}

/// Simple van marker using custom paint (alternative to SVG)
class VanMarkerPainted extends StatelessWidget {
  final double heading;
  final VanStatus status;
  final double size;

  const VanMarkerPainted({
    super.key,
    this.heading = 0,
    this.status = VanStatus.active,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * (math.pi / 180),
      child: CustomPaint(
        size: Size(size, size),
        painter: _VanPainter(status: status),
      ),
    );
  }
}

class _VanPainter extends CustomPainter {
  final VanStatus status;

  _VanPainter({required this.status});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = _getVanColor(status);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final vanWidth = size.width * 0.5;
    final vanLength = size.height * 0.7;

    // Main van body
    final vanRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: vanWidth,
        height: vanLength,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(vanRect, paint);
    canvas.drawRRect(vanRect, strokePaint);

    // Cabin (front of van)
    final cabinPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _getVanColor(status).withValues(alpha: 0.8);

    final cabinRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - vanLength * 0.35),
        width: vanWidth * 0.8,
        height: vanLength * 0.2,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(cabinRect, cabinPaint);
    canvas.drawRRect(cabinRect, strokePaint);

    // Side mirrors
    final mirrorPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black87;

    canvas.drawCircle(
      Offset(center.dx - vanWidth * 0.6, center.dy - vanLength * 0.15),
      3,
      mirrorPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + vanWidth * 0.6, center.dy - vanLength * 0.15),
      3,
      mirrorPaint,
    );

    // Direction arrow
    final arrowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final arrowPath = Path()
      ..moveTo(center.dx, center.dy - vanLength * 0.25)
      ..lineTo(center.dx, center.dy - vanLength * 0.4)
      ..moveTo(center.dx, center.dy - vanLength * 0.4)
      ..lineTo(center.dx - 4, center.dy - vanLength * 0.35)
      ..moveTo(center.dx, center.dy - vanLength * 0.4)
      ..lineTo(center.dx + 4, center.dy - vanLength * 0.35);

    canvas.drawPath(arrowPath, arrowPaint);

    // Status indicator
    final statusPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _getStatusIndicatorColor(status);

    canvas.drawCircle(center, 4, statusPaint);
    canvas.drawCircle(center, 4, strokePaint);
  }

  Color _getVanColor(VanStatus status) {
    switch (status) {
      case VanStatus.active:
        return const Color(0xFF2563EB); // Blue
      case VanStatus.idle:
        return const Color(0xFFF59E0B); // Orange
      case VanStatus.stopped:
        return const Color(0xFFEF4444); // Red
      case VanStatus.offline:
        return const Color(0xFF6B7280); // Gray
    }
  }

  Color _getStatusIndicatorColor(VanStatus status) {
    switch (status) {
      case VanStatus.active:
        return const Color(0xFF10B981); // Green
      case VanStatus.idle:
        return const Color(0xFFFBBF24); // Yellow
      case VanStatus.stopped:
        return const Color(0xFFDC2626); // Red
      case VanStatus.offline:
        return const Color(0xFF9CA3AF); // Light gray
    }
  }

  @override
  bool shouldRepaint(_VanPainter oldDelegate) => oldDelegate.status != status;
}

/// Pulse ring animation for live tracking
class _PulseRing extends StatefulWidget {
  final double size;
  final Color color;

  const _PulseRing({
    required this.size,
    required this.color,
  });

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
          size: Size(widget.size * 1.5, widget.size * 1.5),
          painter: _PulseRingPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulseRingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final radius = maxRadius * 0.3 + (maxRadius * 0.7 * progress);
    final opacity = 1.0 - progress;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: opacity * 0.5)
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_PulseRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Van tracking status
enum VanStatus {
  active,   // Moving and transmitting
  idle,     // Stationary but job running
  stopped,  // Job stopped/paused
  offline,  // Not transmitting location
}

/// Helper to determine van status from location data
class VanStatusHelper {
  static VanStatus getStatus({
    required bool isTracking,
    required int lastUpdateSecondsAgo,
    required bool isMoving,
  }) {
    if (!isTracking) {
      return VanStatus.stopped;
    }

    if (lastUpdateSecondsAgo > 120) {
      return VanStatus.offline;
    }

    if (isMoving) {
      return VanStatus.active;
    }

    return VanStatus.idle;
  }
}
