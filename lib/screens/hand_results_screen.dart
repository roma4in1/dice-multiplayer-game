import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/hand_result.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/dice_widget.dart';
import '../widgets/player_card.dart';
import 'round_results_screen.dart';

class HandResultsScreen extends StatefulWidget {
  final String gameId;

  const HandResultsScreen({super.key, required this.gameId});

  @override
  State<HandResultsScreen> createState() => _HandResultsScreenState();
}

class _HandResultsScreenState extends State<HandResultsScreen> {
  int? _initialHand;
  bool _hasNavigatedToRoundResults = false;
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final myPlayerId = authService.currentUserId!;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hand Results'),
          automaticallyImplyLeading: false,
        ),
        body: StreamBuilder<GameState?>(
          stream: firestoreService.getGameStream(widget.gameId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final game = snapshot.data!;

            // Store initial hand on first load
            _initialHand ??= game.currentHand;

            // Navigate to round results when round ends
            if (game.status == GameStatus.roundEnd &&
                !_hasNavigatedToRoundResults &&
                !_isNavigating) {
              _hasNavigatedToRoundResults = true;
              _isNavigating = true;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_isNavigating) return;

                Navigator.of(context)
                    .pushReplacement(
                      MaterialPageRoute(
                        builder: (context) =>
                            RoundResultsScreen(gameId: widget.gameId),
                      ),
                    )
                    .then((_) {
                      if (mounted) {
                        _isNavigating = false;
                      }
                    });
              });

              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading round results...'),
                  ],
                ),
              );
            }

            // Navigate back when hand advances
            if (game.status == GameStatus.playing &&
                _initialHand != null &&
                game.currentHand > _initialHand! &&
                !_isNavigating) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              });
            }

            final players = game.players.entries
                .map((e) => Player.fromJson(e.value))
                .toList();

            // Get hand results
            final handResultsMap = game.handResults;
            if (handResultsMap.isEmpty) {
              return const Center(child: Text('No results available'));
            }

            // Convert to HandResult objects and sort by rank
            final results = handResultsMap.entries
                .map((e) => HandResult.fromJson(e.value))
                .toList();

            // Sort by comparison (highest rank first)
            results.sort((a, b) => HandEvaluator.compareHands(b, a));

            // Get all winners (handles ties)
            final winnerIds = game.handWinners.isNotEmpty
                ? game.handWinners
                : (game.handWinner != null ? [game.handWinner!] : <String>[]);
            final isTie = winnerIds.length > 1;

            // Get ready status
            final playersReady = game.playersReadyToContinue;
            final iAmReady = playersReady.contains(myPlayerId);

            return Column(
              children: [
                // Winner Announcement
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber[700]!, Colors.orange[700]!],
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
                        isTie ? 'Tie!' : 'Winner!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show all winners for ties
                      ...winnerIds.map((winnerId) {
                        final winnerResult = results.firstWhere(
                          (r) => r.playerId == winnerId,
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            winnerResult.playerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      if (winnerIds.isNotEmpty) ...[
                        Text(
                          results
                              .firstWhere((r) => r.playerId == winnerIds.first)
                              .rank
                              .displayName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            Text(
                              isTie
                                  ? '+${results.firstWhere((r) => r.playerId == winnerIds.first).points} pts each this hand'
                                  : '+${results.firstWhere((r) => r.playerId == winnerIds.first).points} pts this hand',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Show round totals for each winner
                            ...winnerIds.map((winnerId) {
                              final winnerPlayer = players.firstWhere(
                                (p) => p.id == winnerId,
                              );
                              final roundTotal =
                                  game.currentRoundPoints[winnerId] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  '${winnerPlayer.name}: $roundTotal round pts (${winnerPlayer.totalPoints} total)',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // All hands
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final isWinner = winnerIds.contains(result.playerId);

                      return PlayerCard(
                        player: players.firstWhere(
                          (p) => p.id == result.playerId,
                        ),
                        style: PlayerCardStyle.handResults,
                        isMe: result.playerId == myPlayerId,
                        isWinner: isWinner,
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.rank.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: result.diceValues.asMap().entries.map((
                                entry,
                              ) {
                                final idx = entry.key;
                                final value = entry.value;

                                // Get the dice type from submissions
                                final submission =
                                    game.handSubmissions[result.playerId];
                                final diceTypes = submission != null
                                    ? List<String>.from(submission['diceTypes'])
                                    : <String>[];
                                final type = idx < diceTypes.length
                                    ? diceTypes[idx]
                                    : 'visible';

                                Color? color;
                                if (type == 'red') color = Colors.red[700];
                                if (type == 'blue') color = Colors.blue[700];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: DiceWidget(
                                    value: value,
                                    size: 50,
                                    color: color,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Show actual points won
                            Text(
                              isWinner ? '+${result.points}' : '0',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isWinner
                                    ? Colors.amber[700]
                                    : Colors.grey[600],
                              ),
                            ),
                            // Round total
                            Text(
                              '${game.currentRoundPoints[result.playerId] ?? 0} round',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Player ready status
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
                                color: isReady
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Continue button
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
                              game.currentHand < 3
                                  ? 'Continue to Next Hand'
                                  : game.currentRound < game.totalRounds
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
}
