import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/game_state.dart';
import '../models/dice_info.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/dice_widget.dart';
import '../widgets/rolling_dice_widget.dart';
import 'betting_screen.dart';
import 'hand_results_screen.dart';
import '../widgets/player_card.dart';
import '../widgets/rule_book_button.dart';

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
  bool _hasShownHandResults = false;
  bool _isRolling = false;
  final List<int> _selectedDiceIndices = [];
  bool _isSubmittingHand = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game'),
        automaticallyImplyLeading: false,
        actions: const [RuleBookButton()],
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
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => BettingScreen(gameId: widget.gameId),
                  ),
                );
              }
            });
          }

          // Show hand results as modal overlay
          if (game.status == GameStatus.playing &&
              game.handEvaluationComplete == true &&
              !_hasShownHandResults) {
            _hasShownHandResults = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: false,
                  barrierColor: Colors.black.withValues(alpha: 0.8),
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return FadeTransition(
                      opacity: animation,
                      child: HandResultsScreen(gameId: widget.gameId),
                    );
                  },
                ).then((_) {
                  if (mounted) {
                    setState(() {
                      _hasShownHandResults = false;
                    });
                  }
                });
              }
            });
          }

          // Reset flag when hand evaluation is no longer complete
          if (!game.handEvaluationComplete && _hasShownHandResults) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasShownHandResults = false;
                });
              }
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
              // ── Game Status Header ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(gradient: AppTheme.navyGradient),
                child: Column(
                  children: [
                    Text(
                      'Round ${game.currentRound} of ${game.totalRounds}',
                      style: AppTheme.display(size: 26),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hand ${game.currentHand} of 3',
                      style: AppTheme.heading(size: 14, color: Colors.white60),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: AppTheme.navyPanel(radius: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: players.map((player) {
                          final isMe = player.id == _authService.currentUserId;
                          final score =
                              game.currentRoundPoints[player.id] ?? 0;
                          return Column(
                            children: [
                              Text(
                                isMe ? 'You' : player.name,
                                style: TextStyle(
                                  color: isMe ? AppTheme.gold : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isMe
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(
                                  scale: anim,
                                  child:
                                      FadeTransition(opacity: anim, child: child),
                                ),
                                child: Text(
                                  '$score',
                                  key: ValueKey(
                                      'score_${player.id}_$score'),
                                  style: AppTheme.display(
                                      size: 28, color: AppTheme.gold),
                                ),
                              ),
                              Text(
                                '(${player.totalPoints} total)',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Game Content on felt ─────────────────────────────────────
              Expanded(
                child: DecoratedBox(
                  decoration:
                      const BoxDecoration(gradient: AppTheme.feltGradient),
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
    final alreadySubmitted = game.handSubmissions.containsKey(myPlayerId);

    if (alreadySubmitted) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.card(
          color: AppTheme.success.withValues(alpha: 0.15),
          borderColor: AppTheme.success.withValues(alpha: 0.5),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 60, color: Colors.green[300]),
            const SizedBox(height: 12),
            const Text(
              'Hand Submitted!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Waiting for other players...',
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
          ],
        ),
      );
    }

    if (!isMyTurn) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.card(
          color: Colors.white.withValues(alpha: 0.07),
          borderColor: Colors.white24,
        ),
        child: Column(
          children: [
            Icon(Icons.schedule, size: 50, color: Colors.white38),
            const SizedBox(height: 12),
            const Text(
              'Not Your Turn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wait for other players to play',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            _buildYourDicePreview(myDice),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold, width: 2.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_arrow, color: AppTheme.gold),
                  const SizedBox(width: 8),
                  Text(
                    'Select 3 dice (${_selectedDiceIndices.length}/3)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                  child: const Text('Clear',
                      style: TextStyle(color: Colors.white70)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Hidden Dice Section
          const Text(
            'Hidden Dice:',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70),
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
                    color: AppTheme.diceRed,
                    label: 'RED',
                    isSelected: _selectedDiceIndices.contains(0),
                  ),
                )
              else
                DiceWidget(
                  value: myDice.hiddenDice.red.value,
                  size: 60,
                  color: AppTheme.diceRed,
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
                    color: AppTheme.diceBlue,
                    label: 'BLUE',
                    isSelected: _selectedDiceIndices.contains(1),
                  ),
                )
              else
                DiceWidget(
                  value: myDice.hiddenDice.blue.value,
                  size: 60,
                  color: AppTheme.diceBlue,
                  label: 'BLUE',
                  isUsed: true,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Visible Dice Section
          const Text(
            'Visible Dice:',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: myDice.visibleDice.map((dice) {
              final isUsed = myDice.usedIndices.contains(dice.index);
              final isSelected = _selectedDiceIndices.contains(dice.index);

              return GestureDetector(
                onTap: isUsed ? null : () => _toggleDiceSelection(dice.index),
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
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmittingHand
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.navy,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Play Hand',
                          style: AppTheme.heading(
                              size: 18,
                              color: AppTheme.navy,
                              weight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
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
            color: Colors.black.withValues(alpha: 0.25),
            child: Column(
              children: [
                Text(
                  'Rolling Phase',
                  style: AppTheme.heading(size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  '${playersWhoRolled.length} / ${players.length} players have rolled',
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                ),
                if (currentlyRolling != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentlyRolling == _authService.currentUserId
                            ? 'You are rolling...'
                            : '${players.firstWhere((p) => p.id == currentlyRolling).name} is rolling...',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
              color: isMyTurnToRoll
                  ? AppTheme.gold.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMyTurnToRoll ? AppTheme.gold : Colors.white24,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.navyLight,
                      radius: 20,
                      child: Text(
                        myPlayer.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.gold,
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
                            color: Colors.white,
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
                                ? Colors.greenAccent
                                : currentlyRolling == _authService.currentUserId
                                ? Colors.orange
                                : Colors.white54,
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
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRolling
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppTheme.navy,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.casino, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  'Roll My Dice',
                                  style: AppTheme.heading(
                                      size: 18,
                                      color: AppTheme.navy,
                                      weight: FontWeight.bold),
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
                        return const CircularProgressIndicator(
                            color: AppTheme.gold);
                      }
                      return _buildYourDicePreview(snapshot.data!);
                    },
                  )
                else
                  const Text(
                    'Waiting for other player to roll...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Opponents Section
          if (opponents.isNotEmpty) ...[
            Text('Other Players', style: AppTheme.heading(size: 18)),
            const SizedBox(height: 12),
            ...opponents.map((opponent) {
              final hasRolled = playersWhoRolled.contains(opponent.id);
              final isRolling = currentlyRolling == opponent.id;
              return _buildOpponentRollingCard(opponent, hasRolled, isRolling);
            }),
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
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RollingDiceWidget(size: 60, color: AppTheme.diceRed),
            SizedBox(width: 12),
            RollingDiceWidget(size: 60, color: AppTheme.diceBlue),
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
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            DiceWidget(
              value: myDice.hiddenDice.red.value,
              size: 40,
              color: AppTheme.diceRed,
              isUsed: myDice.usedIndices.contains(0),
            ),
            const SizedBox(width: 6),
            DiceWidget(
              value: myDice.hiddenDice.blue.value,
              size: 40,
              color: AppTheme.diceBlue,
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
    return PlayerCard(
      player: opponent,
      style: PlayerCardStyle.rolling,
      isRolling: isRolling,
      hasRolled: hasRolled,
      backgroundColor: isRolling
          ? Colors.orange.withValues(alpha: 0.15)
          : hasRolled
          ? Colors.green.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.07),
      borderColor: isRolling
          ? Colors.orange
          : hasRolled
          ? Colors.greenAccent
          : Colors.white24,
      subtitle: hasRolled
          ? StreamBuilder<Map<String, PublicPlayerData>>(
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
                        color: Colors.white70,
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
                  ],
                );
              },
            )
          : null,
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
                CircularProgressIndicator(color: AppTheme.gold),
                SizedBox(height: 20),
                Text('Loading dice...',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }

        final myDice = diceSnapshot.data!;

        return StreamBuilder<Map<String, PublicPlayerData>>(
          stream: _firestoreService.getPublicDiceStream(widget.gameId),
          builder: (context, publicSnapshot) {
            if (!publicSnapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.gold));
            }

            final publicData = publicSnapshot.data!;
            final opponents =
                players.where((p) => p.id != myPlayerId).toList();

            // Turn indicator widget
            Widget turnIndicator = Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMyTurn
                    ? AppTheme.gold.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.2),
                border: Border(
                  bottom: BorderSide(
                    color: isMyTurn ? AppTheme.gold : Colors.white30,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isMyTurn ? Icons.play_arrow : Icons.schedule,
                    color: isMyTurn ? AppTheme.gold : Colors.white54,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isMyTurn
                        ? '🎯 YOUR TURN — Select 3 dice!'
                        : '⏳ ${currentTurnPlayer.name}\'s turn...',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isMyTurn ? AppTheme.gold : Colors.white70,
                    ),
                  ),
                ],
              ),
            );

            if (isMyTurn) {
              turnIndicator = turnIndicator
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 0.75, end: 1.0, duration: 900.ms);
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  turnIndicator,

                  const SizedBox(height: 16),

                  // Game Table - Show submitted hands
                  _buildGameTable(game, players),

                  const SizedBox(height: 16),

                  // Opponents Section
                  if (opponents.isNotEmpty) ...[
                    Text('Opponents', style: AppTheme.heading(size: 18)),
                    const SizedBox(height: 12),
                    ...opponents.map((opponent) {
                      final opponentData = publicData[opponent.id];
                      if (opponentData == null) return const SizedBox();
                      return _buildOpponentDice(opponent, opponentData);
                    }),
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white24, thickness: 1),
                  const SizedBox(height: 16),

                  // Your Dice Section with Selection
                  Text('Your Dice',
                      style: AppTheme.display(size: 20, color: Colors.white)),
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
    final submissions = game.handSubmissions;

    if (submissions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text(
            'No hands played yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.navyPanel(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart, color: AppTheme.gold, size: 20),
              const SizedBox(width: 8),
              Text('Played Hands',
                  style: AppTheme.heading(size: 16, color: Colors.white)),
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
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.navyLight,
                    radius: 14,
                    child: Text(
                      player.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: List.generate(3, (index) {
                        final value = diceValues[index];
                        final type = diceTypes[index];

                        Color? color;
                        if (type == 'red') color = AppTheme.diceRed;
                        if (type == 'blue') color = AppTheme.diceBlue;

                        return DiceWidget(
                          value: value,
                          size: 40,
                          color: color,
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOpponentDice(Player opponent, PublicPlayerData data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.navyLight,
                radius: 16,
                child: Text(
                  opponent.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.gold,
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
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${data.totalDiceRemaining} dice left',
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Visible Dice:',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70),
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
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DiceWidget(
                value: data.redDiceUsed ? 0 : null,
                size: 45,
                color: AppTheme.diceRed,
                isUsed: data.redDiceUsed,
              ),
              const SizedBox(width: 8),
              DiceWidget(
                value: data.blueDiceUsed ? 0 : null,
                size: 45,
                color: AppTheme.diceBlue,
                isUsed: data.blueDiceUsed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
