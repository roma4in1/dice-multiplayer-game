import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/game_state.dart';
import '../models/hand_result.dart';
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

  static const List<Map<String, dynamic>> _betOptions = [
    {
      'type': 'zero',
      'title': 'ZERO',
      'description': 'Score exactly 0 points this round',
      'reward': '+30 pts',
      'rewardDetail': 'fixed bonus',
      'emoji': '🚫',
      'gradient': [Color(0xFF424242), Color(0xFF212121)],
      'glow': Color(0xFF757575),
    },
    {
      'type': 'minimum',
      'title': 'MINIMUM',
      'description': 'Win exactly 1 hand (1–5 pts)',
      'reward': '×2 pts',
      'rewardDetail': 'points doubled',
      'emoji': '📉',
      'gradient': [Color(0xFF1565C0), Color(0xFF0D47A1)],
      'glow': Color(0xFF42A5F5),
    },
    {
      'type': 'maximum',
      'title': 'MAXIMUM',
      'description': 'Win 2 or more hands (6+ pts)',
      'reward': '×2 pts',
      'rewardDetail': 'points doubled',
      'emoji': '📈',
      'gradient': [Color(0xFFE65100), Color(0xFFBF360C)],
      'glow': Color(0xFFFF9800),
    },
    {
      'type': 'winner',
      'title': 'WINNER',
      'description': 'Finish with the highest score',
      'reward': '×2 pts',
      'rewardDetail': 'points doubled',
      'emoji': '🏆',
      'gradient': [Color(0xFFD4AF37), Color(0xFFAA8820)],
      'glow': Color(0xFFFFD54F),
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

          final players = game.players.entries
              .map((e) => Player.fromJson(e.value))
              .toList();
          final playersWithBets = players
              .where((p) => p.currentBet != null && p.currentBet!.isNotEmpty)
              .length;
          final totalPlayers = players.length;

          return Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.feltGradient),
            child: Column(
              children: [
                // ── Round Info Header ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration:
                      const BoxDecoration(gradient: AppTheme.navyGradient),
                  child: Column(
                    children: [
                      Text(
                        'Round ${game.currentRound} of ${game.totalRounds}',
                        style: AppTheme.display(size: 26),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose your betting strategy',
                        style: AppTheme.heading(
                            size: 14,
                            color: Colors.white60,
                            weight: FontWeight.w400),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$playersWithBets / $totalPlayers players have bet',
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable content ─────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (!_betLocked) ...[
                          const SizedBox(height: 14),

                          // Bet suggestion hint from private dice
                          StreamBuilder<PlayerDice?>(
                            stream: _firestoreService.getPlayerDiceStream(
                              widget.gameId,
                              _authService.currentUserId!,
                            ),
                            builder: (context, snap) {
                              if (!snap.hasData || snap.data == null) {
                                return const SizedBox();
                              }
                              return _buildBetHint(snap.data!);
                            },
                          ),

                          // Info banner
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppTheme.gold, size: 18),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Review everyone\'s visible dice before betting',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),
                          _buildAllPlayersDice(players),
                          const SizedBox(height: 20),
                          Divider(
                              color: Colors.white.withValues(alpha: 0.15),
                              thickness: 1),
                          const SizedBox(height: 14),
                        ],

                        // Bet options or locked state
                        if (_betLocked)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock,
                                    size: 72, color: AppTheme.gold),
                                const SizedBox(height: 20),
                                Text('Bet Locked In!',
                                    style: AppTheme.display(
                                        size: 26, color: AppTheme.gold)),
                                const SizedBox(height: 12),
                                Text(
                                  'Your bet: ${_betOptions.firstWhere((b) => b['type'] == _selectedBet)['title']}',
                                  style: AppTheme.heading(
                                      size: 16, color: Colors.white70),
                                ),
                                const SizedBox(height: 40),
                                const Text(
                                  'Waiting for other players...',
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.white54),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '$playersWithBets / $totalPlayers players have bet',
                                  style: AppTheme.heading(
                                      size: 16, color: AppTheme.gold),
                                ),
                                const SizedBox(height: 24),
                                const CircularProgressIndicator(
                                    color: AppTheme.gold),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Select Your Bet:',
                                    style: AppTheme.heading(size: 18)),
                                const SizedBox(height: 14),
                                ..._betOptions.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final option = entry.value;
                                  final isSelected =
                                      _selectedBet == option['type'];
                                  final gradColors = option['gradient']
                                      as List<Color>;
                                  final glowColor =
                                      option['glow'] as Color;

                                  return AnimatedScale(
                                    scale: isSelected ? 1.04 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedBet = option['type'];
                                        });
                                      },
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 14),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: gradColors,
                                                )
                                              : LinearGradient(
                                                  colors: [
                                                    Colors.white.withValues(
                                                        alpha: 0.07),
                                                    Colors.white.withValues(
                                                        alpha: 0.04),
                                                  ],
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected
                                                ? glowColor
                                                : Colors.white24,
                                            width: isSelected ? 2.5 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: glowColor
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 20,
                                                    spreadRadius: 2,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 14),
                                        child: Row(
                                          children: [
                                            // Emoji circle
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.white.withValues(alpha: 0.2)
                                                    : Colors.white.withValues(alpha: 0.08),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(option['emoji'],
                                                    style: const TextStyle(fontSize: 26)),
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Title + description
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    option['title'],
                                                    style: AppTheme.heading(
                                                      size: 16,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : Colors.white70,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    option['description'],
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isSelected
                                                          ? Colors.white60
                                                          : Colors.white38,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // Reward pill — fixed right, always visible
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? AppTheme.gold.withValues(alpha: 0.35)
                                                        : AppTheme.gold.withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: AppTheme.gold,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    option['reward'] as String,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : AppTheme.goldLight,
                                                    ),
                                                  ),
                                                ),
                                                if (isSelected) ...[
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(Icons.check,
                                                        color: gradColors.last,
                                                        size: 16),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                        .animate(
                                            delay: (index * 80).ms)
                                        .fadeIn(duration: 350.ms)
                                        .slideX(
                                            begin: 0.1,
                                            end: 0,
                                            duration: 350.ms),
                                  );
                                }),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Lock In Button ─────────────────────────────────────
                if (!_betLocked)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black.withValues(alpha: 0.2),
                    child: Column(
                      children: [
                        if (_selectedBet != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Selected: ${_betOptions.firstWhere((b) => b['type'] == _selectedBet)['title']}',
                              style: AppTheme.heading(
                                  size: 14, color: AppTheme.gold),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _selectedBet != null
                                ? () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    setState(() => _betLocked = true);
                                    try {
                                      await _firestoreService.submitBet(
                                        widget.gameId,
                                        _authService.currentUserId!,
                                        _selectedBet!,
                                      ).timeout(const Duration(seconds: 12));
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => _betLocked = false);
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to submit bet — please try again'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedBet != null
                                  ? AppTheme.gold
                                  : Colors.white24,
                              foregroundColor: _selectedBet != null
                                  ? AppTheme.navy
                                  : Colors.white38,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Lock In Bet',
                              style: AppTheme.heading(
                                  size: 18,
                                  color: _selectedBet != null
                                      ? AppTheme.navy
                                      : Colors.white38,
                                  weight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You cannot change your bet once locked',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBetHint(PlayerDice myDice) {
    final all = myDice.allDice
        .where((d) => !myDice.usedIndices.contains(d.index))
        .toList();
    if (all.length < 3) return const SizedBox();

    HandResult? best;
    for (int i = 0; i < all.length - 2; i++) {
      for (int j = i + 1; j < all.length - 1; j++) {
        for (int k = j + 1; k < all.length; k++) {
          final vals = [all[i].value, all[j].value, all[k].value];
          final r = HandEvaluator.evaluateHand('', '', vals);
          if (best == null || HandEvaluator.compareHands(r, best) > 0) {
            best = r;
          }
        }
      }
    }
    if (best == null) return const SizedBox();

    final (icon, hint) = switch (best.rank) {
      HandRank.triple  => ('🎯', 'Triple available — MAXIMUM or WINNER looks strong'),
      HandRank.straight => ('📈', 'Straight possible — MAXIMUM worth considering'),
      HandRank.pair    => ('✌️', 'Pair available — MINIMUM is a solid bet'),
      HandRank.highCard => ('🤔', 'Mixed dice — ZERO could pay off big'),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hint: $hint',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildAllPlayersDice(List<Player> players) {
    return StreamBuilder<Map<String, PublicPlayerData>>(
      stream: _firestoreService.getPublicDiceStream(widget.gameId),
      builder: (context, publicSnapshot) {
        if (!publicSnapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.gold));
        }

        final publicData = publicSnapshot.data!;

        return Column(
          children: [
            Text('All Players\' Dice', style: AppTheme.heading(size: 16)),
            const SizedBox(height: 12),
            ...players.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              final isMe = player.id == _authService.currentUserId;
              final data = publicData[player.id];

              if (data == null) return const SizedBox();

              return Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppTheme.gold.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMe ? AppTheme.gold : Colors.white24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.navyLight,
                          radius: 14,
                          child: Text(
                            player.nameInitial,
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMe ? '${player.name} (You)' : player.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isMe ? AppTheme.gold : Colors.white,
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
                              color: Colors.white60),
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
                              color: Colors.white60),
                        ),
                        DiceWidget(
                            value: null, size: 28, color: AppTheme.diceRed),
                        const SizedBox(width: 4),
                        DiceWidget(
                            value: null, size: 28, color: AppTheme.diceBlue),
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
                                  const Text('→ ',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white54)),
                                  DiceWidget(
                                    value: myDice.hiddenDice.red.value,
                                    size: 28,
                                    color: AppTheme.diceRed,
                                  ),
                                  const SizedBox(width: 4),
                                  DiceWidget(
                                    value: myDice.hiddenDice.blue.value,
                                    size: 28,
                                    color: AppTheme.diceBlue,
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
              )
                  .animate(delay: (index * 100).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, end: 0);
            }),
          ],
        );
      },
    );
  }
}
