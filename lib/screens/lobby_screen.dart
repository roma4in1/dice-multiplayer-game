import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String gameId;

  const LobbyScreen({super.key, required this.gameId});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _leaveGame();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game Lobby'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leaveGame,
          ),
        ),
        body: StreamBuilder<GameState?>(
          stream: _firestoreService.getGameStream(widget.gameId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Game not found'));
            }

            final game = snapshot.data!;

            // Navigate to game screen when game starts (rolling phase)
            if (game.status == GameStatus.rolling && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => GameScreen(gameId: widget.gameId),
                  ),
                );
              });
            }

            final players = game.players.entries
                .map((e) => Player.fromJson(e.value))
                .toList();
            final isHost = game.hostId == _authService.currentUserId;
            final currentPlayer = players.firstWhere(
              (p) => p.id == _authService.currentUserId,
              orElse: () => players.first,
            );

            // Check if all non-host players are ready
            final nonHostPlayers = players.where((p) => !p.isHost).toList();
            final allPlayersReady =
                nonHostPlayers.isEmpty ||
                nonHostPlayers.every((p) => p.isReady);

            return Column(
              children: [
                // Game Info Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.purple[600]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Join Code:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: game.joinCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Code copied!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    game.joinCode,
                                    style: TextStyle(
                                      color: Colors.purple[700],
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.copy,
                                    color: Colors.purple[700],
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoChip('Rounds', game.totalRounds.toString()),
                          _buildInfoChip(
                            'Players',
                            '${game.playerCount}/${game.maxPlayers}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Players List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return _buildPlayerCard(player);
                    },
                  ),
                ),

                // Bottom Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (!isHost)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              _firestoreService.setPlayerReady(
                                widget.gameId,
                                _authService.currentUserId!,
                                !currentPlayer.isReady,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentPlayer.isReady
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                            child: Text(
                              currentPlayer.isReady ? 'Not Ready' : 'Ready',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      if (isHost) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: game.canStart && allPlayersReady
                                ? () =>
                                      _firestoreService.startGame(widget.gameId)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text(
                              'Start Game',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          game.canStart && !allPlayersReady
                              ? 'Waiting for all players to be ready...'
                              : !game.canStart
                              ? 'Need at least 2 players'
                              : 'Ready to start!',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
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

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: player.isHost ? Colors.amber : Colors.blue,
          child: Text(
            player.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              player.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (player.isHost) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HOST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: player.isHost
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'READY',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.check_circle, color: Colors.green),
                ],
              )
            : player.isReady
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.schedule, color: Colors.grey),
      ),
    );
  }

  Future<void> _leaveGame() async {
    await _firestoreService.leaveGame(
      widget.gameId,
      _authService.currentUserId!,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
