import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/dice_info.dart';
import '../models/hand_result.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();
  static const int pointsPerHand = 5;

  // Generate random 6-digit join code
  String _generateJoinCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Create a new game
  Future<String?> createGame({
    required String hostId,
    required String hostName,
    int maxPlayers = 8,
    int totalRounds = 3,
  }) async {
    try {
      final joinCode = _generateJoinCode();
      final gameRef = _firestore.collection('games').doc();

      final gameState = GameState(
        gameId: gameRef.id,
        hostId: hostId,
        joinCode: joinCode,
        status: GameStatus.waiting,
        maxPlayers: maxPlayers,
        totalRounds: totalRounds,
        createdAt: DateTime.now(),
        players: {
          hostId: Player(
            id: hostId,
            name: hostName,
            isHost: true,
            isReady: true,
            joinedAt: DateTime.now(),
          ).toJson(),
        },
      );

      await gameRef.set(gameState.toJson());

      return gameRef.id;
    } catch (e) {
      return null;
    }
  }

  // Join game by code
  Future<String?> joinGame({
    required String joinCode,
    required String playerId,
    required String playerName,
  }) async {
    try {
      // Find game with join code
      final querySnapshot = await _firestore
          .collection('games')
          .where('joinCode', isEqualTo: joinCode)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null; // Game not found
      }

      final gameRef = querySnapshot.docs.first.reference;

      // Use a transaction so the full-check and add are atomic
      final joined = await _firestore.runTransaction<bool>((tx) async {
        final gameDoc = await tx.get(gameRef);
        if (!gameDoc.exists) return false;

        final gameData = gameDoc.data()!;
        final players = gameData['players'] as Map<String, dynamic>;
        final maxPlayers = gameData['maxPlayers'] as int;

        if (players.length >= maxPlayers) return false;
        if (gameData['status'] != 'waiting') return false;

        final player = Player(
          id: playerId,
          name: playerName,
          joinedAt: DateTime.now(),
        );
        tx.update(gameRef, {'players.$playerId': player.toJson()});
        return true;
      });

      return joined ? gameRef.id : null;
    } catch (e) {
      return null;
    }
  }

  // Get game stream
  Stream<GameState?> getGameStream(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      return GameState.fromJson(snapshot.data()!);
    });
  }

  // Update player ready status
  Future<void> setPlayerReady(
    String gameId,
    String playerId,
    bool ready,
  ) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'players.$playerId.isReady': ready,
      });
    } catch (e) {
      // ignore: setting ready status is best-effort
    }
  }

  // Start game (host only)
  Future<void> startGame(String gameId) async {
    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final gameData = gameDoc.data()!;
      final players = gameData['players'] as Map<String, dynamic>;

      // Initialize round points for all players
      final initialRoundPoints = <String, int>{};
      for (var playerId in players.keys) {
        initialRoundPoints[playerId] = 0;
      }

      await _firestore.collection('games').doc(gameId).update({
        'status': 'rolling',
        'currentRound': 1,
        'currentRoundPoints':
            initialRoundPoints, // ✅ Initialize with all players
        'playersWhoRolled': [],
        'currentlyRolling': null,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Player manually rolls their dice
  Future<void> rollMyDice(
    String gameId,
    String playerId,
    String playerName,
  ) async {
    try {
      // Fire-and-forget: show rolling animation on other clients immediately
      _firestore.collection('games').doc(gameId).update({
        'currentlyRolling': playerId,
      });

      // Compute dice locally — no network needed
      final allDice = List.generate(11, (_) => _random.nextInt(6) + 1);
      final redDie = DiceInfo(value: allDice[0], index: 0, type: DiceType.red);
      final blueDie =
          DiceInfo(value: allDice[1], index: 1, type: DiceType.blue);
      final visibleValues = allDice.sublist(2)..sort();
      final visibleDice = List.generate(
        9,
        (i) => DiceInfo(
            value: visibleValues[i], index: i + 2, type: DiceType.visible),
      );
      final sortedAllDice = [allDice[0], allDice[1], ...visibleValues];

      // Short animation window
      await Future.delayed(const Duration(milliseconds: 800));

      // Single transaction: write secrets + public data + mark rolled
      final gameRef = _firestore.collection('games').doc(gameId);
      final secretRef = _firestore
          .collection('games')
          .doc(gameId)
          .collection('playerSecrets')
          .doc(playerId);

      await _firestore.runTransaction<void>((tx) async {
        final gameDoc = await tx.get(gameRef);
        final gameData = gameDoc.data()!;
        final players = gameData['players'] as Map<String, dynamic>;
        final playersWhoRolled =
            List<String>.from(gameData['playersWhoRolled'] ?? []);

        // Write secret dice (subcollection)
        tx.set(secretRef, {
          'allDice': sortedAllDice,
          'hiddenDice': {
            'red': redDie.toJson(),
            'blue': blueDie.toJson(),
          },
          'visibleDice': visibleDice.map((d) => d.toJson()).toList(),
          'usedIndices': [],
        });

        // Update game doc: public data + rolled status
        final update = <String, dynamic>{
          'publicPlayerData.$playerId': {
            'playerId': playerId,
            'playerName': playerName,
            'visibleDiceValues': visibleValues,
            'usedVisibleIndices': [],
            'redDiceUsed': false,
            'blueDiceUsed': false,
            'totalDiceRemaining': 11,
          },
          'playersWhoRolled': FieldValue.arrayUnion([playerId]),
          'currentlyRolling': null,
        };

        if (!playersWhoRolled.contains(playerId) &&
            playersWhoRolled.length + 1 == players.length) {
          update['status'] = 'betting';
        }

        tx.update(gameRef, update);
      });
    } catch (e) {
      rethrow;
    }
  }

  // Submit bet
  Future<void> submitBet(String gameId, String playerId, String bet) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'players.$playerId.currentBet': bet,
      });

      // Check if all players have bet
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final gameData = gameDoc.data()!;
      final players = gameData['players'] as Map<String, dynamic>;

      final allPlayersBet = players.values.every((player) {
        return player['currentBet'] != null &&
            player['currentBet'].toString().isNotEmpty;
      });

      // If all players have bet, move to playing phase (hand selection)
      if (allPlayersBet) {
        final playerIds = players.keys.toList();

        final initialRoundPoints = <String, int>{};
        for (var playerId in playerIds) {
          initialRoundPoints[playerId] = 0;
        }

        await _firestore.collection('games').doc(gameId).update({
          'status': 'playing',
          'currentHand': 1,
          'currentRoundPoints': initialRoundPoints,
          'currentTurn': playerIds[0], // First player goes first
          'turnOrder': playerIds,
          'handSubmissions': {},
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // Roll dice for a single player
  Future<void> _rollDiceForPlayer(
    String gameId,
    String playerId,
    Map<String, dynamic> playerData,
  ) async {
    try {
      // Roll 11 dice
      final allDice = List.generate(11, (_) => _random.nextInt(6) + 1);

      // First 2 are hidden (red and blue) - keep as is
      final redDie = DiceInfo(value: allDice[0], index: 0, type: DiceType.red);
      final blueDie = DiceInfo(
        value: allDice[1],
        index: 1,
        type: DiceType.blue,
      );

      // Remaining 9 are visible - SORT THEM in ascending order (low to high)
      final visibleValues = allDice.sublist(2);
      visibleValues.sort(); // Ascending order (1 to 6)

      final visibleDice = List.generate(
        9,
        (i) => DiceInfo(
          value: visibleValues[i],
          index: i + 2,
          type: DiceType.visible,
        ),
      );

      // Reconstruct allDice with sorted visible dice
      final sortedAllDice = [allDice[0], allDice[1], ...visibleValues];

      // Store in playerSecrets (private)
      await _firestore
          .collection('games')
          .doc(gameId)
          .collection('playerSecrets')
          .doc(playerId)
          .set({
            'allDice': sortedAllDice,
            'hiddenDice': {'red': redDie.toJson(), 'blue': blueDie.toJson()},
            'visibleDice': visibleDice.map((d) => d.toJson()).toList(),
            'usedIndices': [],
          });

      // Store public data (visible dice only) - sorted
      await _firestore.collection('games').doc(gameId).update({
        'publicPlayerData.$playerId': {
          'playerId': playerId,
          'playerName': playerData['name'],
          'visibleDiceValues': visibleValues, // Already sorted
          'usedVisibleIndices': [],
          'redDiceUsed': false,
          'blueDiceUsed': false,
          'totalDiceRemaining': 11,
        },
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get player's secret dice
  Stream<PlayerDice?> getPlayerDiceStream(String gameId, String playerId) {
    return _firestore
        .collection('games')
        .doc(gameId)
        .collection('playerSecrets')
        .doc(playerId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return PlayerDice.fromJson(snapshot.data()!);
        });
  }

  // Get all players' public dice data
  Stream<Map<String, PublicPlayerData>> getPublicDiceStream(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return {};

      final data = snapshot.data()!;
      final publicData = data['publicPlayerData'] as Map<String, dynamic>?;

      if (publicData == null) return {};

      return publicData.map(
        (key, value) => MapEntry(key, PublicPlayerData.fromJson(value)),
      );
    });
  }

  // Play hand - submit 3 dice
  Future<void> playHand(
    String gameId,
    String playerId,
    List<int> selectedIndices,
  ) async {
    try {
      // Check if it's player's turn
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final gameData = gameDoc.data()!;

      if (gameData['currentTurn'] != playerId) {
        throw Exception('Not your turn!');
      }

      // Check if player already submitted
      final submissions =
          gameData['handSubmissions'] as Map<String, dynamic>? ?? {};
      if (submissions.containsKey(playerId)) {
        throw Exception('You already submitted for this hand!');
      }

      final players = gameData['players'] as Map<String, dynamic>;

      // Get player's secret dice to get actual values
      final secretDoc = await _firestore
          .collection('games')
          .doc(gameId)
          .collection('playerSecrets')
          .doc(playerId)
          .get();

      final secretData = secretDoc.data()!;
      final playerDice = PlayerDice.fromJson(secretData);

      // Get selected dice values and types
      final selectedDice = selectedIndices.map((index) {
        return playerDice.allDice.firstWhere((d) => d.index == index);
      }).toList();

      // Prepare hand submission (hide values for hidden dice until all submit)
      final diceValues = selectedDice.map((d) {
        // If it's a hidden die, store null until reveal phase
        if (d.type == DiceType.red || d.type == DiceType.blue) {
          return null; // Hidden until all players submit
        }
        return d.value;
      }).toList();

      final actualValues = selectedDice.map((d) => d.value).toList();
      final diceTypes = selectedDice
          .map((d) => d.type.toString().split('.').last)
          .toList();

      // Update game with hand submission
      await _firestore.collection('games').doc(gameId).update({
        'handSubmissions.$playerId': {
          'playerId': playerId,
          'selectedIndices': selectedIndices,
          'diceValues': diceValues, // Visible dice shown, hidden are null
          'actualValues': actualValues, // Store actual for later reveal
          'diceTypes': diceTypes,
          'revealed': false,
        },
      });

      // Update used indices in player secrets
      final newUsedIndices = [...playerDice.usedIndices, ...selectedIndices];
      await _firestore
          .collection('games')
          .doc(gameId)
          .collection('playerSecrets')
          .doc(playerId)
          .update({'usedIndices': newUsedIndices});

      // Update public data
      final visibleIndicesUsed = selectedIndices
          .where((i) => i >= 2)
          .map((i) => i - 2)
          .toList();
      final redUsed = selectedIndices.contains(0);
      final blueUsed = selectedIndices.contains(1);

      final publicUpdate = <String, dynamic>{
        'publicPlayerData.$playerId.usedVisibleIndices': FieldValue.arrayUnion(
          visibleIndicesUsed,
        ),
        'publicPlayerData.$playerId.totalDiceRemaining':
            11 - newUsedIndices.length,
      };
      // Only ever set to true — never reset a used die back to false
      if (redUsed) publicUpdate['publicPlayerData.$playerId.redDiceUsed'] = true;
      if (blueUsed) publicUpdate['publicPlayerData.$playerId.blueDiceUsed'] = true;

      await _firestore.collection('games').doc(gameId).update(publicUpdate);

      // Get updated game data and check if all players submitted
      final updatedGameDoc = await _firestore
          .collection('games')
          .doc(gameId)
          .get();
      final updatedGameData = updatedGameDoc.data()!;
      final updatedSubmissions =
          updatedGameData['handSubmissions'] as Map<String, dynamic>;
      final turnOrder = List<String>.from(updatedGameData['turnOrder']);

      // Check if all players have submitted
      if (updatedSubmissions.length == players.length) {
        // All players submitted - reveal hidden dice and evaluate
        await _revealHiddenDice(gameId, updatedSubmissions);
        await _evaluateHand(gameId, players, updatedSubmissions);
      } else {
        // Advance to next player's turn
        final currentIndex = turnOrder.indexOf(playerId);
        final nextIndex = (currentIndex + 1) % turnOrder.length;
        final nextPlayerId = turnOrder[nextIndex];

        await _firestore.collection('games').doc(gameId).update({
          'currentTurn': nextPlayerId,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // Reveal hidden dice after all players submit
  Future<void> _revealHiddenDice(
    String gameId,
    Map<String, dynamic> submissions,
  ) async {
    final updates = <String, dynamic>{};

    for (var entry in submissions.entries) {
      final playerId = entry.key;
      final submission = entry.value as Map<String, dynamic>;
      final actualValues = List<int>.from(submission['actualValues']);

      updates['handSubmissions.$playerId.diceValues'] = actualValues;
      updates['handSubmissions.$playerId.revealed'] = true;
    }

    await _firestore.collection('games').doc(gameId).update(updates);
  }

  Future<void> _evaluateHand(
    String gameId,
    Map<String, dynamic> players,
    Map<String, dynamic> submissions,
  ) async {
    // Evaluate each player's hand
    final handResults = <String, HandResult>{};

    for (var entry in submissions.entries) {
      final playerId = entry.key;
      final submission = entry.value as Map<String, dynamic>;
      final diceValues = List<int>.from(submission['actualValues']);
      final playerName = players[playerId]['name'] as String;

      final result = HandEvaluator.evaluateHand(playerId, playerName, diceValues);
      handResults[playerId] = result;
    }

    // Determine winners (handles ties)
    final winnerIds = HandEvaluator.determineWinners(handResults);
    final isTie = winnerIds.length > 1;

    const int pointsPerHand = 5;
    final pointsPerWinner = isTie
        ? (pointsPerHand / winnerIds.length).ceil()
        : pointsPerHand;

    // Get current round points
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    final gameData = gameDoc.data()!;
    final currentRoundPoints = Map<String, int>.from(
      gameData['currentRoundPoints'] ?? {},
    );

    // Update round points for winners only (totalPoints updated later in _evaluateRoundBets)
    for (var winnerId in winnerIds) {
      currentRoundPoints[winnerId] =
          (currentRoundPoints[winnerId] ?? 0) + pointsPerWinner;
    }

    // ✅ Update HandResult objects with ACTUAL points awarded (accounting for ties)
    for (var winnerId in winnerIds) {
      if (handResults.containsKey(winnerId)) {
        final result = handResults[winnerId]!;
        handResults[winnerId] = HandResult(
          playerId: result.playerId,
          playerName: result.playerName,
          diceValues: result.diceValues,
          rank: result.rank,
          highCard: result.highCard,
          points:
              pointsPerWinner, // ✅ Store actual points awarded (split if tie)
        );
      }
    }

    // ✅ Losers get 0 points
    for (var entry in handResults.entries) {
      if (!winnerIds.contains(entry.key)) {
        final result = entry.value;
        handResults[entry.key] = HandResult(
          playerId: result.playerId,
          playerName: result.playerName,
          diceValues: result.diceValues,
          rank: result.rank,
          highCard: result.highCard,
          points: 0, // ✅ Losers get 0
        );
      }
    }

    // Store results (without updating totalPoints - that happens in _evaluateRoundBets)
    await _firestore.collection('games').doc(gameId).update({
      'handResults': handResults.map((k, v) => MapEntry(k, v.toJson())),
      'handWinner': winnerIds.first,
      'handWinners': winnerIds,
      'handEvaluationComplete': true,
      'currentTurn': null,
      'playersReadyToContinue': [],
      'currentRoundPoints': currentRoundPoints,
    });
  }

  Future<void> markPlayerReadyToContinue(String gameId, String playerId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);

      // Atomically add this player and check if all are ready
      String? nextAction = await _firestore.runTransaction<String?>((tx) async {
        final gameDoc = await tx.get(gameRef);
        final gameData = gameDoc.data()!;
        final players = gameData['players'] as Map<String, dynamic>;
        final playersReady = List<String>.from(
          gameData['playersReadyToContinue'] ?? [],
        );

        // Idempotent: skip if already marked ready
        if (playersReady.contains(playerId)) return null;

        final updatedReady = [...playersReady, playerId];
        tx.update(gameRef, {
          'playersReadyToContinue': FieldValue.arrayUnion([playerId]),
        });

        if (updatedReady.length == players.length) {
          return gameData['status'] as String;
        }
        return null;
      });

      // Only the transaction that completes the set continues the game
      if (nextAction == null) return;

      final gameDoc = await gameRef.get();
      final gameData = gameDoc.data()!;
      final currentHand = gameData['currentHand'] as int;

      if (nextAction == 'roundEnd') {
        await _continueFromRoundResults(gameId);
      } else if (currentHand < 3) {
        await _continueToNextHand(gameId);
      } else {
        await _evaluateRoundBets(gameId);
        await gameRef.update({
          'status': 'roundEnd',
          'playersReadyToContinue': [],
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _continueToNextHand(String gameId) async {
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    final gameData = gameDoc.data()!;
    final currentHand = gameData['currentHand'] as int;
    final turnOrder = List<String>.from(gameData['turnOrder']);
    final handWinners = gameData['handWinners'] != null
        ? List<String>.from(gameData['handWinners'])
        : [];

    // Reorder turn order so winner goes first
    final newTurnOrder = handWinners.isNotEmpty
        ? _reorderTurnOrder(turnOrder, handWinners.first)
        : turnOrder;

    await _firestore.collection('games').doc(gameId).update({
      'status': 'playing',
      'currentHand': currentHand + 1,
      'handSubmissions': {},
      'handResults': {},
      'handWinner': null,
      'handWinners': [],
      'handEvaluationComplete': false,
      'currentTurn': newTurnOrder[0],
      'turnOrder': newTurnOrder,
      'playersReadyToContinue': [],
    });
  }

  /// Continue game from round results screen to next round or game end
  Future<void> _continueFromRoundResults(String gameId) async {
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    final gameData = gameDoc.data()!;
    final currentRound = gameData['currentRound'] as int;
    final totalRounds = gameData['totalRounds'] as int;
    final players = gameData['players'] as Map<String, dynamic>;

    if (currentRound < totalRounds) {
      // Start next round;

      // Reset players' bets
      final updates = <String, dynamic>{
        'status': 'rolling',
        'currentRound': currentRound + 1,
        'currentHand': 0,
        'currentRoundPoints': {},
        'playersWhoRolled': [],
        'currentlyRolling': null,
        'handSubmissions': {},
        'handResults': {},
        'handWinner': null,
        'handWinners': [],
        'handEvaluationComplete': false,
        'currentTurn': null,
        'playersReadyToContinue': [],
      };

      // Clear all players' bets
      for (var playerId in players.keys) {
        updates['players.$playerId.currentBet'] = '';
      }

      await _firestore.collection('games').doc(gameId).update(updates);
    } else {
      await _firestore.collection('games').doc(gameId).update({
        'status': 'gameEnd',
      });
    }
  }

  // Reorder turn order so winner goes first
  List<String> _reorderTurnOrder(List<String> turnOrder, String winnerId) {
    final winnerIndex = turnOrder.indexOf(winnerId);
    if (winnerIndex == -1) return turnOrder;

    return [
      ...turnOrder.sublist(winnerIndex),
      ...turnOrder.sublist(0, winnerIndex),
    ];
  }

  Future<void> _evaluateRoundBets(String gameId) async {
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    final gameData = gameDoc.data()!;
    final players = gameData['players'] as Map<String, dynamic>;
    final currentRoundPoints = Map<String, int>.from(
      gameData['currentRoundPoints'] ?? {},
    );

    final pointsUpdate = <String, dynamic>{};

    for (var playerId in players.keys) {
      final player = players[playerId];
      final bet = player['currentBet'] as String?;
      final roundPoints = currentRoundPoints[playerId] ?? 0;

      // Evaluate bet success
      final betSuccess = _checkBetSuccess(
        bet,
        roundPoints,
        currentRoundPoints,
        playerId,
      );

      // Calculate final points to add
      int pointsToAdd = roundPoints; // Base case: failed bet

      if (betSuccess) {
        if (bet == 'zero') {
          pointsToAdd = 30; // Fixed bonus
        } else {
          pointsToAdd = roundPoints * 2; // Double points
        }
      }

      // Add to total points
      final currentTotal = player['totalPoints'] as int? ?? 0;
      pointsUpdate['players.$playerId.totalPoints'] =
          currentTotal + pointsToAdd;
    }

    // Update database
    await _firestore.collection('games').doc(gameId).update(pointsUpdate);
  }

  bool _checkBetSuccess(
    String? bet,
    int roundPoints,
    Map<String, int> allRoundPoints,
    String playerId,
  ) {
    if (bet == null) return false;

    switch (bet) {
      case 'zero':
        return roundPoints == 0;
      case 'minimum':
        return roundPoints > 2.5 && roundPoints < 7.5;
      case 'maximum':
        return roundPoints >= 10;
      case 'winner':
        if (allRoundPoints.isEmpty) return false;
        final maxPoints = allRoundPoints.values.reduce((a, b) => a > b ? a : b);
        return roundPoints == maxPoints;
      default:
        return false;
    }
  }

  // Update player name
  Future<void> updatePlayerName(
    String gameId,
    String playerId,
    String newName,
  ) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'players.$playerId.name': newName,
      });

      // Also update in public player data if it exists
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final gameData = gameDoc.data();
      if (gameData != null) {
        final publicData =
            gameData['publicPlayerData'] as Map<String, dynamic>?;
        if (publicData != null && publicData.containsKey(playerId)) {
          await _firestore.collection('games').doc(gameId).update({
            'publicPlayerData.$playerId.playerName': newName,
          });
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Leave game
  Future<void> leaveGame(String gameId, String playerId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) return;

      final gameData = gameDoc.data()!;
      final players = gameData['players'] as Map<String, dynamic>;

      // Remove player
      players.remove(playerId);

      // If host left, assign new host or delete game
      if (gameData['hostId'] == playerId) {
        if (players.isEmpty) {
          // Delete game if no players left
          await gameRef.delete();
        } else {
          // Assign new host
          final newHostId = players.keys.first;
          players[newHostId]['isHost'] = true;

          await gameRef.update({'hostId': newHostId, 'players': players});
        }
      } else {
        await gameRef.update({'players': players});
      }
    } catch (e) {
      // ignore: best-effort cleanup
    }
  }

  Future<void> sendReaction(
      String gameId, String playerId, String emoji) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'reactions.$playerId': {
          'emoji': emoji,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      // ignore: best-effort
    }
  }

  Future<void> voteRematch(String gameId, String playerId,
      GameState game) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final players = game.players;
      final newVotes = [...game.rematchVotes, playerId];

      if (newVotes.length >= players.length) {
        // All voted — create new game
        final newRef = _firestore.collection('games').doc();
        final newJoinCode = _generateJoinCode();
        final hostId = game.hostId;

        final initialPlayers = <String, dynamic>{};
        for (final entry in players.entries) {
          final p = Map<String, dynamic>.from(entry.value as Map);
          p['isReady'] = p['id'] == hostId;
          p['currentBet'] = null;
          p['totalPoints'] = 0;
          initialPlayers[entry.key] = p;
        }

        await newRef.set({
          'gameId': newRef.id,
          'hostId': hostId,
          'joinCode': newJoinCode,
          'status': 'waiting',
          'maxPlayers': game.maxPlayers,
          'totalRounds': game.totalRounds,
          'currentRound': 0,
          'currentHand': 0,
          'players': initialPlayers,
          'createdAt': DateTime.now().toIso8601String(),
          'playersWhoRolled': [],
          'turnOrder': [],
          'handSubmissions': {},
          'handResults': {},
          'handWinners': [],
          'handEvaluationComplete': false,
          'publicPlayerData': {},
          'playersReadyToContinue': [],
          'currentRoundPoints': {},
          'reactions': {},
          'rematchVotes': [],
        });

        await gameRef.update({
          'rematchVotes': newVotes,
          'rematchGameId': newRef.id,
        });
      } else {
        await gameRef.update({
          'rematchVotes': FieldValue.arrayUnion([playerId]),
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}
