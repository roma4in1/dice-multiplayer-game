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
      print('Error creating game: $e');
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

      final gameDoc = querySnapshot.docs.first;
      final gameData = gameDoc.data();
      final players = gameData['players'] as Map<String, dynamic>;

      // Check if game is full
      final maxPlayers = gameData['maxPlayers'] as int;
      if (players.length >= maxPlayers) {
        return null; // Game is full
      }

      // Add player to game
      final player = Player(
        id: playerId,
        name: playerName,
        joinedAt: DateTime.now(),
      );

      await gameDoc.reference.update({'players.$playerId': player.toJson()});

      return gameDoc.id;
    } catch (e) {
      print('Error joining game: $e');
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
      print('Error setting player ready: $e');
    }
  }

  // Start game (host only)
  Future<void> startGame(String gameId) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'status': 'rolling',
        'currentRound': 1,
        'playersWhoRolled': [],
        'currentlyRolling': null,
      });
    } catch (e) {
      print('Error starting game: $e');
    }
  }

  // Player manually rolls their dice
  Future<void> rollMyDice(
    String gameId,
    String playerId,
    String playerName,
  ) async {
    try {
      // Mark as currently rolling
      await _firestore.collection('games').doc(gameId).update({
        'currentlyRolling': playerId,
      });

      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 2000));

      // Roll the dice
      await _rollDiceForPlayer(gameId, playerId, {'name': playerName});

      // Mark as done rolling
      await _firestore.collection('games').doc(gameId).update({
        'playersWhoRolled': FieldValue.arrayUnion([playerId]),
        'currentlyRolling': null,
      });

      // Check if all players have rolled
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final gameData = gameDoc.data()!;
      final players = gameData['players'] as Map<String, dynamic>;
      final playersWhoRolled = List<String>.from(
        gameData['playersWhoRolled'] ?? [],
      );

      if (playersWhoRolled.length == players.length) {
        // All players rolled, move to betting
        await _firestore.collection('games').doc(gameId).update({
          'status': 'betting',
        });
      }
    } catch (e) {
      print('Error rolling dice: $e');
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

        await _firestore.collection('games').doc(gameId).update({
          'status': 'playing',
          'currentHand': 1,
          'currentTurn': playerIds[0], // First player goes first
          'turnOrder': playerIds,
          'handSubmissions': {},
        });
      }
    } catch (e) {
      print('Error submitting bet: $e');
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
      print('Error rolling dice for player: $e');
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

      await _firestore.collection('games').doc(gameId).update({
        'publicPlayerData.$playerId.usedVisibleIndices': FieldValue.arrayUnion(
          visibleIndicesUsed,
        ),
        'publicPlayerData.$playerId.redDiceUsed': redUsed ? true : false,
        'publicPlayerData.$playerId.blueDiceUsed': blueUsed ? true : false,
        'publicPlayerData.$playerId.totalDiceRemaining':
            11 - newUsedIndices.length,
      });

      // Get updated game data
      final updatedGameDoc = await _firestore
          .collection('games')
          .doc(gameId)
          .get();
      final updatedGameData = updatedGameDoc.data()!;
      final players = updatedGameData['players'] as Map<String, dynamic>;
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
      print('Error playing hand: $e');
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

  // ✅ FIXED: Evaluate all hands with proper winner determination
  Future<void> _evaluateHand(
    String gameId,
    Map<String, dynamic> players,
    Map<String, dynamic> submissions,
  ) async {
    print('=== EVALUATING HAND ===');

    // Evaluate each player's hand
    final handResults = <String, HandResult>{};

    for (var entry in submissions.entries) {
      final playerId = entry.key;
      final submission = entry.value as Map<String, dynamic>;
      final diceValues = List<int>.from(submission['actualValues']);
      final playerName = players[playerId]['name'] as String;

      final rank = HandEvaluator._determineRank(diceValues);
      final highCard = diceValues.reduce((a, b) => a > b ? a : b);

      // ✅ FIXED: All hands worth same points
      const int fixedPoints = 5;
      final result = HandResult(
        playerId: playerId,
        playerName: playerName,
        diceValues: diceValues,
        rank: rank,
        highCard: highCard,
        points: fixedPoints, // ✅ Same for all hands
      );

      handResults[playerId] = result;

      print('Player: $playerName');
      print('  Dice: $diceValues');
      print('  Rank: ${result.rank.displayName}');
      print('  High Card: ${result.highCard}');
      print('  Points: ${result.points}');
    }

    final winnerIds = HandEvaluator.determineWinners(handResults);
    final isTie = winnerIds.length > 1;

    print('Winners: $winnerIds (${isTie ? "TIE" : "CLEAR WINNER"})');

    const int pointsPerHand = 5;
    final totalPoints = pointsPerHand;

    // Hand rank only determines winner, not point value
    print('Hand worth: $totalPoints points (winner takes all)');

    final pointsPerWinner = isTie
        ? (totalPoints / winnerIds.length).ceil()
        : totalPoints;

    print('Points per winner: $pointsPerWinner');

    // Store results
    await _firestore.collection('games').doc(gameId).update({
      'handResults': handResults.map((k, v) => MapEntry(k, v.toJson())),
      'handWinner': winnerIds.first, // For backwards compatibility
      'handWinners': winnerIds, // ✅ All winners
      'handEvaluationComplete': true,
      'currentTurn': null,
      'playersReadyToContinue': [], // ✅ Reset ready list
    });

    // ✅ FIXED: Award points ONLY to winners
    final updateMap = <String, dynamic>{};
    for (var winnerId in winnerIds) {
      final currentPoints = players[winnerId]['totalPoints'] as int? ?? 0;
      updateMap['players.$winnerId.totalPoints'] =
          currentPoints + pointsPerWinner;
      print(
        'Awarded $pointsPerWinner points to $winnerId (total: ${currentPoints + pointsPerWinner})',
      );
    }

    await _firestore.collection('games').doc(gameId).update(updateMap);

    print('=== END EVALUATING HAND ===\n');
  }

  // ✅ Mark player as ready to continue
  Future<void> markPlayerReadyToContinue(String gameId, String playerId) async {
    try {
      print('=== MARK PLAYER READY ===');
      print('Player: $playerId');

      // Add player to ready list
      await _firestore.collection('games').doc(gameId).update({
        'playersReadyToContinue': FieldValue.arrayUnion([playerId]),
      });

      print('✓ Updated ready list in Firestore');

      // Wait a moment to ensure write completes
      await Future.delayed(const Duration(milliseconds: 100));

      // Check if all players are ready
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final gameData = gameDoc.data()!;
      final players = gameData['players'] as Map<String, dynamic>;
      final playersReady = List<String>.from(
        gameData['playersReadyToContinue'] ?? [],
      );

      print('Total players: ${players.length}');
      print('Players ready: ${playersReady.length}');
      print('Ready list: $playersReady');

      // If all players ready, continue the game
      if (playersReady.length == players.length) {
        print('✅ ALL PLAYERS READY! Continuing game...');
        await _actualContinueGame(gameId);
        print('✅ Game continued successfully');
      } else {
        print(
          '⏳ Waiting for ${players.length - playersReady.length} more player(s)',
        );
      }

      print('=== END MARK PLAYER READY ===\n');
    } catch (e) {
      print('❌ Error marking player ready: $e');
      rethrow;
    }
  }

  // ✅ FIXED: Internal method that actually continues the game with proper round handling
  Future<void> _actualContinueGame(String gameId) async {
    try {
      print('=== ACTUAL CONTINUE GAME ===');

      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final gameData = gameDoc.data()!;
      final currentHand = gameData['currentHand'] as int;
      final currentRound = gameData['currentRound'] as int;
      final totalRounds = gameData['totalRounds'] as int;
      final turnOrder = List<String>.from(gameData['turnOrder']);
      final handWinners = gameData['handWinners'] != null
          ? List<String>.from(gameData['handWinners'])
          : (gameData['handWinner'] != null
                ? [gameData['handWinner'] as String]
                : []);

      print('Current hand: $currentHand');
      print('Current round: $currentRound');
      print('Total rounds: $totalRounds');

      if (currentHand < 3) {
        // Continue to next hand (same round)
        final newTurnOrder = handWinners.isNotEmpty
            ? _reorderTurnOrder(turnOrder, handWinners.first)
            : turnOrder;

        print('➡️ Continuing to hand ${currentHand + 1}');

        await _firestore.collection('games').doc(gameId).update({
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

        print('✅ Successfully continued to next hand');
      } else if (currentRound < totalRounds) {
        // ✅ FIXED: End of round - start new round with rolling phase
        print(
          '➡️ End of round $currentRound, starting round ${currentRound + 1}',
        );

        await _firestore.collection('games').doc(gameId).update({
          'status': 'rolling', // ✅ FIXED: Go back to rolling, not roundEnd
          'currentRound': currentRound + 1, // ✅ FIXED: Increment round
          'currentHand': 0, // Reset hand counter
          'playersWhoRolled': [], // Reset rolling status
          'currentlyRolling': null,
          'handSubmissions': {},
          'handResults': {},
          'handWinner': null,
          'handWinners': [],
          'handEvaluationComplete': false,
          'currentTurn': null,
          'playersReadyToContinue': [],
        });

        print('✅ Successfully started new round');
      } else {
        // Game over
        print('🏁 Game over!');

        await _firestore.collection('games').doc(gameId).update({
          'status': 'gameEnd',
        });

        print('✅ Game ended');
      }

      print('=== END ACTUAL CONTINUE GAME ===\n');
    } catch (e) {
      print('❌ Error continuing game: $e');
      rethrow;
    }
  }

  // ✅ DEPRECATED: Use markPlayerReadyToContinue instead
  // Kept for backwards compatibility
  Future<void> continueGame(String gameId) async {
    await _actualContinueGame(gameId);
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
      print('Error leaving game: $e');
    }
  }
}
