import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state.dart';
import '../models/dice_info.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/dice_widget.dart';
import '../widgets/rolling_dice_widget.dart';
import 'betting_screen.dart';
import 'hand_results_screen.dart'; // ✅ ADDED THIS IMPORT

class GameScreen extends StatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _hasNavigatedToBetting = false;
  bool _hasNavigatedToResults = false; // ✅ ADDED THIS FLAG
  bool _isRolling = false;
  List<int> _selectedDiceIndices = [];
  bool _isSubmittingHand = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<GameState?>(
        stream: _firestoreService.getGameStream(widget.gameId),
        builder: (context, gameSnapshot) {
          if (!gameSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final game = gameSnapshot.data!;
          final players = game.players.entries
              .map((e) => Player.fromJson(e.value))
              .toList();

          // Navigate to betting screen when rolling is complete
          if (game.status == GameStatus.betting && !_hasNavigatedToBetting) {
            _hasNavigatedToBetting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => BettingScreen(gameId: widget.gameId),
                ),
              );
            });
          }

          // ✅ ADDED THIS ENTIRE SECTION: Navigate to hand results when evaluation is complete
          if (game.handEvaluationComplete == true && !_hasNavigatedToResults) {
            _hasNavigatedToResults = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) =>
                          HandResultsScreen(gameId: widget.gameId),
                    ),
                  )
                  .then((_) {
                    // Reset the flag when returning from results screen
                    setState(() {
                      _hasNavigatedToResults = false;
                    });
                  });
            });
          }

          final isRollingPhase = game.status == GameStatus.rolling;
          final currentlyRolling = game.currentlyRolling;
          final playersWhoRolled = game.playersWhoRolled;
          final myPlayerId = _authService.currentUserId!;
          final haveIRolled = playersWhoRolled.contains(myPlayerId);
          final isMyTurnToRoll =
              !haveIRolled && !_isRolling && currentlyRolling == null;

          return Column(
            children: [
              // Game Status Header
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
                    Text(
                      'Hand ${game.currentHand} of 3',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 16),
                    // ✅ ADDED: Score Display
                    StreamBuilder<GameState?>(
                      stream: _firestoreService.getGameStream(widget.gameId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final game = snapshot.data!;
                        final players = game.players.entries
                            .map((e) => Player.fromJson(e.value))
                            .toList();

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: players.map((player) {
                              final isMe =
                                  player.id == _authService.currentUserId;
                              return Column(
                                children: [
                                  Text(
                                    isMe ? 'You' : player.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: isMe
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    '${player.totalPoints} pts',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Game Content
              Expanded(
                child: isRollingPhase
                    ? _buildRollingPhaseContent(
                        game,
                        players,
                        currentlyRolling,
                        playersWhoRolled,
                        haveIRolled,
                        isMyTurnToRoll,
                      )
                    : _buildPlayingPhaseContent(game, players),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildYourDiceWithSelection(
    PlayerDice myDice,
    bool isMyTurn,
    GameState game,
  ) {
    final myPlayerId = _authService.currentUserId!;

    // Check if I already submitted
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .snapshots(),
      builder: (context, snapshot) {
        bool alreadySubmitted = false;
        if (snapshot.hasData) {
          final gameData = snapshot.data!.data() as Map<String, dynamic>?;
          if (gameData != null) {
            final submissions =
                gameData['handSubmissions'] as Map<String, dynamic>? ?? {};
            alreadySubmitted = submissions.containsKey(myPlayerId);
          }
        }

        if (alreadySubmitted) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[300]!, width: 2),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, size: 60, color: Colors.green[700]),
                const SizedBox(height: 12),
                const Text(
                  'Hand Submitted!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Waiting for other players...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (!isMyTurn) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(Icons.schedule, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  'Not Your Turn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Wait for other players to play',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildYourDicePreview(myDice),
              ],
            ),
          );
        }

        final availableDice = myDice.allDice
            .where((d) => !myDice.usedIndices.contains(d.index))
            .toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[300]!, width: 3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.play_arrow, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Select 3 dice (${_selectedDiceIndices.length}/3)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedDiceIndices.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDiceIndices.clear();
                        });
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Hidden Dice Section
              const Text(
                'Hidden Dice:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!myDice.usedIndices.contains(0))
                    GestureDetector(
                      onTap: () => _toggleDiceSelection(0),
                      child: DiceWidget(
                        value: myDice.hiddenDice.red.value,
                        size: 60,
                        color: Colors.red[700],
                        label: 'RED',
                        isSelected: _selectedDiceIndices.contains(0),
                      ),
                    )
                  else
                    DiceWidget(
                      value: myDice.hiddenDice.red.value,
                      size: 60,
                      color: Colors.red[700],
                      label: 'RED',
                      isUsed: true,
                    ),
                  const SizedBox(width: 12),
                  if (!myDice.usedIndices.contains(1))
                    GestureDetector(
                      onTap: () => _toggleDiceSelection(1),
                      child: DiceWidget(
                        value: myDice.hiddenDice.blue.value,
                        size: 60,
                        color: Colors.blue[700],
                        label: 'BLUE',
                        isSelected: _selectedDiceIndices.contains(1),
                      ),
                    )
                  else
                    DiceWidget(
                      value: myDice.hiddenDice.blue.value,
                      size: 60,
                      color: Colors.blue[700],
                      label: 'BLUE',
                      isUsed: true,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Visible Dice Section
              const Text(
                'Visible Dice:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: myDice.visibleDice.map((dice) {
                  final isUsed = myDice.usedIndices.contains(dice.index);
                  final isSelected = _selectedDiceIndices.contains(dice.index);

                  return GestureDetector(
                    onTap: isUsed
                        ? null
                        : () => _toggleDiceSelection(dice.index),
                    child: DiceWidget(
                      value: dice.value,
                      size: 55,
                      isUsed: isUsed,
                      isSelected: isSelected,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _selectedDiceIndices.length == 3 && !_isSubmittingHand
                      ? () => _submitHand()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmittingHand
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.send, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Play Hand',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleDiceSelection(int index) {
    setState(() {
      if (_selectedDiceIndices.contains(index)) {
        _selectedDiceIndices.remove(index);
      } else if (_selectedDiceIndices.length < 3) {
        _selectedDiceIndices.add(index);
      }
    });
  }

  Future<void> _submitHand() async {
    if (_selectedDiceIndices.length != 3) return;

    setState(() => _isSubmittingHand = true);

    try {
      await _firestoreService.playHand(
        widget.gameId,
        _authService.currentUserId!,
        _selectedDiceIndices,
      );

      if (mounted) {
        setState(() {
          _selectedDiceIndices.clear();
          _isSubmittingHand = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hand played! Waiting for other players...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingHand = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRollingPhaseContent(
    GameState game,
    List<Player> players,
    String? currentlyRolling,
    List<String> playersWhoRolled,
    bool haveIRolled,
    bool isMyTurnToRoll,
  ) {
    final myPlayer = players.firstWhere(
      (p) => p.id == _authService.currentUserId,
    );
    final opponents = players
        .where((p) => p.id != _authService.currentUserId)
        .toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Text(
                  'Rolling Phase',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${playersWhoRolled.length} / ${players.length} players have rolled',
                  style: const TextStyle(fontSize: 16),
                ),
                if (currentlyRolling != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentlyRolling == _authService.currentUserId
                            ? 'You are rolling...'
                            : '${players.firstWhere((p) => p.id == currentlyRolling).name} is rolling...',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Your Roll Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isMyTurnToRoll ? Colors.green[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMyTurnToRoll ? Colors.green : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 20,
                      child: Text(
                        myPlayer.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          myPlayer.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          haveIRolled
                              ? '✓ Rolled'
                              : currentlyRolling == _authService.currentUserId
                              ? 'Rolling...'
                              : 'Ready to roll',
                          style: TextStyle(
                            fontSize: 14,
                            color: haveIRolled
                                ? Colors.green
                                : currentlyRolling == _authService.currentUserId
                                ? Colors.orange
                                : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!haveIRolled && currentlyRolling == null)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isRolling
                          ? null
                          : () async {
                              setState(() => _isRolling = true);
                              await _firestoreService.rollMyDice(
                                widget.gameId,
                                _authService.currentUserId!,
                                myPlayer.name,
                              );
                              if (mounted) {
                                setState(() => _isRolling = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRolling
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.casino, size: 28),
                                SizedBox(width: 12),
                                Text(
                                  'Roll My Dice',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  )
                else if (currentlyRolling == _authService.currentUserId)
                  _buildMyRollingAnimation()
                else if (haveIRolled)
                  StreamBuilder<PlayerDice?>(
                    stream: _firestoreService.getPlayerDiceStream(
                      widget.gameId,
                      _authService.currentUserId!,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      return _buildYourDicePreview(snapshot.data!);
                    },
                  )
                else
                  const Text(
                    'Waiting for other player to roll...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Opponents Section
          if (opponents.isNotEmpty) ...[
            const Text(
              'Other Players',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...opponents.map((opponent) {
              final hasRolled = playersWhoRolled.contains(opponent.id);
              final isRolling = currentlyRolling == opponent.id;
              return _buildOpponentRollingCard(opponent, hasRolled, isRolling);
            }).toList(),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMyRollingAnimation() {
    return Column(
      children: [
        const Text(
          'Rolling your dice...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            RollingDiceWidget(size: 60, color: Colors.red),
            SizedBox(width: 12),
            RollingDiceWidget(size: 60, color: Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(9, (index) {
            return const RollingDiceWidget(size: 50);
          }),
        ),
      ],
    );
  }

  Widget _buildYourDicePreview(PlayerDice myDice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Dice:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            DiceWidget(
              value: myDice.hiddenDice.red.value,
              size: 40,
              color: Colors.red[700],
              isUsed: myDice.usedIndices.contains(0),
            ),
            const SizedBox(width: 6),
            DiceWidget(
              value: myDice.hiddenDice.blue.value,
              size: 40,
              color: Colors.blue[700],
              isUsed: myDice.usedIndices.contains(1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: myDice.visibleDice.map((dice) {
            return DiceWidget(
              value: dice.value,
              size: 40,
              isUsed: myDice.usedIndices.contains(dice.index),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOpponentRollingCard(
    Player opponent,
    bool hasRolled,
    bool isRolling,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRolling
            ? Colors.orange[50]
            : hasRolled
            ? Colors.green[50]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRolling
              ? Colors.orange
              : hasRolled
              ? Colors.green
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 16,
                child: Text(
                  opponent.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponent.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isRolling
                          ? 'Rolling...'
                          : hasRolled
                          ? '✓ Rolled'
                          : 'Waiting to roll',
                      style: TextStyle(
                        fontSize: 14,
                        color: isRolling
                            ? Colors.orange
                            : hasRolled
                            ? Colors.green
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isRolling)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasRolled)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          if (isRolling) ...[
            const SizedBox(height: 16),
            const Text(
              'Rolling visible dice...',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(9, (index) {
                return const RollingDiceWidget(size: 40);
              }),
            ),
          ] else if (hasRolled)
            StreamBuilder<Map<String, PublicPlayerData>>(
              stream: _firestoreService.getPublicDiceStream(widget.gameId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final publicData = snapshot.data![opponent.id];
                if (publicData == null) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Visible Dice:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: publicData.visibleDiceValues.map((value) {
                        return DiceWidget(value: value, size: 40);
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Hidden: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        DiceWidget(
                          value: null,
                          size: 35,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 6),
                        DiceWidget(
                          value: null,
                          size: 35,
                          color: Colors.blue[700],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPlayingPhaseContent(GameState game, List<Player> players) {
    final myPlayerId = _authService.currentUserId!;
    final isMyTurn = game.currentTurn == myPlayerId;
    final currentTurnPlayer = players.firstWhere(
      (p) => p.id == game.currentTurn,
      orElse: () => players.first,
    );

    return StreamBuilder<PlayerDice?>(
      stream: _firestoreService.getPlayerDiceStream(widget.gameId, myPlayerId),
      builder: (context, diceSnapshot) {
        if (!diceSnapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Loading dice...'),
              ],
            ),
          );
        }

        final myDice = diceSnapshot.data!;

        return StreamBuilder<Map<String, PublicPlayerData>>(
          stream: _firestoreService.getPublicDiceStream(widget.gameId),
          builder: (context, publicSnapshot) {
            if (!publicSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final publicData = publicSnapshot.data!;
            final opponents = players.where((p) => p.id != myPlayerId).toList();

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Turn indicator
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isMyTurn ? Colors.green[50] : Colors.blue[50],
                      border: Border(
                        bottom: BorderSide(
                          color: isMyTurn ? Colors.green : Colors.blue,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isMyTurn ? Icons.play_arrow : Icons.schedule,
                          color: isMyTurn
                              ? Colors.green[700]
                              : Colors.blue[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isMyTurn
                              ? '🎯 YOUR TURN - Select 3 dice!'
                              : '⏳ ${currentTurnPlayer.name}\'s turn...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isMyTurn
                                ? Colors.green[900]
                                : Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Game Table - Show submitted hands
                  _buildGameTable(game, players),

                  const SizedBox(height: 16),

                  // Opponents Section
                  if (opponents.isNotEmpty) ...[
                    const Text(
                      'Opponents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...opponents.map((opponent) {
                      final opponentData = publicData[opponent.id];
                      if (opponentData == null) return const SizedBox();
                      return _buildOpponentDice(opponent, opponentData);
                    }).toList(),
                  ],

                  const SizedBox(height: 24),
                  const Divider(thickness: 2),
                  const SizedBox(height: 16),

                  // Your Dice Section with Selection
                  const Text(
                    'Your Dice',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildYourDiceWithSelection(myDice, isMyTurn, game),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGameTable(GameState game, List<Player> players) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final gameData = snapshot.data!.data() as Map<String, dynamic>?;
        if (gameData == null) return const SizedBox();

        final submissions =
            gameData['handSubmissions'] as Map<String, dynamic>? ?? {};

        if (submissions.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Text(
                'No hands played yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber[300]!, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Played Hands',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...submissions.entries.map((entry) {
                final playerId = entry.key;
                final submission = entry.value as Map<String, dynamic>;
                final player = players.firstWhere((p) => p.id == playerId);
                final diceValues = List<dynamic>.from(submission['diceValues']);
                final diceTypes = List<String>.from(submission['diceTypes']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
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
                      const SizedBox(width: 12),
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: List.generate(3, (index) {
                            final value = diceValues[index];
                            final type = diceTypes[index];

                            Color? color;
                            if (type == 'red') color = Colors.red[700];
                            if (type == 'blue') color = Colors.blue[700];

                            return DiceWidget(
                              value: value, // null for hidden until revealed
                              size: 40,
                              color: color,
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOpponentDice(Player opponent, PublicPlayerData data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 16,
                child: Text(
                  opponent.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                opponent.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${data.totalDiceRemaining} dice left',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Visible Dice:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(9, (index) {
              final isUsed = data.usedVisibleIndices.contains(index);
              final value = data.visibleDiceValues[index];
              return DiceWidget(value: value, size: 45, isUsed: isUsed);
            }),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hidden Dice:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DiceWidget(
                value: data.redDiceUsed ? 0 : null,
                size: 45,
                color: Colors.red[700],
                isUsed: data.redDiceUsed,
              ),
              const SizedBox(width: 8),
              DiceWidget(
                value: data.blueDiceUsed ? 0 : null,
                size: 45,
                color: Colors.blue[700],
                isUsed: data.blueDiceUsed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYourDice(PlayerDice myDice) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[300]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dice remaining: ${myDice.remainingCount}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hidden Dice (Only you can see):',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DiceWidget(
                value: myDice.hiddenDice.red.value,
                size: 60,
                color: Colors.red[700],
                isUsed: myDice.usedIndices.contains(0),
                label: 'RED',
              ),
              const SizedBox(width: 12),
              DiceWidget(
                value: myDice.hiddenDice.blue.value,
                size: 60,
                color: Colors.blue[700],
                isUsed: myDice.usedIndices.contains(1),
                label: 'BLUE',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Visible Dice (Everyone can see):',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: myDice.visibleDice.asMap().entries.map((entry) {
              final dice = entry.value;
              return DiceWidget(
                value: dice.value,
                size: 55,
                isUsed: myDice.usedIndices.contains(dice.index),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
