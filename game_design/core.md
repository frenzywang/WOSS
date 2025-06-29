# 🔥 使用 Flutter Flame 实现核心玩法的完整设计文档（LLM 可理解格式）

---

## ✅ 项目概况

- **项目类型**：弹珠式回合制战斗游戏
- **开发语言**：Dart（基于 Flutter + Flame 游戏引擎）
- **目标平台**：iOS / Android / Web（优先支持移动端）
- **引擎框架**：Flame + Forge2D（用于物理弹射）

---

## 🎮 游戏核心玩法概述

玩家控制一个由多个弹珠单位（角色）组成的小队，通过拖动角色（弹珠）进行弹射攻击。每个角色拥有一个职业与专属技能。战斗为 **回合制**，双方轮流操作，地图小而紧凑，强调策略弹射与技能组合。

---

## 🧱 技术结构总览（Flame 适配）

| 模块 | 技术实现建议 |
|------|----------------|
| 游戏主循环 | `FlameGame` 或 `Forge2DGame` |
| 物理弹射 | `Forge2D`（Flame 物理系统） |
| 地图与障碍物 | 自定义组件 + `BodyComponent`（物理墙体） |
| 角色弹珠 | `BodyComponent` + 拖拽控制逻辑 |
| 技能系统 | 事件触发系统 + 数据配置 |
| 回合管理 | 自定义 GameController 控制状态机 |
| UI层 | Flutter Widget Overlay（血条、技能按钮等） |

---

## 🚀 核心玩法循环（Game Loop）

```plaintext
[组队] → [进入地图] → [回合开始] → [玩家拖动弹射角色] → [碰撞检测 + 技能触发] → [角色停下] → [切换回合] → ...
```

### 回合制细节
- 每个队伍轮流操作，每个角色每回合只能弹射一次
- 技能有冷却或能量机制（可选）
- 战斗持续，直到一方全灭或满足胜利条件

---

## 🧩 角色系统（弹珠单位）

### 职业分类（五种）
| 职业 | 描述 | 弹性 | 质量（质量影响力矩/反弹） |
|------|------|------|----------------|
| 肉盾 | 高血/抗击退 | 低（0.1） | 高（10） |
| 法师 | 高伤低防 | 高（0.9） | 低（3） |
| 射手 | 精准伤害 | 中（0.6） | 中（5） |
| 战士 | 万能近战 | 中 | 中 |
| 辅助 | 治疗/增益 | 中 | 中 |

### 属性字段（Dart类结构示例）：
```dart
class BattleUnit {
  final String id;
  final String name;
  final UnitClass unitClass;
  int hp;
  int atk;
  double mass;
  double elasticity;
  Skill activeSkill;
  Skill? passiveSkill;
}
```

---

## 🎯 弹射控制系统（Flame + Forge2D 实现）

### 拖动 & 弹射
- 使用 Flame 的 `GestureDetectorComponent` 或手动监听 `onPanStart / onPanUpdate / onPanEnd`
- 拖动箭头（UI）展示方向与力度
- 松手后将角色施加力（applyLinearImpulse）

### 示例伪代码
```dart
void onPanEnd(DragEndDetails details) {
  final direction = dragStart - dragEnd;
  final force = direction.normalized() * forceMultiplier;
  body.applyLinearImpulse(force);
}
```

---

## 💥 碰撞与技能触发（Forge2D）

### 碰撞处理
- 使用 `ContactCallback` 注册角色与其他单位/地图的碰撞
- 判断碰撞对象，触发技能或伤害逻辑

### 技能触发机制
```dart
class Skill {
  final String id;
  final String name;
  final SkillTrigger trigger;
  final SkillEffect effect;
  final int cooldown;
}
```

- 触发类型：onCollision、onCast、onKill、onTurnStart
- 效果类型：damage, heal, stun, burn, buff, shield

---

## 🗺️ 地图系统（小地图 + 地形机制）

### 特性
- 地图固定尺寸（如 1024x768），尽量不滚动
- 使用 `WallComponent` 创建边界
- 可加入地形机关（如陷阱、加速带、传送口）

### 地图结构（JSON 示例）：
```json
{
  "id": "map_001",
  "walls": [[0,0,1024,10], [0,768,1024,10]],
  "traps": [{"x": 300, "y": 300, "radius": 50}]
}
```

---

## 🔁 回合管理系统

### 状态管理（GameState）

```dart
enum GameState {
  waitingForInput,
  animating,
  enemyTurn,
  gameOver,
}
```

- 控制当前轮到谁出手
- 控制是否允许拖动
- 控制技能释放与冷却

---

## 🧠 AI 控制系统（简化）

- 敌方单位使用简单策略：
  - 随机目标 → 计算向量 → 弹射
  - 或使用脚本化行动（技能优先释放）

---

## 🖼️ UI 与表现层

### 技术选型
- 使用 Flame 的 `Overlay` 系统，将 Flutter Widgets 叠加在游戏之上
- 包括：
  - 血条、技能按钮、冷却时间
  - 拖动箭头显示
  - 回合提示与胜负判定

---

## 🧪 示例开发任务拆分（LLM 可理解）

### 1. 创建地图与边界墙体组件
```dart
class WallComponent extends BodyComponent { ... }
```

### 2. 创建弹珠角色组件
```dart
class UnitComponent extends BodyComponent {
  BattleUnit unitData;
  void onCollision(...) => triggerSkill();
}
```

### 3. 实现拖动弹射逻辑
```dart
class DragController extends Component {
  void onPanStart(...) => recordStart();
  void onPanEnd(...) => applyImpulseToUnit();
}
```

### 4. 技能系统实现
```dart
class SkillManager {
  void trigger(Skill skill, UnitComponent caster, UnitComponent target);
}
```

### 5. 回合控制器
```dart
class TurnManager {
  GameState state;
  void nextTurn();
}
```

---

## 📦 数据结构与配置建议

### 技能 JSON 示例
```json
{
  "id": "fire_blast",
  "name": "火焰爆裂",
  "trigger": "onCast",
  "effect": {
    "type": "circle_aoe",
    "radius": 100,
    "damage": 200,
    "burn": true
  },
  "cooldown": 3
}
```

### 地图 JSON 示例
```json
{
  "id": "map_001",
  "walls": [...],
  "traps": [...],
  "spawnPoints": {
    "player": [[100,200], [150,200]],
    "enemy": [[800,600], [850,600]]
  }
}
```

---

## ✅ LLM Prompt 示例（可用于开发）

```plaintext
你是一个 Flutter Flame 游戏开发助手。我正在开发一个弹珠回合制战斗游戏，请帮我用 Flame + Forge2D 实现以下功能：

1. 创建一个可以拖动并弹射的角色组件（使用 BodyComponent）
2. 角色在碰撞时触发一个技能函数
3. 管理回合状态，轮流控制玩家与AI角色
4. 使用 JSON 加载技能与地图数据
```

---

## ✅ 总结：使用 Flame 开发的优势

| 优点 | 说明 |
|------|------|
| 跨平台 | 一套代码支持 Android / iOS / Web |
| 轻量封装 | 适合快速原型开发与 2D 游戏 |
| Forge2D | 强大的物理引擎，适合弹射玩法 |
| Flutter UI | 可使用 Flutter 完整 UI 功能构建界面 |

---

## 📌 后续可拓展方向

- 角色养成系统（升级/强化/技能解锁）
- 多地图 + 章节式战役
- PVP 排位（回合制异步匹配）
- 地图编辑器（Flutter App 实现）
