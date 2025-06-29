import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/battle_unit.dart';
import '../components/simple_unit_component.dart';

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

  @override
  Future<void> onLoad() async {
    super.onLoad();

    print('Game loaded, state: $gameState');
    print('Game size: $size');

    await _setupUnits();

    camera.viewfinder.visibleGameSize = size;

    print('Game setup complete! Collision detection enabled.');
  }

  Future<void> _setupUnits() async {
    playerUnits.clear();
    enemyUnits.clear();

    print('🎮 Setting up units with game size: $size');

    // Create player units - 放在底部
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
              elasticity: 0.1,
            )
          : BattleUnit(
              id: 'player2',
              name: '🏹',
              unitClass: UnitClass.archer,
              hp: 80,
              maxHp: 80,
              atk: 60,
              mass: 5.0,
              elasticity: 0.6,
            );

      // 简化位置计算 - 放在底部中央
      final unitPosition = Vector2(200 + i * 100, size.y - 150);

      final unit = SimpleUnitComponent(
        unitData: unitData,
        isPlayer: true,
        position: unitPosition,
      );

      add(unit);
      playerUnits.add(unit);
      print('✅ Added player unit: ${unitData.name} at ${unitPosition}');
    }

    // Create enemy units - 放在顶部
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
              elasticity: 0.4,
            )
          : BattleUnit(
              id: 'enemy2',
              name: '🧙',
              unitClass: UnitClass.mage,
              hp: 60,
              maxHp: 60,
              atk: 80,
              mass: 3.0,
              elasticity: 0.9,
            );

      // 简化位置计算 - 放在顶部中央
      final unitPosition = Vector2(200 + i * 100, 150);

      final unit = SimpleUnitComponent(
        unitData: unitData,
        isPlayer: false,
        position: unitPosition,
      );

      add(unit);
      enemyUnits.add(unit);
      print('✅ Added enemy unit: ${unitData.name} at ${unitPosition}');
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

    print('📏 Force calculation:');
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

    // 所有的绘制逻辑都移动到 SimpleUnitComponent 中了
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
