import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class GameEndScreen extends StatelessWidget {
  final String gameId;

  const GameEndScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final myPlayerId = authService.currentUserId!;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game Over'),
          automaticallyImplyLeading: false,
        ),
        body: StreamBuilder<GameState?>(
          stream: firestoreService.getGameStream(gameId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final game = snapshot.data!;
            final players = game.players.entries
                .map((e) => Player.fromJson(e.value))
                .toList();

            // Sort by total points (descending)
            players.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

            final winner = players.first;
            final isWinner = winner.id == myPlayerId;

            return Column(
              children: [
                // Winner Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.amber[700]!, Colors.orange[700]!],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        size: 100,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'GAME OVER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '👑 Winner 👑',
                        style: TextStyle(color: Colors.white70, fontSize: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        winner.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${winner.totalPoints} points',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isWinner) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            '🎉 YOU WON! 🎉',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Final Standings
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final position = index + 1;
                      final isMe = player.id == myPlayerId;

                      // Medal colors
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
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[50] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMe ? Colors.blue[300]! : Colors.grey[300]!,
                            width: isMe ? 3 : 1,
                          ),
                          boxShadow: position <= 3
                              ? [
                                  BoxShadow(
                                    color: (medalColor ?? Colors.grey)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            // Position Medal
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: medalColor ?? Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: medalIcon != null
                                    ? Icon(
                                        medalIcon,
                                        color: Colors.white,
                                        size: 30,
                                      )
                                    : Text(
                                        '$position',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Avatar
                            CircleAvatar(
                              backgroundColor: Colors.blue,
                              radius: 25,
                              child: Text(
                                player.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMe ? '${player.name} (You)' : player.name,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: isMe
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    position == 1
                                        ? '🏆 Champion'
                                        : position == 2
                                        ? '🥈 Runner-up'
                                        : position == 3
                                        ? '🥉 Third Place'
                                        : 'Finalist',
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
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: medalColor ?? Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  'points',
                                  style: TextStyle(
                                    fontSize: 14,
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

                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            // Navigate back to home and clear stack
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const HomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Game ID: ${game.joinCode}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
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
