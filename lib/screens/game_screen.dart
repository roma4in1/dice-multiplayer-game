import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/game_state.dart';
import '../models/dice_info.dart';
import '../models/hand_result.dart';
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

  // Countdown timer
  Timer? _turnTimer;
  int _secondsLeft = 45;
  String? _timedTurnFor;

  // Floating reaction overlay
  String? _floatingEmoji;
  String? _floatingFromPlayer;
  Timer? _reactionTimer;
  Map<String, dynamic> _lastSeenReactions = {};

  @override
  void dispose() {
    _turnTimer?.cancel();
    _reactionTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(String turnPlayerId, PlayerDice myDice, GameState game) {
    if (_timedTurnFor == turnPlayerId) return;
    _timedTurnFor = turnPlayerId;
    _secondsLeft = 45;
    _turnTimer?.cancel();
    final isMyTurnToAutoSubmit = turnPlayerId == _authService.currentUserId;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        // Only auto-submit for the player whose turn it actually is
        if (isMyTurnToAutoSubmit) _autoSubmit(myDice, game);
      }
    });
  }

  void _resetCountdown() {
    _turnTimer?.cancel();
    _timedTurnFor = null;
    if (mounted) setState(() => _secondsLeft = 45);
  }

  Future<void> _autoSubmit(PlayerDice myDice, GameState game) async {
    if (_isSubmittingHand) return; // in-flight call — let it finish
    final myId = _authService.currentUserId!;
    if (game.handSubmissions.containsKey(myId)) return;

    final available = myDice.allDice
        .where((d) => !myDice.usedIndices.contains(d.index))
        .toList();
    if (available.length < 3) return;

    // Try every combination of 3 dice and keep the strongest hand
    List<int>? bestIndices;
    HandResult? bestResult;
    for (int i = 0; i < available.length - 2; i++) {
      for (int j = i + 1; j < available.length - 1; j++) {
        for (int k = j + 1; k < available.length; k++) {
          final combo = [available[i], available[j], available[k]];
          final values = combo.map((d) => d.value).toList();
          final result = HandEvaluator.evaluateHand('', '', values);
          if (bestResult == null ||
              HandEvaluator.compareHands(result, bestResult!) > 0) {
            bestResult = result;
            bestIndices = combo.map((d) => d.index).toList();
          }
        }
      }
    }

    if (bestIndices == null) return;
    final chosen = bestIndices;
    setState(() => _selectedDiceIndices
      ..clear()
      ..addAll(chosen));
    await _submitHand();
  }

  void _checkReactions(GameState game, List<Player> players) {
    final myId = _authService.currentUserId!;
    for (final entry in game.reactions.entries) {
      if (entry.key == myId) continue;
      final data = entry.value as Map<String, dynamic>;
      final ts = data['timestamp'] as String? ?? '';
      final prev = _lastSeenReactions[entry.key];
      if (prev == ts) continue;
      _lastSeenReactions[entry.key] = ts;
      final emoji = data['emoji'] as String? ?? '';
      final sender = players.cast<Player?>().firstWhere(
            (p) => p!.id == entry.key,
            orElse: () => null,
          );
      _showReaction(emoji, sender?.name ?? 'Opponent');
    }
  }

  void _showReaction(String emoji, String fromName) {
    _reactionTimer?.cancel();
    setState(() {
      _floatingEmoji = emoji;
      _floatingFromPlayer = fromName;
    });
    _reactionTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() { _floatingEmoji = null; _floatingFromPlayer = null; });
    });
  }

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
              if (mounted) setState(() => _hasShownHandResults = false);
            });
          }

          // Check for incoming reactions from opponents
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _checkReactions(game, players));

          final isRollingPhase = game.status == GameStatus.rolling;
          final currentlyRolling = game.currentlyRolling;
          final playersWhoRolled = game.playersWhoRolled;
          final myPlayerId = _authService.currentUserId!;
          final myPlayerName = players.cast<Player?>()
              .firstWhere((p) => p!.id == myPlayerId, orElse: () => null)
              ?.name ?? 'Player';
          final haveIRolled = playersWhoRolled.contains(myPlayerId);
          final isMyTurnToRoll =
              !haveIRolled && !_isRolling && currentlyRolling == null;

          return Stack(
            children: [
          Column(
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
          ),
          // ── Floating reaction overlay ──────────────────────────────────
          if (_floatingEmoji != null)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      _floatingEmoji!,
                      style: const TextStyle(fontSize: 72),
                    )
                        .animate()
                        .scale(
                            begin: const Offset(0.3, 0.3),
                            duration: 400.ms,
                            curve: Curves.elasticOut)
                        .then()
                        .fadeOut(delay: 2.seconds, duration: 600.ms),
                    Text(
                      _floatingFromPlayer ?? '',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ).animate().fadeIn(duration: 300.ms),
                  ],
                ),
              ),
            ),
          // ── Emoji chat panel (bottom-left, safe area aware) ───────────
          Positioned(
            bottom: 0,
            left: 0,
            child: SafeArea(
              top: false,
              // minimum ensures we clear browser toolbars on older Android phones
              // even when the OS reports zero safe-area insets
              minimum: const EdgeInsets.only(bottom: 64, left: 12),
              child: _EmojiChatPanel(
                gameId: widget.gameId,
                myPlayerId: myPlayerId,
                myPlayerName: myPlayerName,
                chatMessages: game.chatMessages,
                firestoreService: _firestoreService,
              ),
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

          const SizedBox(height: 16),

          // Live hand preview
          if (_selectedDiceIndices.length == 3) ...[
            Builder(builder: (context) {
              final allDice = myDice.allDice;
              final values = _selectedDiceIndices
                  .map((i) => allDice
                      .firstWhere((d) => d.index == i)
                      .value)
                  .toList();
              final preview = HandEvaluator.evaluateHand('', '', values);
              final rankEmoji = switch (preview.rank.displayName) {
                'Triple'    => '🎯',
                'Straight'  => '📈',
                'Pair'      => '✌️',
                _           => '🃏',
              };
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(rankEmoji,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Text(
                      'Hand: ${preview.rank.displayName}',
                      style: AppTheme.heading(
                          size: 16,
                          color: AppTheme.gold,
                          weight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

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
    if (_isSubmittingHand) return; // prevent concurrent submissions

    setState(() => _isSubmittingHand = true);

    try {
      await _firestoreService.playHand(
        widget.gameId,
        _authService.currentUserId!,
        List<int>.from(_selectedDiceIndices), // snapshot indices before any clear
      ).timeout(const Duration(seconds: 12));

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
        final msg = e.toString().contains('TimeoutException')
            ? 'Connection slow — please try again'
            : 'Error: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
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
                              try {
                                await _firestoreService.rollMyDice(
                                  widget.gameId,
                                  _authService.currentUserId!,
                                  myPlayer.name,
                                ).timeout(const Duration(seconds: 12));
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Roll failed — please try again'),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isRolling = false);
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
                    const SizedBox(height: 10),
                    const Text(
                      'Hidden Dice:',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        DiceWidget(
                            value: null,
                            size: 36,
                            color: AppTheme.diceRed),
                        SizedBox(width: 6),
                        DiceWidget(
                            value: null,
                            size: 36,
                            color: AppTheme.diceBlue),
                      ],
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
    final currentTurnPlayer = game.currentTurn != null
        ? players.firstWhere(
            (p) => p.id == game.currentTurn,
            orElse: () => players.first,
          )
        : players.first;
    final alreadySubmitted = game.handSubmissions.containsKey(myPlayerId);

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

        // Countdown runs for everyone so both players can see it
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (game.currentTurn != null && !game.handEvaluationComplete) {
            _startCountdown(game.currentTurn!, myDice, game);
          } else {
            _resetCountdown();
          }
        });

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

            final timerColor = _secondsLeft <= 10 ? Colors.red : AppTheme.gold;
            final showTimer = game.currentTurn != null && !game.handEvaluationComplete;

            // Sticky turn header — sits above the scroll view, always visible
            Widget turnHeader = Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMyTurn
                    ? AppTheme.gold.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.25),
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
                  // Timer ring — visible to EVERYONE while a turn is active
                  if (showTimer && !alreadySubmitted) ...[
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: _secondsLeft / 45,
                            color: timerColor,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            strokeWidth: 3,
                          ),
                          Center(
                            child: Text(
                              '$_secondsLeft',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: timerColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_secondsLeft}s',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      isMyTurn
                          ? '🎯 YOUR TURN — Select 3 dice!'
                          : '${currentTurnPlayer.name} is choosing...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isMyTurn ? AppTheme.gold : Colors.white70,
                      ),
                    ),
                  ),
                  if (!isMyTurn) ...[
                    const SizedBox(width: 8),
                    const _ThinkingDots(),
                  ],
                ],
              ),
            );

            if (isMyTurn && !alreadySubmitted) {
              turnHeader = turnHeader
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 0.75, end: 1.0, duration: 900.ms);
            }

            return Column(
              children: [
                turnHeader,  // sticky — not inside the scroll view
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                  _buildGameTable(game, players),
                  const SizedBox(height: 16),

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

                  Text('Your Dice',
                      style: AppTheme.display(size: 20, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildYourDiceWithSelection(myDice, isMyTurn, game),
                  const SizedBox(height: 20),
                ],
              ),          // inner Column
            ),            // SingleChildScrollView
          ),              // Expanded
        ],
      );                  // outer Column (return)
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

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> {
  int _dot = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dot = (_dot + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dot;
    return Text(dots,
        style: const TextStyle(
            fontSize: 20, color: Colors.white54, letterSpacing: 2));
  }
}

