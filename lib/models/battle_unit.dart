enum UnitClass { tank, mage, archer, warrior, support }

class BattleUnit {
  final String id;
  final String name;
  final UnitClass unitClass;
  int hp;
  final int maxHp;
  final int atk;
  final double mass;
  final double elasticity;

  BattleUnit({
    required this.id,
    required this.name,
    required this.unitClass,
    required this.hp,
    required this.maxHp,
    required this.atk,
    required this.mass,
    required this.elasticity,
  });

  bool get isAlive => hp > 0;

  void takeDamage(int damage) {
    hp = (hp - damage).clamp(0, maxHp);
  }

  void heal(int amount) {
    hp = (hp + amount).clamp(0, maxHp);
  }
}
