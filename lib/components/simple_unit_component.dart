import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/battle_unit.dart';

class SimpleUnitComponent extends CircleComponent with CollisionCallbacks {
  final BattleUnit unitData;
  final bool isPlayer;
  bool hasBeenUsedThisTurn = false;

  late TextComponent nameComponent;
  late TextComponent hpComponent;
  @override
  double radius = 20.0;

  Vector2 velocity = Vector2.zero();
  final double friction = 0.98;

  // 瞄准状态
  bool isAiming = false;
  Vector2? dragEndPosition;
  static const double maxDragDistance = 120.0;

  SimpleUnitComponent({
    required this.unitData,
    required this.isPlayer,
    required Vector2 position,
    double radius = 25,
  }) : super(
         radius: radius,
         position: position,
         anchor: Anchor.center,
         paint: Paint()
           ..color = const Color(
             0x00000000,
           ), // Transparent to hide default circle
       );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 显著增大碰撞检测区域
    add(CircleHitbox(radius: radius * 1.5)); // 比视觉半径大50%

    print(
      '🔧 Unit ${unitData.name} loaded at ${position} with hitbox radius: ${radius * 1.5}',
    );

    nameComponent = TextComponent(
      text: unitData.name,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: Vector2.zero(), // Center the emoji in the unit
    );
    add(nameComponent);

