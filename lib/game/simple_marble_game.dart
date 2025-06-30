import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/game_state.dart';
import '../models/battle_unit.dart';
import '../components/simple_unit_component.dart';
import '../components/wall_component.dart';

class SimpleMarbleBattleGame extends FlameGame
    with PanDetector, TapDetector, HasCollisionDetection {
  List<SimpleUnitComponent> playerUnits = [];
  List<SimpleUnitComponent> enemyUnits = [];
  GameState gameState = GameState.waitingForInput;

  // 拖拽相关变量
  SimpleUnitComponent? selectedUnit;
  Vector2? dragStart;
  Vector2? dragCurrent;

  // 游戏常量
  static const double maxDragDistance = 120.0;

  // 简化的边界变量
  late Rect boundary;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    print('Game loaded, state: $gameState');
    print('Game size: $size');

    await _setupSimpleBoundary();
    await _setupUnits();

    camera.viewfinder.visibleGameSize = size;

    print('Game setup complete! Collision detection enabled.');
  }

  Future<void> _setupSimpleBoundary() async {
    // 创建一个简单的矩形边界，完全移除WallComponent
    final margin = 60.0;
    boundary = Rect.fromLTWH(
      margin,
      margin,
      size.x - margin * 2,
      size.y - margin * 2,
    );

    print(
      '📦 Simple boundary created: ${boundary.left}, ${boundary.top}, ${boundary.width}, ${boundary.height}',
    );
    print(
      '📦 边界范围: 左=${boundary.left}, 上=${boundary.top}, 右=${boundary.right}, 下=${boundary.bottom}',
    );

    // 移除所有之前的墙体组件 - 不再需要
    children.whereType<WallComponent>().toList().forEach(
      (wall) => wall.removeFromParent(),
    );

    // 不再创建WallComponent，直接使用边界检测
    print('✅ 使用直接边界检测，无虚空墙体');
  }

  Future<void> _setupUnits() async {
    playerUnits.clear();
    enemyUnits.clear();

    print('🎮 Setting up units with boundary: $boundary');

    // 确保单位在边界中心区域，远离墙体
    final centerX = boundary.center.dx;
    final centerY = boundary.center.dy;
    final safeMargin = 100.0; // 增大安全边距，从60增到100

    print('边界中心: ($centerX, $centerY)');
    print('安全边距: $safeMargin');

    // Create player units - 在下方安全区域
    for (int i = 0; i < 2; i++) {
      final unitData = i == 0
          ? BattleUnit(
              id: 'player1',
              name: '🛡️',
              unitClass: UnitClass.tank,
              hp: 150,
              maxHp: 150,
              atk: 30,
              mass: 10.0,
              elasticity: 0.3,
            )
          : BattleUnit(
              id: 'player2',
              name: '🏹',
              unitClass: UnitClass.archer,
              hp: 80,
              maxHp: 80,
              atk: 60,
              mass: 5.0,
              elasticity: 0.3,
            );

      // 确保单位在边界内部的安全区域
      final unitPosition = Vector2(
        centerX - 50 + (i * 100), // 更宽的水平间距
        centerY + 80, // 在中心下方，但不贴近底边
      );

      // 验证位置是否安全
      print('玩家单位 $i 位置: $unitPosition');
      print(
        '距离边界: 左${unitPosition.x - boundary.left}, 右${boundary.right - unitPosition.x}, 上${unitPosition.y - boundary.top}, 下${boundary.bottom - unitPosition.y}',
      );

      final unit = SimpleUnitComponent(
        unitData: unitData,
        isPlayer: true,
        position: unitPosition,
      );

      add(unit);
      playerUnits.add(unit);
      print('✅ Added player unit: ${unitData.name} at $unitPosition');
    }

    // Create enemy units - 在上方安全区域
    for (int i = 0; i < 2; i++) {
      final unitData = i == 0
          ? BattleUnit(
              id: 'enemy1',
              name: '👹',
              unitClass: UnitClass.warrior,
              hp: 100,
              maxHp: 100,
              atk: 50,
              mass: 7.0,
              elasticity: 0.3,
            )
          : BattleUnit(
              id: 'enemy2',
              name: '🧙',
              unitClass: UnitClass.mage,
              hp: 60,
              maxHp: 60,
              atk: 80,
              mass: 3.0,
              elasticity: 0.3,
            );

      // 确保单位在边界内部的安全区域
      final unitPosition = Vector2(
        centerX - 50 + (i * 100), // 更宽的水平间距
        centerY - 80, // 在中心上方，但不贴近顶边
      );

      // 验证位置是否安全
      print('敌方单位 $i 位置: $unitPosition');
      print(
        '距离边界: 左${unitPosition.x - boundary.left}, 右${boundary.right - unitPosition.x}, 上${unitPosition.y - boundary.top}, 下${boundary.bottom - unitPosition.y}',
      );

      final unit = SimpleUnitComponent(
        unitData: unitData,
        isPlayer: false,
        position: unitPosition,
      );

      add(unit);
      enemyUnits.add(unit);
      print('✅ Added enemy unit: ${unitData.name} at $unitPosition');
    }
  }

  @override
  bool onPanStart(DragStartInfo info) {
    print('onPanStart called!');
    if (gameState != GameState.waitingForInput) {
      print('Game not waiting for input, state: $gameState');
      return false;
    }

    final screenPos = info.eventPosition.global;
    // 暂时使用屏幕坐标，稍后修复坐标转换
    final worldPosition = Vector2(screenPos.x, screenPos.y);

    print('🎯 Drag Debug:');
    print('  Screen: $screenPos, World: $worldPosition');
    print('  Game size: $size');
    print('  Player units:');

    for (int i = 0; i < playerUnits.length; i++) {
      final unit = playerUnits[i];
      print(
        '    Unit $i: ${unit.unitData.name} at ${unit.position}, used: ${unit.hasBeenUsedThisTurn}',
      );
      final distance = (unit.position - worldPosition).length;
      print('    Distance to click: ${distance.toStringAsFixed(1)}');

      if (distance < unit.radius + 20) {
        selectedUnit = unit;
        dragStart = selectedUnit!.position.clone(); // 以单位为圆心
        dragCurrent = worldPosition;
        selectedUnit!.isAiming = true;
        selectedUnit!.dragEndPosition = worldPosition;
        print('✅ Unit selected: ${unit.unitData.name}');
        return true;
      }
    }
    print('❌ No unit selected');
    return false;
  }

  @override
  bool onTapDown(TapDownInfo info) {
    print('onTapDown called at: ${info.eventPosition.global}');
    return false;
  }

  @override
  bool onPanUpdate(DragUpdateInfo info) {
    if (selectedUnit == null || dragStart == null) return false;

    final screenPos = info.eventPosition.global;
    dragCurrent = Vector2(screenPos.x, screenPos.y);

    // 应用最大拖拽距离限制
    final direction = dragCurrent! - dragStart!; // 从圆心到手指
    if (direction.length > maxDragDistance) {
      final limitedDirection = direction.normalized() * maxDragDistance;
      dragCurrent = dragStart! + limitedDirection; // 限制拖拽位置
    }
    selectedUnit!.dragEndPosition = dragCurrent;

    // 只在距离变化较大时输出调试信息
    return true;
  }

  @override
  bool onPanEnd(DragEndInfo info) {
    print('onPanEnd called');
    if (selectedUnit == null || dragStart == null || dragCurrent == null) {
      _clearDrag();
      return false;
    }

    final direction = dragStart! - dragCurrent!;
    final distance = direction.length;
    print('Launch direction: $direction, distance: $distance');

    // 使用与视觉指示器相同的最小距离检查
    if (distance > 10) {
      _launchUnit(selectedUnit!, direction);
    }

    _clearDrag();
    return true;
  }

  void _clearDrag() {
    if (selectedUnit != null) {
      selectedUnit!.isAiming = false;
      selectedUnit!.dragEndPosition = null;
    }
    selectedUnit = null;
    dragStart = null;
    dragCurrent = null;
  }

  void _launchUnit(SimpleUnitComponent unit, Vector2 direction) {
    if (gameState != GameState.waitingForInput) return;
    if (!unit.isPlayer) return;
    // 暂时移除hasBeenUsedThisTurn限制，方便测试
    // if (unit.hasBeenUsedThisTurn) return;

    // 直接基于拖拽距离计算力度，不要过早归一化
    final distance = direction.length;

    // 减半力度倍数
    final forceMultiplier = 0.4; // 从0.8减半到0.4
    final force = direction * forceMultiplier; // 保持原始方向和距离比例

    print('�� Force calculation:');
    print('  Drag distance: ${distance.toStringAsFixed(1)}');
    print('  Direction: $direction');
    print('  Final force: $force');
    print('  Force magnitude: ${force.length.toStringAsFixed(2)}');

    unit.launch(force);
    unit.hasBeenUsedThisTurn = true;

    print(
      '🚀 Launched ${unit.unitData.name} with force: ${force.length.toStringAsFixed(2)} (drag distance: ${distance.toStringAsFixed(1)})',
    );

    // 开始动画状态
    gameState = GameState.animating;

    // 2秒后自动重置状态，允许继续操作
    Future.delayed(const Duration(seconds: 2), () {
      gameState = GameState.waitingForInput;
      // 重置使用状态，允许重复拖拽测试
      for (final playerUnit in playerUnits) {
        playerUnit.hasBeenUsedThisTurn = false;
      }
      print('🔄 Turn reset - can drag again');
    });
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 直接绘制边框
    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(boundary, paint);
  }

  void nextTurn() {
    // 重置所有单位的使用状态
    for (final unit in playerUnits) {
      unit.hasBeenUsedThisTurn = false;
    }
    for (final unit in enemyUnits) {
      unit.hasBeenUsedThisTurn = false;
    }

    // 切换到等待输入状态
    gameState = GameState.waitingForInput;
    print('🔄 Turn completed - reset units');
  }
}
