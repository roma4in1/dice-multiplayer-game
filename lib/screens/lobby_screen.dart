import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/player_card.dart';
import 'game_screen.dart';
import '../widgets/rule_book_button.dart';

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _leaveGame();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game Lobby'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leaveGame,
          ),
          actions: const [RuleBookButton()],
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
                .map((e) => Player.fromJson(
                    Map<String, dynamic>.from(e.value as Map)))
                .toList();
            final myId = _authService.currentUserId!;
            final isHost = game.hostId == myId;
            final currentPlayer = players.cast<Player?>().firstWhere(
              (p) => p!.id == myId,
              orElse: () => null,
            );
            final iAmReady = currentPlayer?.isReady ?? false;

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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.navyLight, AppTheme.navy],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Join Code:',
                              style: AppTheme.heading(
                                  size: 14,
                                  color: Colors.white60,
                                  weight: FontWeight.w400)),
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
                                gradient: const LinearGradient(
                                  colors: [AppTheme.goldLight, AppTheme.gold],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    game.joinCode,
                                    style: AppTheme.display(
                                        size: 22, color: AppTheme.navy),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.copy,
                                      color: AppTheme.navy, size: 18),
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
                SafeArea(
                  top: false,
                  child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      if (!isHost)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: currentPlayer == null
                                ? null
                                : () {
                                    _firestoreService.setPlayerReady(
                                      widget.gameId,
                                      myId,
                                      !iAmReady,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  iAmReady ? Colors.orange : Colors.green,
                            ),
                            child: Text(
                              iAmReady ? 'Not Ready' : 'Ready',
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
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(label,
              style: AppTheme.heading(
                  size: 11, color: Colors.white60, weight: FontWeight.w400)),
          Text(
            value,
            style: AppTheme.display(size: 18, color: Colors.white),
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

  Future<void> _leaveGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardIvory,
        title: Text('Leave Game?',
            style: AppTheme.heading(color: AppTheme.navy)),
        content: const Text(
          'You will be removed from the lobby. This cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _firestoreService.leaveGame(
      widget.gameId,
      _authService.currentUserId!,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
