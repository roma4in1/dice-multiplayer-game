enum HandRank { highCard, pair, straight, triple }

extension HandRankExtension on HandRank {
  String get displayName {
    switch (this) {
      case HandRank.highCard:
        return 'High Card';
      case HandRank.pair:
        return 'Pair';
      case HandRank.straight:
        return 'Straight';
      case HandRank.triple:
        return 'Triple';
    }
  }
}

class HandResult {
  final String playerId;
  final String playerName;
  final List<int> diceValues;
  final HandRank rank;
  final int highCard;
  final int points;

  const HandResult({
    required this.playerId,
    required this.playerName,
    required this.diceValues,
    required this.rank,
    required this.highCard,
    required this.points,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'diceValues': diceValues,
      'rank': rank.toString().split('.').last,
      'highCard': highCard,
      'points': points,
    };
  }

  factory HandResult.fromJson(Map<String, dynamic> json) {
    return HandResult(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      diceValues: List<int>.from(json['diceValues']),
      rank: HandRank.values.firstWhere(
        (e) => e.toString().split('.').last == json['rank'],
      ),
      highCard: json['highCard'] as int,
      points: json['points'] as int,
    );
  }
}

class HandEvaluator {
  // Evaluate a single hand
  static HandResult evaluateHand(
    String playerId,
    String playerName,
    List<int> diceValues,
  ) {
    final rank = _determineRank(diceValues);
    final highCard = diceValues.reduce((a, b) => a > b ? a : b);

    return HandResult(
      playerId: playerId,
      playerName: playerName,
      diceValues: diceValues,
      rank: rank,
      highCard: highCard,
      points: 5,
    );
  }

  // Determine hand rank based on dice values
  static HandRank _determineRank(List<int> dice) {
    final sorted = [...dice]..sort();
    final counts = <int, int>{};

    for (var value in dice) {
      counts[value] = (counts[value] ?? 0) + 1;
    }

    // Check for triple (all 3 same)
    if (counts.values.any((count) => count == 3)) {
      return HandRank.triple;
    }

    // Check for straight (3 consecutive)
    if (sorted[1] == sorted[0] + 1 && sorted[2] == sorted[1] + 1) {
      return HandRank.straight;
    }

    // Check for pair (2 same)
    if (counts.values.any((count) => count == 2)) {
      return HandRank.pair;
    }

    // High card
    return HandRank.highCard;
  }

  // Compare two hands to determine winner
  static int compareHands(HandResult a, HandResult b) {
    // Compare rank first
    if (a.rank.index != b.rank.index) {
      return a.rank.index - b.rank.index;
    }

    // Same rank, compare high card
    if (a.highCard != b.highCard) {
      return a.highCard - b.highCard;
    }

    // If still tied, compare sum of all dice
    final sumA = a.diceValues.reduce((x, y) => x + y);
    final sumB = b.diceValues.reduce((x, y) => x + y);

    return sumA - sumB;
  }

  // ✅ NEW: Find all winners (handles ties)
  static List<String> determineWinners(Map<String, HandResult> allHands) {
    if (allHands.isEmpty) return [];

    // Find the best hand
    final bestEntry = allHands.entries.reduce(
      (a, b) => compareHands(a.value, b.value) > 0 ? a : b,
    );

    // Find all hands that tie with the best hand
    final winners = <String>[];
    for (var entry in allHands.entries) {
      if (compareHands(entry.value, bestEntry.value) == 0) {
        winners.add(entry.key);
      }
    }

    return winners;
  }

  // ✅ DEPRECATED: Use determineWinners instead
  // Kept for backwards compatibility but returns first winner only
  static String determineWinner(Map<String, HandResult> allHands) {
    final winners = determineWinners(allHands);
    return winners.isEmpty ? '' : winners.first;
  }
}