    hpComponent = TextComponent(
      text: '${unitData.hp}',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(0, radius + 20), // Position below the unit
    );
    add(hpComponent);
  }

  void launch(Vector2 force) {
    velocity = force;
    print('Unit ${unitData.name} launched with velocity: $velocity');
  }

  @override
  void update(double dt) {
    super.update(dt);

    hpComponent.text = '${unitData.hp}';

    if (velocity.length > 0.5) {
      final oldPosition = position.clone();
      position += velocity * dt * 80;
      velocity *= friction;

      final gameSize = findGame()?.size ?? Vector2(800, 600);

      if (position.x < radius) {
        position.x = radius;
        velocity.x *= -unitData.elasticity;
        print('${unitData.name} hit left wall');
      }
      if (position.x > gameSize.x - radius) {
        position.x = gameSize.x - radius;
        velocity.x *= -unitData.elasticity;
        print('${unitData.name} hit right wall');
      }
      if (position.y < radius) {
        position.y = radius;
        velocity.y *= -unitData.elasticity;
        print('${unitData.name} hit top wall');
      }
      if (position.y > gameSize.y - radius) {
        position.y = gameSize.y - radius;
        velocity.y *= -unitData.elasticity;
        print('${unitData.name} hit bottom wall');
      }

      if ((position - oldPosition).length > 0.1) {
        print(
          '${unitData.name} moved from $oldPosition to $position, velocity: ${velocity.length.toStringAsFixed(2)}',
        );
      }
    } else {
      if (velocity.length > 0) {
        print('${unitData.name} stopped moving');
      }
      velocity = Vector2.zero();
    }
  }

  @override
  void render(Canvas canvas) {
    // Don't call super.render(canvas) to prevent default CircleComponent rendering

    if (isAiming) {
      _drawAimingIndicator(canvas);
    }

    Color unitColor;
    switch (unitData.unitClass) {
      case UnitClass.tank:
        unitColor = Colors.blue;
        break;
      case UnitClass.mage:
        unitColor = Colors.purple;
        break;
      case UnitClass.archer:
        unitColor = Colors.green;
        break;
      case UnitClass.warrior:
        unitColor = Colors.red;
        break;
      case UnitClass.support:
        unitColor = Colors.yellow;
        break;
    }

    if (!isPlayer) {
      unitColor = unitColor.withValues(alpha: 0.7);
    }

    // 绘制可操作单位的动态外圈指示器
    if (isPlayer && !hasBeenUsedThisTurn) {
      final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final pulseScale = 1.0 + 0.2 * (0.5 + 0.5 * math.sin(time * 3.0)); // 脉动效果
      final outerRadius = radius * pulseScale + 8;

      final selectionPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(Offset.zero, outerRadius, selectionPaint);
    }

    // Draw main unit circle
    final paint = Paint()
      ..color = unitColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, radius, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = hasBeenUsedThisTurn ? Colors.grey : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset.zero, radius, borderPaint);

    // Health bar below the unit
    final hpRatio = unitData.hp / unitData.maxHp;
    final hpBarWidth = radius * 1.8;
    final hpBarHeight = 6.0;
    final hpBarY = radius + 5;

    // Health bar background
    final hpBackgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-hpBarWidth / 2, hpBarY, hpBarWidth, hpBarHeight),
        const Radius.circular(3),
      ),
      hpBackgroundPaint,
    );

    // Health bar fill
    final hpFillPaint = Paint()
      ..color = hpRatio > 0.5
          ? Colors.green
          : (hpRatio > 0.25 ? Colors.orange : Colors.red)
      ..style = PaintingStyle.fill;

    if (hpRatio > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -hpBarWidth / 2,
            hpBarY,
            hpBarWidth * hpRatio,
            hpBarHeight,
          ),
          const Radius.circular(3),
        ),
        hpFillPaint,
      );
    }

    // Don't call super.render(canvas) - this prevents the white circle
  }

  void _drawAimingIndicator(Canvas canvas) {
    if (dragEndPosition == null) return;

    // 瞄准方向是拖拽的反方向 (从单位中心指向拖拽点)
    final indicatorDirection = position - dragEndPosition!;
    final distance = indicatorDirection.length;

    // 设置最大拖拽距离限制
    final clampedDistance = distance.clamp(0.0, maxDragDistance);
    final isAtMaxDistance = distance >= maxDragDistance;

    if (clampedDistance > 10) {
      final normalizedDirection = indicatorDirection.normalized();

      // 计算力度百分比 (0.0 到 1.0)
      final forceRatio = clampedDistance / maxDragDistance;

      // 根据力度调整颜色 - 绿色到红色渐变
      final color =
          Color.lerp(Colors.green, Colors.red, forceRatio) ?? Colors.orange;

      // 根据力度调整透明度
      final alpha = (0.7 + forceRatio * 0.3).clamp(0.7, 1.0);
      final trajectoryColor = color.withAlpha((alpha * 255).toInt());

      // 计算指示器起点 - 从圆形边缘开始 (本地坐标系中，圆心是0,0)
      final lineStartPos = normalizedDirection * radius;

      // 计算指示器长度
      final lineLength = clampedDistance * 1.2;

      // 绘制左右两条平行线
      final perpendicular = Vector2(
        -normalizedDirection.y,
        normalizedDirection.x,
      );
      final lineOffset = 12.0;

      final leftLineStart = lineStartPos + perpendicular * lineOffset;
      final leftLineEnd = leftLineStart + normalizedDirection * lineLength;
      final rightLineStart = lineStartPos - perpendicular * lineOffset;
      final rightLineEnd = rightLineStart + normalizedDirection * lineLength;

      final linePaint = Paint()
        ..color = trajectoryColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // 左边线
      canvas.drawLine(
        leftLineStart.toOffset(),
        leftLineEnd.toOffset(),
        linePaint,
      );

      // 右边线
      canvas.drawLine(
        rightLineStart.toOffset(),
        rightLineEnd.toOffset(),
        linePaint,
      );

      // 在两条线之间绘制箭头装饰
      final numIndicators = (lineLength / 30).round().clamp(3, 6);
      for (int i = 1; i <= numIndicators; i++) {
        final t = i / (numIndicators + 1);
        final indicatorPos =
            lineStartPos + normalizedDirection * lineLength * t;
        _drawIndicatorPattern(
          canvas,
          indicatorPos,
          normalizedDirection,
          trajectoryColor,
        );
      }

      // 绘制力度指示器 (单位本地坐标系中，圆心是0,0)
      _drawForceIndicator(canvas, Vector2.zero(), forceRatio, isAtMaxDistance);
    }
  }

  void _drawIndicatorPattern(
    Canvas canvas,
    Vector2 position,
    Vector2 direction,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arrowSize = 5.0;
    final perpendicular = Vector2(-direction.y, direction.x);

    // ^ 箭头在两条线中间，沿轨迹方向
    final arrowTip = position + direction * arrowSize;
    final arrowLeft = position + perpendicular * arrowSize * 0.6;
    final arrowRight = position - perpendicular * arrowSize * 0.6;

    // 绘制 ^ 的左边
    canvas.drawLine(arrowLeft.toOffset(), arrowTip.toOffset(), paint);

    // 绘制 ^ 的右边
    canvas.drawLine(arrowTip.toOffset(), arrowRight.toOffset(), paint);
  }

  void _drawForceIndicator(
    Canvas canvas,
    Vector2 unitPos,
    double forceRatio,
    bool isAtMax,
  ) {
    // 在单位旁边绘制力度条 (unitPos is Vector2.zero in local space)
    final barWidth = 60.0;
    final barHeight = 8.0;
    final barPos = Vector2(unitPos.x - barWidth / 2, unitPos.y - radius - 25);

    // 背景条
    final bgPaint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barPos.x, barPos.y, barWidth, barHeight),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // 力度填充条
    final fillColor = isAtMax
        ? Colors.red
        : Color.lerp(Colors.green, Colors.orange, forceRatio);
    final fillPaint = Paint()
      ..color = fillColor ?? Colors.orange
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          barPos.x + 2,
          barPos.y + 2,
          (barWidth - 4) * forceRatio,
          barHeight - 4,
        ),
        const Radius.circular(2),
      ),
      fillPaint,
    );

    // 最大力度警告
    if (isAtMax) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'MAX',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(barPos.x + barWidth / 2 - textPainter.width / 2, barPos.y - 15),
      );
    }
  }

  @override
  bool onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is SimpleUnitComponent && other.isPlayer != isPlayer) {
      // 确保物理和伤害计算只由一方发起，防止重复计算
      if (isPlayer) {
        // 伤害计算
        print('💥 ${unitData.name} hit ${other.unitData.name}!');
        final damage = (unitData.atk * 0.1).round();
        other.unitData.takeDamage(damage);
        print(
          '${other.unitData.name} took $damage damage, HP: ${other.unitData.hp}/${other.unitData.maxHp}',
        );

        // --- 物理计算 ---

        // 1. 计算碰撞向量和距离
        final direction = (position - other.position);
        final distance = direction.length;

        // 2. 正确的穿透解析 (核心修复)
        if (distance > 0.1) {
          final hitboxRadius = radius * 1.5;
          final otherHitboxRadius = other.radius * 1.5;
          final penetration = (hitboxRadius + otherHitboxRadius) - distance;

          if (penetration > 0) {
            direction.normalize();
            // 沿碰撞方向将两个单位推开，解决重叠问题
            final correction = direction * (penetration + 1.0); // 增加缓冲
            position += correction / 2;
            other.position -= correction / 2;
            print(
              '🔧 Penetration resolved by ${penetration.toStringAsFixed(1)} pixels',
            );
          }

          // 3. 基于动量守恒的2D弹性碰撞 (桌球物理)
          final normal = (position - other.position).normalized();
          final tangent = Vector2(-normal.y, normal.x);

          // 将速度投影到法线和切线
          final v1nScalar = velocity.dot(normal);
          final v1tScalar = velocity.dot(tangent);
          final v2nScalar = other.velocity.dot(normal);

          // 质量
          final m1 = unitData.mass;
          final m2 = other.unitData.mass;

          // 沿法线方向进行一维弹性碰撞计算
          final v1nFinalScalar =
              (v1nScalar * (m1 - m2) + 2 * m2 * v2nScalar) / (m1 + m2);
          final v2nFinalScalar =
              (v2nScalar * (m2 - m1) + 2 * m1 * v1nScalar) / (m1 + m2);

          // 将标量速度转换回矢量
          final v1nFinal = normal * v1nFinalScalar;
          final v1tFinal = tangent * v1tScalar; // 切线速度不变
          final v2nFinal = normal * v2nFinalScalar;
          final v2tFinal = tangent * other.velocity.dot(tangent); // 切线速度不变

          // 组合最终速度
          velocity = v1nFinal + v1tFinal;
          other.velocity = v2nFinal + v2tFinal;

          print('🏀 Momentum exchange complete!');
          print(
            '  New velocities: ${unitData.name}=${velocity.length.toStringAsFixed(1)}, ${other.unitData.name}=${other.velocity.length.toStringAsFixed(1)}',
          );
        } else {
          // 距离太小时，强制分离
          print('⚠️ Units too close! Force separating...');
          final randomDirection = Vector2(1, 0); // 默认向右分离
          position += randomDirection * 30;
          other.position -= randomDirection * 30;

          velocity = randomDirection * -2.0;
          other.velocity = randomDirection * 2.0;
        }
      }

      return true;
    }
    return false;
  }
}
