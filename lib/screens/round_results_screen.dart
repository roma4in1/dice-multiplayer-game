import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/dice_info.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/dice_widget.dart';

class RoundResultsScreen extends StatefulWidget {
  final String gameId;

  const RoundResultsScreen({super.key, required this.gameId});

  @override
  State<RoundResultsScreen> createState() => _RoundResultsScreenState();
}

class _RoundResultsScreenState extends State<RoundResultsScreen> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final myPlayerId = authService.currentUserId!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Round Complete'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<GameState?>(
        stream: firestoreService.getGameStream(widget.gameId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final game = snapshot.data!;

          if (game.status == GameStatus.gameEnd && !_hasNavigated) {
            _hasNavigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });

            return Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.feltGradient),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events,
                        size: 80, color: AppTheme.gold),
                    const SizedBox(height: 20),
                    Text('Game Complete!',
                        style: AppTheme.display(
                            size: 28, color: AppTheme.gold)),
                    const SizedBox(height: 12),
                    const Text('Returning to home...',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: AppTheme.gold),
                  ],
                ),
              ),
            );
          }

          // Navigate away when round continues to rolling phase
          if (game.status == GameStatus.rolling && !_hasNavigated) {
            _hasNavigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
          }

          final players = game.players.entries
              .map((e) => Player.fromJson(e.value))
              .toList();

          players.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

          final playersReady = game.playersReadyToContinue;
          final iAmReady = playersReady.contains(myPlayerId);

          final betResults = <String, Map<String, dynamic>>{};
          for (var player in players) {
            final roundPoints = game.currentRoundPoints[player.id] ?? 0;
            final bet = player.currentBet ?? '';
            final betSuccess = _evaluateBet(bet, roundPoints, game, player.id);
            final pointsAdded = _calculatePointsAdded(
              bet,
              roundPoints,
              betSuccess,
            );
            betResults[player.id] = {
              'roundPoints': roundPoints,
              'bet': bet,
              'betSuccess': betSuccess,
              'pointsAdded': pointsAdded,
            };
          }

          final isLastRound = game.currentRound >= game.totalRounds;

          return Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.feltGradient),
            child: Column(
              children: [
                // ── Round Complete Header ────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration:
                      const BoxDecoration(gradient: AppTheme.navyGradient),
                  child: Column(
                    children: [
                      Icon(
                        isLastRound ? Icons.emoji_events : Icons.flag,
                        size: 52,
                        color: AppTheme.gold,
                      )
                          .animate()
                          .scale(
                              begin: const Offset(0.5, 0.5),
                              duration: 500.ms,
                              curve: Curves.elasticOut),
                      const SizedBox(height: 10),
                      Text(
                        isLastRound
                            ? 'Game Complete!'
                            : 'Round ${game.currentRound} Complete!',
                        style: AppTheme.display(size: 26, color: AppTheme.gold),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 6),
                      Text(
                        isLastRound
                            ? 'Final Results'
                            : 'Round ${game.currentRound + 1} coming up...',
                        style: AppTheme.heading(
                            size: 14,
                            color: Colors.white60,
                            weight: FontWeight.w400),
                      ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
                    ],
                  ),
                ),

                // ── Results List ─────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final result = betResults[player.id]!;
                      final isMe = player.id == myPlayerId;
                      final betSuccess = result['betSuccess'] as bool;
                      final isFirst = index == 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppTheme.gold.withValues(alpha: 0.12)
                              : AppTheme.cardIvory.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isFirst
                                ? AppTheme.gold
                                : isMe
                                ? AppTheme.gold.withValues(alpha: 0.5)
                                : AppTheme.cardBorder,
                            width: isFirst || isMe ? 2 : 1,
                          ),
                          boxShadow: isFirst
                              ? [
                                  BoxShadow(
                                    color: AppTheme.gold.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Player Header
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isFirst
                                        ? AppTheme.gold
                                        : AppTheme.navyLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '#${index + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isFirst
                                            ? AppTheme.navy
                                            : Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  backgroundColor: AppTheme.navyLight,
                                  radius: 18,
                                  child: Text(
                                    player.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: isFirst
                                          ? AppTheme.gold
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isMe
                                        ? '${player.name} (You)'
                                        : player.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${player.totalPoints} pts',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isFirst
                                        ? AppTheme.gold
                                        : AppTheme.navy,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),
                            Divider(color: AppTheme.cardBorder, height: 1),
                            const SizedBox(height: 10),

                            // Round Performance
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Round Points',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                    Text(
                                      '${result['roundPoints']} pts',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Bet',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                    Text(
                                      _getBetDisplayName(result['bet']),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.navy,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: betSuccess
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: betSuccess
                                          ? Colors.green
                                          : Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        betSuccess
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: betSuccess
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        betSuccess ? 'SUCCESS' : 'FAILED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: betSuccess
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Points Calculation
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: betSuccess
                                    ? AppTheme.gold.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    betSuccess
                                        ? _getSuccessMessage(result['bet'])
                                        : 'No bonus applied',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: betSuccess
                                          ? AppTheme.goldDark
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '+${result['pointsAdded']} pts',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: betSuccess
                                          ? AppTheme.goldDark
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate(delay: (index * 100).ms)
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.15, end: 0);
                    },
                  ),
                ),

                // ── Hidden Dice Reveal ───────────────────────────────
                _HiddenDiceReveal(
                    gameId: widget.gameId, players: players),

                // ── Player Ready Status ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Icon(
                        playersReady.length == players.length
                            ? Icons.check_circle
                            : Icons.schedule,
                        color: playersReady.length == players.length
                            ? Colors.greenAccent
                            : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${playersReady.length} / ${players.length} players ready',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70),
                        ),
                      ),
                      ...players.map((player) {
                        final isReady =
                            playersReady.contains(player.id);
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: isReady
                                ? Colors.greenAccent
                                : Colors.white24,
                            child: Text(
                              player.name[0].toUpperCase(),
                              style: TextStyle(
                                color: isReady
                                    ? AppTheme.navy
                                    : Colors.white54,
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

                // ── Continue Button ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black.withValues(alpha: 0.2),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: iAmReady
                          ? null
                          : () async {
                              await firestoreService
                                  .markPlayerReadyToContinue(
                                widget.gameId,
                                myPlayerId,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            iAmReady ? Colors.white24 : AppTheme.gold,
                        foregroundColor:
                            iAmReady ? Colors.white54 : AppTheme.navy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: iAmReady
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_circle, size: 20),
                                SizedBox(width: 8),
                                Text('Waiting for other players...',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            )
                          : Text(
                              isLastRound
                                  ? 'Return to Home'
                                  : 'Continue to Next Round',
                              style: AppTheme.heading(
                                  size: 17,
                                  color: AppTheme.navy,
                                  weight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _evaluateBet(
    String bet,
    int roundPoints,
    GameState game,
    String playerId,
  ) {
    switch (bet) {
      case 'zero':
        return roundPoints == 0;
      case 'minimum':
        return roundPoints >= 3 && roundPoints <= 9;
      case 'maximum':
        return roundPoints >= 10;
      case 'winner':
        final allRoundPoints = game.currentRoundPoints;
        if (allRoundPoints.isEmpty) return false;
        final maxPoints =
            allRoundPoints.values.reduce((a, b) => a > b ? a : b);
        return roundPoints == maxPoints;
      default:
        return false;
    }
  }

  int _calculatePointsAdded(String bet, int roundPoints, bool betSuccess) {
    if (!betSuccess) return roundPoints;

    switch (bet) {
      case 'zero':
        return 30;
      case 'minimum':
      case 'maximum':
      case 'winner':
        return roundPoints * 2;
      default:
        return roundPoints;
    }
  }

  String _getBetDisplayName(String bet) {
    switch (bet) {
      case 'zero':
        return 'ZERO';
      case 'minimum':
        return 'MINIMUM';
      case 'maximum':
        return 'MAXIMUM';
      case 'winner':
        return 'WINNER';
      default:
        return bet.toUpperCase();
    }
  }

  String _getSuccessMessage(String bet) {
    switch (bet) {
      case 'zero':
        return 'Zero bonus! +30 pts';
      case 'minimum':
      case 'maximum':
      case 'winner':
        return 'Points doubled!';
      default:
        return '';
    }
  }
}

class _HiddenDiceReveal extends StatefulWidget {
  final String gameId;
  final List<Player> players;

  const _HiddenDiceReveal({required this.gameId, required this.players});

  @override
  State<_HiddenDiceReveal> createState() => _HiddenDiceRevealState();
}

class _HiddenDiceRevealState extends State<_HiddenDiceReveal> {
  bool _revealed = false;
  Map<String, PlayerDice?> _diceData = {};
  bool _loading = false;

  Future<void> _reveal() async {
    setState(() => _loading = true);
    final firestore = FirestoreService();
    final results = <String, PlayerDice?>{};
    for (final player in widget.players) {
      try {
        final data = await firestore
            .getPlayerDiceStream(widget.gameId, player.id)
            .first;
        results[player.id] = data;
      } catch (_) {
        results[player.id] = null;
      }
    }
    if (mounted) setState(() { _diceData = results; _revealed = true; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 400),
        crossFadeState: _revealed
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _reveal,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: AppTheme.gold, strokeWidth: 2))
                  : const Icon(Icons.visibility, color: AppTheme.gold),
              label: Text(
                _loading ? 'Revealing...' : '👁 Reveal Hidden Dice',
                style: const TextStyle(color: AppTheme.gold, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.gold),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        secondChild: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hidden Dice Revealed',
                      style: AppTheme.heading(size: 15, color: AppTheme.gold))
                  .animate()
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 12),
              ...widget.players.asMap().entries.map((entry) {
                final i = entry.key;
                final player = entry.value;
                final dice = _diceData[player.id];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.navyLight,
                        radius: 14,
                        child: Text(player.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Text(player.name,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                      const SizedBox(width: 12),
                      if (dice != null) ...[
                        DiceWidget(
                            value: dice.hiddenDice.red.value,
                            size: 38,
                            color: AppTheme.diceRed),
                        const SizedBox(width: 6),
                        DiceWidget(
                            value: dice.hiddenDice.blue.value,
                            size: 38,
                            color: AppTheme.diceBlue),
                      ] else
                        const Text('—',
                            style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
                    .animate(delay: (i * 200).ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.2, end: 0);
              }),
            ],
          ),
        ),
      ),
    );
  }
}
