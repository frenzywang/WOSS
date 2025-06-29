import '../models/game_state.dart';
import '../game/simple_marble_game.dart';

class TurnManager {
  final SimpleMarbleBattleGame game;
  bool isPlayerTurn = true;

  TurnManager(this.game);

  void checkTurnEnd() {
    final allUnitsUsed = game.playerUnits.every(
      (unit) => unit.hasBeenUsedThisTurn,
    );

    if (allUnitsUsed || !isPlayerTurn) {
      _nextTurn();
    }
  }

  void _nextTurn() {
    isPlayerTurn = !isPlayerTurn;
    game.nextTurn();

    if (!isPlayerTurn) {
      _executeAITurn();
    }
  }

  void _executeAITurn() {
    game.gameState = GameState.enemyTurn;

    Future.delayed(const Duration(milliseconds: 1000), () {
      for (final enemyUnit in game.enemyUnits) {
        if (!enemyUnit.unitData.isAlive) continue;

        final playerTargets = game.playerUnits
            .where((unit) => unit.unitData.isAlive)
            .toList();
        if (playerTargets.isEmpty) return;

        final target = playerTargets.first;
        final direction = (target.position - enemyUnit.position).normalized();
        final force = direction * 20;

        enemyUnit.launch(force);
        enemyUnit.hasBeenUsedThisTurn = true;

        break;
      }

      Future.delayed(const Duration(seconds: 2), () {
        _nextTurn();
      });
    });
  }
}
