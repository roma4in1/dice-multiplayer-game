import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/dice_info.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/dice_widget.dart';
import 'game_screen.dart';
import '../widgets/rule_book_button.dart';

class BettingScreen extends StatefulWidget {
  final String gameId;

  const BettingScreen({super.key, required this.gameId});

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  String? _selectedBet;
  bool _betLocked = false;
  bool _hasNavigated = false;

  final List<Map<String, dynamic>> _betOptions = [
    {
      'type': 'zero',
      'title': 'ZERO',
      'description': 'Win 0 points this round',
      'color': Colors.grey,
      'icon': Icons.block,
    },
    {
      'type': 'minimum',
      'title': 'MINIMUM',
      'description': 'Win a few hands',
      'color': Colors.blue,
      'icon': Icons.trending_down,
    },
    {
      'type': 'maximum',
      'title': 'MAXIMUM',
      'description': 'Win most hands',
      'color': Colors.orange,
      'icon': Icons.trending_up,
    },
    {
      'type': 'winner',
      'title': 'WINNER',
      'description': 'Win the entire round',
      'color': Colors.green,
      'icon': Icons.emoji_events,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Your Bet'),
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

          // Navigate to game screen when all bets are in
          if (game.status == GameStatus.playing && !_hasNavigated) {
            _hasNavigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => GameScreen(gameId: widget.gameId),
                ),
              );
            });
          }

          // Get list of players and their bet status
          final players = game.players.entries
              .map((e) => Player.fromJson(e.value))
              .toList();
          final playersWithBets = players
              .where((p) => p.currentBet != null && p.currentBet!.isNotEmpty)
              .length;
          final totalPlayers = players.length;

          return Column(
            children: [
              // Round Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[700]!, Colors.blue[700]!],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Round ${game.currentRound} of ${game.totalRounds}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose your betting strategy',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$playersWithBets / $totalPlayers players have bet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Show all players' dice for reference
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (!_betLocked) ...[
                        const SizedBox(height: 16),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Review everyone\'s visible dice before betting',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildAllPlayersDice(players),
                        const SizedBox(height: 20),
                        const Divider(thickness: 2),
                        const SizedBox(height: 12),
                      ],

                      // Betting Options or Locked State
                      if (_betLocked)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock,
                                size: 80,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Bet Locked In!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Your bet: ${_betOptions.firstWhere((b) => b['type'] == _selectedBet)['title']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 40),
                              Text(
                                'Waiting for other players...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$playersWithBets / $totalPlayers players have bet',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const CircularProgressIndicator(),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Your Bet:',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._betOptions.map((option) {
                                final isSelected =
                                    _selectedBet == option['type'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedBet = option['type'];
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? option['color'].withOpacity(0.2)
                                          : Colors.grey[100],
                                      border: Border.all(
                                        color: isSelected
                                            ? option['color']
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: option['color'],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            option['icon'],
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                option['title'],
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                option['description'],
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: option['color'],
                                            size: 28,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Lock In Button
              if (!_betLocked)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_selectedBet != null)
                        Text(
                          'Selected: ${_betOptions.firstWhere((b) => b['type'] == _selectedBet)['title']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _selectedBet != null
                              ? () async {
                                  setState(() => _betLocked = true);
                                  await _firestoreService.submitBet(
                                    widget.gameId,
                                    _authService.currentUserId!,
                                    _selectedBet!,
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Lock In Bet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You cannot change your bet once locked',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllPlayersDice(List<Player> players) {
    return StreamBuilder<Map<String, PublicPlayerData>>(
      stream: _firestoreService.getPublicDiceStream(widget.gameId),
      builder: (context, publicSnapshot) {
        if (!publicSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final publicData = publicSnapshot.data!;

        return Column(
          children: [
            const Text(
              'All Players\' Dice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...players.map((player) {
              final isMe = player.id == _authService.currentUserId;
              final data = publicData[player.id];

              if (data == null) return const SizedBox();

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMe ? Colors.blue[300]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 14,
                          child: Text(
                            player.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMe ? '${player.name} (You)' : player.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Visible: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: data.visibleDiceValues.map((value) {
                              return DiceWidget(value: value, size: 32);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Hidden: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        DiceWidget(
                          value: null,
                          size: 28,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 4),
                        DiceWidget(
                          value: null,
                          size: 28,
                          color: Colors.blue[700],
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          StreamBuilder<PlayerDice?>(
                            stream: _firestoreService.getPlayerDiceStream(
                              widget.gameId,
                              _authService.currentUserId!,
                            ),
                            builder: (context, diceSnapshot) {
                              if (!diceSnapshot.hasData) {
                                return const SizedBox();
                              }
                              final myDice = diceSnapshot.data!;
                              return Row(
                                children: [
                                  const Text(
                                    '→ ',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  DiceWidget(
                                    value: myDice.hiddenDice.red.value,
                                    size: 28,
                                    color: Colors.red[700],
                                  ),
                                  const SizedBox(width: 4),
                                  DiceWidget(
                                    value: myDice.hiddenDice.blue.value,
                                    size: 28,
                                    color: Colors.blue[700],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
