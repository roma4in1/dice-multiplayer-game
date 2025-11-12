import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

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
                    const Icon(Icons.flag, size: 60, color: Colors.white),
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

              // Standings
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final isMe = player.id == myPlayerId;
                    final position = index + 1;

                    // Medal colors for top 3
                    Color? medalColor;
                    IconData? medalIcon;
                    if (position == 1) {
                      medalColor = Colors.amber[700];
                      medalIcon = Icons.emoji_events;
                    } else if (position == 2) {
                      medalColor = Colors.grey[600];
                      medalIcon = Icons.military_tech;
                    } else if (position == 3) {
                      medalColor = Colors.orange[700];
                      medalIcon = Icons.military_tech;
                    }

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
                      child: Row(
                        children: [
                          // Position
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: medalColor ?? Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: medalIcon != null
                                  ? Icon(
                                      medalIcon,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : Text(
                                      '$position',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Avatar
                          CircleAvatar(
                            backgroundColor: Colors.blue,
                            radius: 20,
                            child: Text(
                              player.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMe ? '${player.name} (You)' : player.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: isMe
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Total Score',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Points
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${player.totalPoints}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: medalColor ?? Colors.grey[700],
                                ),
                              ),
                              Text(
                                'points',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
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
}
