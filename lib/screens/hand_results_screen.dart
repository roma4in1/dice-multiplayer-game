import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/game_state.dart';
import '../models/hand_result.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/dice_widget.dart';
import '../widgets/player_card.dart';
import 'round_results_screen.dart';
import '../widgets/rule_book_button.dart';

class HandResultsScreen extends StatefulWidget {
  final String gameId;

  const HandResultsScreen({super.key, required this.gameId});

  @override
  State<HandResultsScreen> createState() => _HandResultsScreenState();
}

class _HandResultsScreenState extends State<HandResultsScreen> {
  int? _initialHand;
  bool _hasNavigatedToRoundResults = false;
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final myPlayerId = authService.currentUserId!;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hand Results'),
          automaticallyImplyLeading: false,
          actions: const [RuleBookButton()],
        ),
        body: StreamBuilder<GameState?>(
          stream: firestoreService.getGameStream(widget.gameId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final game = snapshot.data!;

            _initialHand ??= game.currentHand;

            // Navigate to round results when round ends
            if (game.status == GameStatus.roundEnd &&
                !_hasNavigatedToRoundResults &&
                !_isNavigating) {
              _hasNavigatedToRoundResults = true;
              _isNavigating = true;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_isNavigating) return;

                Navigator.of(context)
                    .pushReplacement(
                      MaterialPageRoute(
                        builder: (context) =>
                            RoundResultsScreen(gameId: widget.gameId),
                      ),
                    )
                    .then((_) {
                      if (mounted) _isNavigating = false;
                    });
              });

              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.gold),
                    SizedBox(height: 16),
                    Text('Loading round results...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              );
            }

            // Navigate back when hand advances
            if (game.status == GameStatus.playing &&
                _initialHand != null &&
                game.currentHand > _initialHand! &&
                !_isNavigating) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              });
            }

            final players = game.players.entries
                .map((e) => Player.fromJson(e.value))
                .toList();

            final handResultsMap = game.handResults;
            if (handResultsMap.isEmpty) {
              return const Center(
                  child: Text('No results available',
                      style: TextStyle(color: Colors.white70)));
            }

            final results = handResultsMap.entries
                .map((e) => HandResult.fromJson(e.value))
                .toList();

            results.sort((a, b) => HandEvaluator.compareHands(b, a));

            final winnerIds = game.handWinners.isNotEmpty
                ? game.handWinners
                : (game.handWinner != null ? [game.handWinner!] : <String>[]);
            final isTie = winnerIds.length > 1;

            final playersReady = game.playersReadyToContinue;
            final iAmReady = playersReady.contains(myPlayerId);

            final winnerResult = winnerIds.isNotEmpty
                ? results.firstWhere((r) => r.playerId == winnerIds.first)
                : null;

            return Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.feltGradient),
              child: Column(
                children: [
                  // ── Winner Announcement ────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    decoration: const BoxDecoration(
                        gradient: AppTheme.navyGradient),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events,
                                size: 52, color: AppTheme.gold)
                            .animate()
                            .scale(
                                begin: const Offset(0.5, 0.5),
                                end: const Offset(1.0, 1.0),
                                duration: 500.ms,
                                curve: Curves.elasticOut),

                        const SizedBox(height: 10),

                        Text(
                          isTie ? 'It\'s a Tie!' : 'Winner!',
                          style: AppTheme.display(size: 28, color: AppTheme.gold),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms)
                            .slideY(begin: -0.3, end: 0),

                        const SizedBox(height: 6),

                        ...winnerIds.map((winnerId) {
                          final wr =
                              results.firstWhere((r) => r.playerId == winnerId);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              wr.playerName,
                              style: AppTheme.heading(
                                  size: 22, color: Colors.white),
                            )
                                .animate()
                                .fadeIn(delay: 350.ms, duration: 400.ms)
                                .slideY(begin: 0.2, end: 0),
                          );
                        }),

                        if (winnerResult != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            winnerResult.rank.displayName,
                            style: AppTheme.heading(
                                size: 15,
                                color: Colors.white60,
                                weight: FontWeight.w400),
                          ).animate().fadeIn(delay: 450.ms, duration: 300.ms),

                          const SizedBox(height: 8),

                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.goldLight, AppTheme.gold],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isTie
                                  ? '+${winnerResult.points} pts each'
                                  : '+${winnerResult.points} pts',
                              style: AppTheme.heading(
                                  size: 18,
                                  color: AppTheme.navy,
                                  weight: FontWeight.bold),
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 500.ms, duration: 400.ms)
                              .scale(
                                  begin: const Offset(0.8, 0.8),
                                  curve: Curves.elasticOut),

                          const SizedBox(height: 8),

                          ...winnerIds.map((winnerId) {
                            final wp = players.firstWhere(
                                (p) => p.id == winnerId,
                                orElse: () => players.first);
                            final roundTotal =
                                game.currentRoundPoints[winnerId] ?? 0;
                            return Text(
                              '${wp.name}: $roundTotal round pts (${wp.totalPoints} total)',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13),
                            ).animate().fadeIn(delay: 600.ms, duration: 300.ms);
                          }),
                        ],
                      ],
                    ),
                  ),

                  // ── All hands — staggered reveal ───────────────────────
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        final isWinner = winnerIds.contains(result.playerId);

                        return PlayerCard(
                          player: players.firstWhere(
                            (p) => p.id == result.playerId,
                          ),
                          style: PlayerCardStyle.handResults,
                          isMe: result.playerId == myPlayerId,
                          isWinner: isWinner,
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.rank.displayName,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white60),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: result.diceValues
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final idx = entry.key;
                                  final value = entry.value;

                                  final submission =
                                      game.handSubmissions[result.playerId];
                                  final diceTypes = submission != null
                                      ? List<String>.from(
                                          submission['diceTypes'])
                                      : <String>[];
                                  final type = idx < diceTypes.length
                                      ? diceTypes[idx]
                                      : 'visible';

                                  Color? color;
                                  if (type == 'red') color = AppTheme.diceRed;
                                  if (type == 'blue')
                                    color = AppTheme.diceBlue;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: DiceWidget(
                                      value: value,
                                      size: 50,
                                      color: color,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isWinner ? '+${result.points}' : '0',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isWinner
                                      ? AppTheme.gold
                                      : Colors.white38,
                                ),
                              ),
                              Text(
                                '${game.currentRoundPoints[result.playerId] ?? 0} round',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                            .animate(delay: (index * 150).ms)
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.25, end: 0, duration: 400.ms);
                      },
                    ),
                  ),

                  // ── Ready status bar ───────────────────────────────────
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

                  // ── Continue button ────────────────────────────────────
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
                                game.currentHand < 3
                                    ? 'Continue to Next Hand'
                                    : game.currentRound < game.totalRounds
                                    ? 'Continue to Next Round'
                                    : 'View Final Results',
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
      ),
    );
  }
}
