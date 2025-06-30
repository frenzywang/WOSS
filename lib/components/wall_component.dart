import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

abstract class BoundaryComponent extends PositionComponent
    with CollisionCallbacks {
  Color get color => Colors.cyan.withValues(alpha: 0.8);
  double get thickness => 6.0;
  double get hitboxThickness => 24.0;

  @override
  void render(Canvas canvas) {
    renderBoundary(canvas);
  }

  void renderBoundary(Canvas canvas);
  Vector2 getNormalAt(Vector2 point);
}

class WallComponent extends BoundaryComponent {
  final Vector2 start;
  final Vector2 end;
  late final Vector2 _normal;

  WallComponent(this.start, this.end) : super() {
    anchor = Anchor.center;
    position = (start + end) / 2;
    size = Vector2((end - start).length, hitboxThickness);
    angle = (end - start).screenAngle();

    final tangent = (end - start).normalized();
    _normal = Vector2(-tangent.y, tangent.x);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(RectangleHitbox(size: Vector2(size.x, hitboxThickness)));
    print('🔧 Wall hitbox created: ${size.x} x $hitboxThickness at $position');
  }

  @override
  void renderBoundary(Canvas canvas) {
    // 不绘制任何内容，只用于碰撞检测
    // 视觉效果由游戏主类直接绘制
  }

  Vector2 get normal => _normal;

  @override
  Vector2 getNormalAt(Vector2 point) => _normal;
}

class CircularBoundaryComponent extends BoundaryComponent {
  @override
  final Vector2 center;
  final double radius;
  final int segments;

  CircularBoundaryComponent(this.center, this.radius, {this.segments = 32})
    : super() {
    position = center;
    size = Vector2.all(radius * 2);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(CircleHitbox(radius: radius));
  }

  @override
  void renderBoundary(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    // Draw outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset.zero, radius, glowPaint);
    canvas.drawCircle(Offset.zero, radius, paint);
  }

  @override
  Vector2 getNormalAt(Vector2 point) {
    return (point - center).normalized();
  }
}

class RectangularBoundaryComponent extends BoundaryComponent {
  final Vector2 topLeft;
  final Vector2 bottomRight;
  final double cornerRadius;

  RectangularBoundaryComponent(
    this.topLeft,
    this.bottomRight, {
    this.cornerRadius = 0,
  }) : super() {
    position = (topLeft + bottomRight) / 2;
    size = bottomRight - topLeft;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    if (cornerRadius > 0) {
      add(RectangleHitbox());
    } else {
      add(RectangleHitbox());
    }
  }

  @override
  void renderBoundary(Canvas canvas) {
    final rect = Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, size.y);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    // Draw outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    if (cornerRadius > 0) {
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(cornerRadius),
      );
      canvas.drawRRect(rrect, glowPaint);
      canvas.drawRRect(rrect, paint);
    } else {
      canvas.drawRect(rect, glowPaint);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  Vector2 getNormalAt(Vector2 point) {
    final localPoint = point - position;
    final halfSize = size / 2;

    // Determine which edge is closest
    final dx = localPoint.x.abs() - halfSize.x;
    final dy = localPoint.y.abs() - halfSize.y;

    if (dx > dy) {
      return Vector2(localPoint.x > 0 ? 1 : -1, 0);
    } else {
      return Vector2(0, localPoint.y > 0 ? 1 : -1);
    }
  }
}
