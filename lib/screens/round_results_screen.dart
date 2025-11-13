import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'game_screen.dart';
import 'game_end_screen.dart';

class RoundResultsScreen extends StatefulWidget {
  final String gameId;

  const RoundResultsScreen({super.key, required this.gameId});

  @override
  State<RoundResultsScreen> createState() => _RoundResultsScreenState();
}

class _RoundResultsScreenState extends State<RoundResultsScreen> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final myPlayerId = authService.currentUserId!;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Round Complete'),
          automaticallyImplyLeading: false,
        ),
        body: StreamBuilder<GameState?>(
          stream: firestoreService.getGameStream(widget.gameId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final game = snapshot.data!;

            // Navigate ONLY when new round starts (rolling phase)
            if (game.status == GameStatus.rolling && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // Clear navigation stack and go to game screen
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => GameScreen(gameId: widget.gameId),
                    ),
                    (route) => false,
                  );
                }
              });

              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting next round...'),
                  ],
                ),
              );
            }

            // Navigate to game end screen
            if (game.status == GameStatus.gameEnd && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          GameEndScreen(gameId: widget.gameId),
                    ),
                  );
                }
              });

              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading final results...'),
                  ],
                ),
              );
            }

            final players = game.players.entries
                .map((e) => Player.fromJson(e.value))
                .toList();

            // Sort by total points descending
            players.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

            // Get ready status
            final playersReady = game.playersReadyToContinue;
            final iAmReady = playersReady.contains(myPlayerId);

            // Calculate bet results for display
            final betResults = <String, Map<String, dynamic>>{};
            for (var player in players) {
              final roundPoints = game.currentRoundPoints[player.id] ?? 0;
              final bet = player.currentBet ?? '';
              final betSuccess = _evaluateBet(
                bet,
                roundPoints,
                game,
                player.id,
              );
              final pointsAdded = _calculatePointsAdded(
                bet,
                roundPoints,
                betSuccess,
              );

              betResults[player.id] = {
                'roundPoints': roundPoints,
                'bet': bet,
                'betSuccess': betSuccess,
                'pointsAdded': pointsAdded,
              };
            }

            return Column(
              children: [
                // Round Complete Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple[700]!, Colors.blue[700]!],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        size: 60,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Round ${game.currentRound} Complete!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game.currentRound < game.totalRounds
                            ? 'Round ${game.currentRound + 1} coming up...'
                            : 'Game Over!',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                // Results List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final result = betResults[player.id]!;
                      final isMe = player.id == myPlayerId;
                      final betSuccess = result['betSuccess'] as bool;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[50] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe ? Colors.blue[300]! : Colors.grey[300]!,
                            width: isMe ? 3 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Player Header
                            Row(
                              children: [
                                Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  radius: 20,
                                  child: Text(
                                    player.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isMe ? '${player.name} (You)' : player.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${player.totalPoints} pts',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 12),

                            // Round Performance
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Round Points',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '${result['roundPoints']} pts',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bet',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      _getBetDisplayName(result['bet']),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: betSuccess
                                        ? Colors.green[100]
                                        : Colors.red[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        betSuccess
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: betSuccess
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        betSuccess ? 'SUCCESS' : 'FAILED',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: betSuccess
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Points Calculation
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    betSuccess
                                        ? _getSuccessMessage(result['bet'])
                                        : 'No bonus applied',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    '+${result['pointsAdded']} pts',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: betSuccess
                                          ? Colors.green[700]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Player Ready Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(
                        playersReady.length == players.length
                            ? Icons.check_circle
                            : Icons.schedule,
                        color: playersReady.length == players.length
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${playersReady.length} / ${players.length} players ready',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      ...players.map((player) {
                        final isReady = playersReady.contains(player.id);
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: isReady
                                ? Colors.green
                                : Colors.grey[300],
                            child: Text(
                              player.name[0].toUpperCase(),
                              style: TextStyle(
                                color: isReady
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

                // Continue Button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: iAmReady
                          ? null
                          : () async {
                              await firestoreService.markPlayerReadyToContinue(
                                widget.gameId,
                                myPlayerId,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iAmReady
                            ? Colors.grey
                            : Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: iAmReady
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_circle, size: 20),
                                SizedBox(width: 8),
                                Text('Waiting for other players...'),
                              ],
                            )
                          : Text(
                              game.currentRound < game.totalRounds
                                  ? 'Continue to Next Round'
                                  : 'View Final Results',
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _evaluateBet(
    String bet,
    int roundPoints,
    GameState game,
    String playerId,
  ) {
    switch (bet) {
      case 'zero':
        return roundPoints == 0;
      case 'minimum':
        return roundPoints > 2.5 && roundPoints < 7.5;
      case 'maximum':
        return roundPoints > 7.5 && roundPoints < 10;
      case 'winner':
        // Check if this player has highest round points
        final allRoundPoints = game.currentRoundPoints;
        if (allRoundPoints.isEmpty) return false;
        final maxPoints = allRoundPoints.values.reduce((a, b) => a > b ? a : b);
        return roundPoints == maxPoints;
      default:
        return false;
    }
  }

  int _calculatePointsAdded(String bet, int roundPoints, bool betSuccess) {
    if (!betSuccess) {
      return roundPoints; // No multiplier/bonus
    }

    switch (bet) {
      case 'zero':
        return 20; // Fixed bonus for successful ZERO
      case 'minimum':
      case 'maximum':
      case 'winner':
        return roundPoints * 2; // Double the points
      default:
        return roundPoints;
    }
  }

  String _getBetDisplayName(String bet) {
    switch (bet) {
      case 'zero':
        return 'ZERO';
      case 'minimum':
        return 'MINIMUM';
      case 'maximum':
        return 'MAXIMUM';
      case 'winner':
        return 'WINNER';
      default:
        return bet.toUpperCase();
    }
  }

  String _getSuccessMessage(String bet) {
    switch (bet) {
      case 'zero':
        return 'Zero bonus! +20 pts';
      case 'minimum':
      case 'maximum':
      case 'winner':
        return 'Points doubled!';
      default:
        return '';
    }
  }
}
