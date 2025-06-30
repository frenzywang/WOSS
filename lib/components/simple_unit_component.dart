import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/battle_unit.dart';
import 'wall_component.dart';
import '../game/simple_marble_game.dart';

class SimpleUnitComponent extends CircleComponent with CollisionCallbacks {
  final BattleUnit unitData;
  final bool isPlayer;
  bool hasBeenUsedThisTurn = false;

  late TextComponent nameComponent;
  late TextComponent hpComponent;

  Vector2 velocity = Vector2.zero();
  final double friction = 0.98;

  // 瞄准状态
  bool isAiming = false;
  Vector2? dragEndPosition;
  static const double maxDragDistance = 120.0;

  // 🔧 统一的半径常量，保证所有地方一致
  static const double unitRadius = 25.0;
  // 实际碰撞检测半径（与CircleHitbox保持一致）
  static const double collisionRadius = unitRadius * 1.5; // 37.5

  SimpleUnitComponent({
    required this.unitData,
    required this.isPlayer,
    required Vector2 position,
    double radius = unitRadius,
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

    // 🔧  尝试关闭Flame物理引擎的干扰 - 使用与视觉相同的半径
    add(CircleHitbox(radius: unitRadius));

    print(
      '🔧 Unit ${unitData.name} loaded at $position with hitbox radius: ${radius * 1.5}, visual radius: $radius',
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
      position: Vector2(0, unitRadius + 20), // 使用统一的半径常量
    );
    add(hpComponent);
  }

  void launch(Vector2 force) {
    velocity = force;
  }

  @override
  void update(double dt) {
    super.update(dt);

    hpComponent.text = '${unitData.hp}';

    // 移动逻辑
    if (velocity.length > 0.5) {
      // 保存移动前的位置
      final oldPosition = position.clone();

      // 大幅降低速度倍数，防止疯狂弹射
      position += velocity * dt * 30;
      velocity *= 0.95;

      // 🔧 添加边界检测 - 确保角色不会超出边界
      final clampedPosition = _clampPosition(position);

      // 如果位置被限制，说明撞到了边界，停止相应方向的速度
      if (clampedPosition.x != position.x) {
        velocity.x = 0; // 撞到左右边界，停止水平速度
      }
      if (clampedPosition.y != position.y) {
        velocity.y = 0; // 撞到上下边界，停止垂直速度
      }

      position.setFrom(clampedPosition);

      // 停止速度过低的移动
      if (velocity.length < 5.0) {
        velocity = Vector2.zero();
      }
    } else {
      velocity = Vector2.zero();
    }

    // 无论是否移动，都要进行边界检测
    final clampedPosition = _clampPosition(position);
    if (clampedPosition.x != position.x || clampedPosition.y != position.y) {
      position.setFrom(clampedPosition);
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
      final outerRadius = unitRadius * pulseScale + 8;

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

    canvas.drawCircle(Offset.zero, unitRadius, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = hasBeenUsedThisTurn ? Colors.grey : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset.zero, unitRadius, borderPaint);

    // Health bar below the unit
    final hpRatio = unitData.hp / unitData.maxHp;
    final hpBarWidth = unitRadius * 1.8;
    final hpBarHeight = 6.0;
    final hpBarY = unitRadius + 5;

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
      final lineStartPos = normalizedDirection * unitRadius;

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
    final barPos = Vector2(
      unitPos.x - barWidth / 2,
      unitPos.y - unitRadius - 25,
    );

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

  Vector2 _clampPosition(Vector2 pos) {
    final game = findGame();
    if (game is! SimpleMarbleBattleGame) return pos;

    final boundary = (game as SimpleMarbleBattleGame).boundary;

    // 🔧 直接检查单位边缘，而不是圆心
    final unitLeft = pos.x - unitRadius;
    final unitRight = pos.x + unitRadius;
    final unitTop = pos.y - unitRadius;
    final unitBottom = pos.y + unitRadius;

    // 🔧 直接调整圆心位置，确保边缘不超出
    var newX = pos.x;
    var newY = pos.y;

    // 🔧 确保边缘在边界内 + 安全边距（使用半径作为安全边距更合理）
    final safetyMargin = unitRadius; // 25.0像素，让单位离边界一个半径的距离

    if (unitLeft < boundary.left + safetyMargin) {
      newX = boundary.left + unitRadius + safetyMargin;
    }
    if (unitRight > boundary.right - safetyMargin) {
      newX = boundary.right - unitRadius - safetyMargin;
    }
    if (unitTop < boundary.top + safetyMargin) {
      newY = boundary.top + unitRadius + safetyMargin;
    }
    if (unitBottom > boundary.bottom - safetyMargin) {
      newY = boundary.bottom - unitRadius - safetyMargin;
    }

    return Vector2(newX, newY);
  }

  @override
  bool onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    // 只处理单位间碰撞，边界碰撞由update方法处理
    if (other is SimpleUnitComponent && other.isPlayer != isPlayer) {
      // 简化单位间碰撞
      if (unitData.hp <= 0 || other.unitData.hp <= 0) {
        return false;
      }

      if (isPlayer) {
        // 伤害计算
        final damage = (unitData.atk * 0.1).round();
        other.unitData.takeDamage(damage);
        print(
          '💥 ${unitData.name} hit ${other.unitData.name} for $damage damage',
        );

        // 强化单位分离，防止重叠卡住
        final direction = (position - other.position);
        if (direction.length > 0.1) {
          final normalizedDirection = direction.normalized();
          final separationDistance =
              unitRadius * 0.5; // Use a smaller, more gentle separation

          // Calculate potential new positions
          final newThisPos =
              position + normalizedDirection * separationDistance;
          final newOtherPos =
              other.position - normalizedDirection * separationDistance;

          // Clamp positions to boundaries BEFORE applying them
          position.setFrom(_clampPosition(newThisPos));
          other.position.setFrom(
            (other as SimpleUnitComponent)._clampPosition(newOtherPos),
          );

          print(
            '🔧 单位分离: ${unitData.name} -> $position, ${other.unitData.name} -> ${other.position}',
          );
        }

        // 简单的速度交换，降低强度
        final tempVelocity = velocity * 0.3;
        velocity = other.velocity * 0.3;
        other.velocity = tempVelocity;

        print('🏀 Simple collision resolved');
      }

      return true;
    }
    return false;
  }
}
