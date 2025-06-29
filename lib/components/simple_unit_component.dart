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
  final double friction = 0.9;

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

  @override
  bool onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is SimpleUnitComponent && other.isPlayer != isPlayer) {
      print('💥 ${unitData.name} hit ${other.unitData.name}!');

      final damage = (unitData.atk * 0.3).round();
      other.unitData.takeDamage(damage);
      print(
        '${other.unitData.name} took $damage damage, HP: ${other.unitData.hp}/${other.unitData.maxHp}',
      );

      // 计算碰撞方向
      final direction = (position - other.position);
      final distance = direction.length;

      print('🔍 Collision details:');
      print('  Distance between units: ${distance.toStringAsFixed(1)}');
      print(
        '  Unit radii: ${radius} + ${other.radius} = ${radius + other.radius}',
      );

      if (distance > 0.1) {
        // 防止除零
        direction.normalize();

        // 立即强制分离单位
        final minSeparation = radius + other.radius + 10; // 增加更多间距
        if (distance < minSeparation) {
          final separationNeeded = minSeparation - distance;
          final separation = direction * (separationNeeded * 0.6); // 分离更多

          // 移动两个单位
          position += separation;
          other.position -= separation;

          print(
            '🔧 Units separated by ${separationNeeded.toStringAsFixed(1)} pixels',
          );
          print(
            '  New positions: ${unitData.name} at $position, ${other.unitData.name} at ${other.position}',
          );
        }

        // 计算反弹速度
        final mySpeed = velocity.length;
        final otherSpeed = other.velocity.length;
        final combinedSpeed = mySpeed + otherSpeed;

        print('🏀 Bounce calculation:');
        print(
          '  My speed: ${mySpeed.toStringAsFixed(1)}, Other speed: ${otherSpeed.toStringAsFixed(1)}',
        );

        // 强制反弹 - 确保有足够的分离速度
        final bounceSpeed = math.max(combinedSpeed * 0.6, 2.0); // 最小反弹速度2.0

        other.velocity = direction * bounceSpeed;
        velocity = direction * -bounceSpeed;

        print(
          '  New velocities: ${unitData.name}=${velocity.length.toStringAsFixed(1)}, ${other.unitData.name}=${other.velocity.length.toStringAsFixed(1)}',
        );

        // 限制最大速度
        if (other.velocity.length > 5.0) {
          other.velocity.normalize();
          other.velocity *= 5.0;
        }
        if (velocity.length > 5.0) {
          velocity.normalize();
          velocity *= 5.0;
        }
      } else {
        // 距离太小时，强制分离
        print('⚠️ Units too close! Force separating...');
        final randomDirection = Vector2(1, 0); // 默认向右分离
        position += randomDirection * 30;
        other.position -= randomDirection * 30;

        velocity = randomDirection * -2.0;
        other.velocity = randomDirection * 2.0;
      }

      return true;
    }
    return false;
  }
}
