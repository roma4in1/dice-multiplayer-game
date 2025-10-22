enum GameStatus { waiting, rolling, betting, playing, roundEnd, gameEnd }

class GameState {
  final String gameId;
  final String hostId;
  final String joinCode;
  final GameStatus status;
  final int maxPlayers;
  final int totalRounds;
  final int currentRound;
  final int currentHand;
  final String? currentTurn;
  final String? currentlyRolling;
  final List<String> playersWhoRolled;
  final List<String> turnOrder;
  final DateTime createdAt;
  final Map<String, dynamic> players;
  // ✅ ADDED THESE FIELDS FOR HAND EVALUATION
  final Map<String, dynamic> handSubmissions;
  final Map<String, dynamic> handResults;
  final String? handWinner; // Kept for backwards compatibility
  final List<String> handWinners; // ✅ NEW: Support multiple winners for ties
  final bool handEvaluationComplete;
  final Map<String, dynamic> publicPlayerData;
  final List<String>
  playersReadyToContinue; // ✅ NEW: Track who clicked continue

  const GameState({
    required this.gameId,
    required this.hostId,
    required this.joinCode,
    required this.status,
    this.maxPlayers = 8,
    this.totalRounds = 3,
    this.currentRound = 0,
    this.currentHand = 0,
    this.currentTurn,
    this.currentlyRolling,
    this.playersWhoRolled = const [],
    this.turnOrder = const [],
    required this.createdAt,
    this.players = const {},
    // ✅ ADDED THESE DEFAULTS
    this.handSubmissions = const {},
    this.handResults = const {},
    this.handWinner,
    this.handWinners = const [], // ✅ NEW
    this.handEvaluationComplete = false,
    this.publicPlayerData = const {},
    this.playersReadyToContinue = const [], // ✅ NEW
  });

  bool get isWaiting => status == GameStatus.waiting;
  bool get isRolling => status == GameStatus.rolling;
  bool get isBetting => status == GameStatus.betting;
  bool get isPlaying => status == GameStatus.playing;
  bool get isRoundEnd => status == GameStatus.roundEnd;
  bool get isGameEnd => status == GameStatus.gameEnd;

  int get playerCount => players.length;
  bool get canStart => playerCount >= 2 && playerCount <= maxPlayers;

  GameState copyWith({
    String? gameId,
    String? hostId,
    String? joinCode,
    GameStatus? status,
    int? maxPlayers,
    int? totalRounds,
    int? currentRound,
    int? currentHand,
    String? currentTurn,
    String? currentlyRolling,
    List<String>? playersWhoRolled,
    List<String>? turnOrder,
    DateTime? createdAt,
    Map<String, dynamic>? players,
    // ✅ ADDED THESE PARAMETERS
    Map<String, dynamic>? handSubmissions,
    Map<String, dynamic>? handResults,
    String? handWinner,
    List<String>? handWinners, // ✅ NEW
    bool? handEvaluationComplete,
    Map<String, dynamic>? publicPlayerData,
    List<String>? playersReadyToContinue, // ✅ NEW
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      hostId: hostId ?? this.hostId,
      joinCode: joinCode ?? this.joinCode,
      status: status ?? this.status,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      totalRounds: totalRounds ?? this.totalRounds,
      currentRound: currentRound ?? this.currentRound,
      currentHand: currentHand ?? this.currentHand,
      currentTurn: currentTurn ?? this.currentTurn,
      currentlyRolling: currentlyRolling ?? this.currentlyRolling,
      playersWhoRolled: playersWhoRolled ?? this.playersWhoRolled,
      turnOrder: turnOrder ?? this.turnOrder,
      createdAt: createdAt ?? this.createdAt,
      players: players ?? this.players,
      // ✅ ADDED THESE FIELDS
      handSubmissions: handSubmissions ?? this.handSubmissions,
      handResults: handResults ?? this.handResults,
      handWinner: handWinner ?? this.handWinner,
      handWinners: handWinners ?? this.handWinners, // ✅ NEW
      handEvaluationComplete:
          handEvaluationComplete ?? this.handEvaluationComplete,
      publicPlayerData: publicPlayerData ?? this.publicPlayerData,
      playersReadyToContinue:
          playersReadyToContinue ?? this.playersReadyToContinue, // ✅ NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'hostId': hostId,
      'joinCode': joinCode,
      'status': status.toString().split('.').last,
      'maxPlayers': maxPlayers,
      'totalRounds': totalRounds,
      'currentRound': currentRound,
      'currentHand': currentHand,
      'currentTurn': currentTurn,
      'currentlyRolling': currentlyRolling,
      'playersWhoRolled': playersWhoRolled,
      'turnOrder': turnOrder,
      'createdAt': createdAt.toIso8601String(),
      'players': players,
      // ✅ ADDED THESE FIELDS
      'handSubmissions': handSubmissions,
      'handResults': handResults,
      'handWinner': handWinner,
      'handWinners': handWinners, // ✅ NEW
      'handEvaluationComplete': handEvaluationComplete,
      'publicPlayerData': publicPlayerData,
      'playersReadyToContinue': playersReadyToContinue, // ✅ NEW
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      gameId: json['gameId'] as String,
      hostId: json['hostId'] as String,
      joinCode: json['joinCode'] as String,
      status: GameStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => GameStatus.waiting,
      ),
      maxPlayers: json['maxPlayers'] as int? ?? 8,
      totalRounds: json['totalRounds'] as int? ?? 3,
      currentRound: json['currentRound'] as int? ?? 0,
      currentHand: json['currentHand'] as int? ?? 0,
      currentTurn: json['currentTurn'] as String?,
      currentlyRolling: json['currentlyRolling'] as String?,
      playersWhoRolled: List<String>.from(json['playersWhoRolled'] ?? []),
      turnOrder: List<String>.from(json['turnOrder'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      players: json['players'] as Map<String, dynamic>? ?? {},
      // ✅ ADDED THESE FIELDS
      handSubmissions: json['handSubmissions'] as Map<String, dynamic>? ?? {},
      handResults: json['handResults'] as Map<String, dynamic>? ?? {},
      handWinner: json['handWinner'] as String?,
      handWinners: json['handWinners'] != null
          ? List<String>.from(json['handWinners'])
          : [], // ✅ NEW
      handEvaluationComplete: json['handEvaluationComplete'] as bool? ?? false,
      publicPlayerData: json['publicPlayerData'] as Map<String, dynamic>? ?? {},
      playersReadyToContinue: json['playersReadyToContinue'] != null
          ? List<String>.from(json['playersReadyToContinue'])
          : [], // ✅ NEW
    );
  }
}

class HandSubmission {
  final String playerId;
  final List<int> selectedIndices;
  final List<int?> diceValues;
  final List<String> diceTypes;
  final bool revealed;

  const HandSubmission({
    required this.playerId,
    required this.selectedIndices,
    required this.diceValues,
    required this.diceTypes,
    this.revealed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'selectedIndices': selectedIndices,
      'diceValues': diceValues,
      'diceTypes': diceTypes,
      'revealed': revealed,
    };
  }

  factory HandSubmission.fromJson(Map<String, dynamic> json) {
    return HandSubmission(
      playerId: json['playerId'] as String,
      selectedIndices: List<int>.from(json['selectedIndices']),
      diceValues: List<int?>.from(json['diceValues']),
      diceTypes: List<String>.from(json['diceTypes']),
      revealed: json['revealed'] as bool? ?? false,
    );
  }
}
