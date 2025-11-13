import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'screens/betting_screen.dart';
import 'screens/hand_results_screen.dart';
import 'screens/round_results_screen.dart';
import 'screens/game_end_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String lobby = '/lobby';
  static const String game = '/game';
  static const String betting = '/betting';
  static const String handResults = '/hand-results';
  static const String roundResults = '/round-results';
  static const String gameEnd = '/game-end';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case lobby:
        final gameId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => LobbyScreen(gameId: gameId));
      case game:
        final gameId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => GameScreen(gameId: gameId));
      case betting:
        final gameId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => BettingScreen(gameId: gameId));
      case handResults:
        final gameId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => HandResultsScreen(gameId: gameId),
        );
      case roundResults:
        final gameId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => RoundResultsScreen(gameId: gameId),
        );
      case gameEnd:
        final gameId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => GameEndScreen(gameId: gameId));
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
