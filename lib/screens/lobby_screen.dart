import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/player_card.dart';
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
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Hand Rankings',
              onPressed: _showRuleBook,
            ),
          ],
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
                      final isMe = player.id == _authService.currentUserId;

                      return PlayerCard(
                        player: player,
                        style: PlayerCardStyle.lobby,
                        isMe: isMe,
                        isReady: player.isReady,
                        onEditName: isMe
                            ? () => _showEditNameDialog(player)
                            : null,
                      );
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

  void _showEditNameDialog(Player player) {
    final controller = TextEditingController(text: player.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Enter new username',
            border: OutlineInputBorder(),
          ),
          maxLength: 20,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name cannot be empty')),
                );
                return;
              }
              if (newName.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name must be at least 2 characters'),
                  ),
                );
                return;
              }

              await _firestoreService.updatePlayerName(
                widget.gameId,
                player.id,
                newName,
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Username changed to $newName')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRuleBook() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[700]),
            const SizedBox(width: 8),
            const Text('Hand Rankings'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'From strongest to weakest:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),

              // Triple
              _buildRankCard(
                rank: '1. Triple',
                description: 'All three dice show the same value',
                examples: ['6-6-6', '5-5-5', '1-1-1'],
                color: Colors.purple,
                icon: Icons.filter_3,
              ),

              const SizedBox(height: 12),

              // Straight
              _buildRankCard(
                rank: '2. Straight',
                description: 'Three consecutive values',
                examples: ['4-5-6', '3-4-5', '1-2-3'],
                color: Colors.blue,
                icon: Icons.trending_up,
              ),

              const SizedBox(height: 12),

              // Pair
              _buildRankCard(
                rank: '3. Pair',
                description: 'Two dice show the same value',
                examples: ['6-6-3', '4-4-1', '2-2-5'],
                color: Colors.green,
                icon: Icons.filter_2,
              ),

              const SizedBox(height: 12),

              // High Card
              _buildRankCard(
                rank: '4. High Card',
                description: 'No matching or consecutive values',
                examples: ['6-4-1', '5-3-1', '6-2-1'],
                color: Colors.orange,
                icon: Icons.filter_1,
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Tiebreaker rules
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Tiebreaker Rules:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Same rank? Compare highest die value\n'
                      '• Still tied? Compare sum of all dice\n'
                      '• Still tied? Players split the points',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Points info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Each hand is worth 5 points\nWinner takes all (or split if tied)',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard({
    required String rank,
    required String description,
    required List<String> examples,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                rank,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: examples.map((example) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  example,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
