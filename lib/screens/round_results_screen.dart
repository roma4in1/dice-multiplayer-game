import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/player_card.dart';
import '../widgets/rule_book_button.dart';

class RoundResultsScreen extends StatefulWidget {
  final String gameId;

  const RoundResultsScreen({super.key, required this.gameId});

  @override
  State<RoundResultsScreen> createState() => _RoundResultsScreenState();
}

class _RoundResultsScreenState extends State<RoundResultsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _hasNavigatedToNextRound = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Round Results'),
        automaticallyImplyLeading: false,
        actions: const [RuleBookButton()],
      ),
      body: StreamBuilder<GameState?>(
        stream: _firestoreService.getGameStream(widget.gameId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final game = snapshot.data!;

          // Navigate to next round when it starts (rolling phase)
          if (game.status == GameStatus.rolling && !_hasNavigatedToNextRound) {
            _hasNavigatedToNextRound = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop(); // Go back to game screen
              }
            });
          }

          final players = game.players.entries
              .map((e) => Player.fromJson(e.value))
              .toList();

          // Sort players by total points (descending)
          players.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

          final myPlayerId = _authService.currentUserId!;
          final playersReady = game.playersReadyToContinue;
          final iAmReady = playersReady.contains(myPlayerId);

          final isLastRound = game.currentRound >= game.totalRounds;

          return Column(
            children: [
              // Round Header
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
                      isLastRound
                          ? 'Final Round - Game Over!'
                          : 'Round ${game.currentRound} of ${game.totalRounds}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // Standings with Bet Evaluation
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final isMe = player.id == myPlayerId;
                    final position = index + 1;

                    // Calculate bet results
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

                    return PlayerCard(
                      player: player,
                      style: PlayerCardStyle.results,
                      isMe: isMe,
                      position: position,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),

                          // Round Performance
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Round Points
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
                                    '$roundPoints pts',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              // Bet
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
                                    _getBetDisplayName(bet),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),

                              // Success/Failed Indicator
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

                          // Points Calculation Breakdown
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      betSuccess
                                          ? _getSuccessMessage(bet)
                                          : 'No bonus - base points only',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      '+$pointsAdded pts',
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
                                if (betSuccess) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _getCalculationBreakdown(
                                      bet,
                                      roundPoints,
                                      pointsAdded,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Ready Status Bar
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                    // Show which players are ready
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
                              color: isReady ? Colors.white : Colors.grey[600],
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
                            await _firestoreService.markPlayerReadyToContinue(
                              widget.gameId,
                              myPlayerId,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iAmReady ? Colors.grey : Colors.green,
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
                            isLastRound
                                ? 'View Final Results'
                                : 'Continue to Next Round',
                          ),
                  ),
                ),
              ),
            ],
          );
        },
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
        return 30; // Fixed bonus for successful ZERO
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
        return 'Zero bonus! Fixed +30 pts';
      case 'minimum':
      case 'maximum':
      case 'winner':
        return 'Bet success! Points doubled (×2)';
      default:
        return '';
    }
  }

  String _getCalculationBreakdown(
    String bet,
    int roundPoints,
    int pointsAdded,
  ) {
    switch (bet) {
      case 'zero':
        return 'Zero bet = fixed 30 point bonus';
      case 'minimum':
      case 'maximum':
      case 'winner':
        return '$roundPoints pts × 2 multiplier = $pointsAdded pts';
      default:
        return '';
    }
  }
}