// ── Emoji Chat Panel ────────────────────────────────────────────────────────

class _EmojiChatPanel extends StatefulWidget {
  final String gameId;
  final String myPlayerId;
  final String myPlayerName;
  final List<Map<String, dynamic>> chatMessages;
  final FirestoreService firestoreService;

  const _EmojiChatPanel({
    required this.gameId,
    required this.myPlayerId,
    required this.myPlayerName,
    required this.chatMessages,
    required this.firestoreService,
  });

  @override
  State<_EmojiChatPanel> createState() => _EmojiChatPanelState();
}

class _EmojiChatPanelState extends State<_EmojiChatPanel> {
  static const _emojis = ['😮', '🔥', '😤', '👏', '😭'];
  static const _cooldownSeconds = 3;

  bool _isOpen = false;
  int _cooldownLeft = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _send(String emoji) {
    if (_cooldownLeft > 0) return;
    widget.firestoreService.sendReaction(
        widget.gameId, widget.myPlayerId, widget.myPlayerName, emoji);
    setState(() => _cooldownLeft = _cooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldownLeft--;
        if (_cooldownLeft <= 0) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return GestureDetector(
        onTap: () => setState(() => _isOpen = true),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.navy.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
          ),
          child: const Center(child: Text('💬', style: TextStyle(fontSize: 20))),
        ),
      );
    }

    // Show last 10 messages, newest at bottom
    final recent = widget.chatMessages.length > 10
        ? widget.chatMessages.sublist(widget.chatMessages.length - 10)
        : widget.chatMessages;

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Reactions',
                      style: AppTheme.heading(
                          size: 12, color: Colors.white70, weight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isOpen = false),
                  child: const Icon(Icons.close, color: Colors.white38, size: 17),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Message list
          SizedBox(
            height: 96,
            child: recent.isEmpty
                ? const Center(
                    child: Text('No reactions yet',
                        style: TextStyle(color: Colors.white30, fontSize: 11)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: recent.length,
                    itemBuilder: (context, i) {
                      final msg = recent[i];
                      final isMe = msg['playerId'] == widget.myPlayerId;
                      final name = isMe ? 'You' : (msg['playerName'] as String? ?? '?');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isMe ? AppTheme.goldLight : Colors.white60,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(msg['emoji'] as String? ?? '',
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Emoji buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _emojis.map((emoji) {
                final canSend = _cooldownLeft <= 0;
                return GestureDetector(
                  onTap: canSend ? () => _send(emoji) : null,
                  child: AnimatedOpacity(
                    opacity: canSend ? 1.0 : 0.35,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Cooldown indicator
          if (_cooldownLeft > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '⏱ ${_cooldownLeft}s cooldown',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ),
        ],
      ),
    );
  }
}
