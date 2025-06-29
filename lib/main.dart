import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'game/simple_marble_game.dart';

void main() {
  runApp(const MarbleBattleApp());
}

class MarbleBattleApp extends StatelessWidget {
  const MarbleBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marble Battle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final SimpleMarbleBattleGame game;

  @override
  void initState() {
    super.initState();
    game = SimpleMarbleBattleGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget.controlled(gameFactory: () => game),
    );
  }
}
