class Player {
  final String id;
  final String name;
  final bool isHost;
  final bool isReady;
  final bool isConnected;
  final int totalPoints;
  final String? currentBet;
  final DateTime joinedAt;

  const Player({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isReady = false,
    this.isConnected = true,
    this.totalPoints = 0,
    this.currentBet,
    required this.joinedAt,
  });

  Player copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? isReady,
    bool? isConnected,
    int? totalPoints,
    String? currentBet,
    DateTime? joinedAt,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      isConnected: isConnected ?? this.isConnected,
      totalPoints: totalPoints ?? this.totalPoints,
      currentBet: currentBet ?? this.currentBet,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isHost': isHost,
      'isReady': isReady,
      'isConnected': isConnected,
      'totalPoints': totalPoints,
      'currentBet': currentBet,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      isHost: json['isHost'] as bool? ?? false,
      isReady: json['isReady'] as bool? ?? false,
      isConnected: json['isConnected'] as bool? ?? true,
      totalPoints: json['totalPoints'] as int? ?? 0,
      currentBet: json['currentBet'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
}

class PublicPlayerData {
  final String playerId;
  final String playerName;
  final List<int> visibleDiceValues;
  final List<int> usedVisibleIndices;
  final bool redDiceUsed;
  final bool blueDiceUsed;
  final int totalDiceRemaining;

  const PublicPlayerData({
    required this.playerId,
    required this.playerName,
    required this.visibleDiceValues,
    this.usedVisibleIndices = const [],
    this.redDiceUsed = false,
    this.blueDiceUsed = false,
    required this.totalDiceRemaining,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'visibleDiceValues': visibleDiceValues,
      'usedVisibleIndices': usedVisibleIndices,
      'redDiceUsed': redDiceUsed,
      'blueDiceUsed': blueDiceUsed,
      'totalDiceRemaining': totalDiceRemaining,
    };
  }

  factory PublicPlayerData.fromJson(Map<String, dynamic> json) {
    return PublicPlayerData(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      visibleDiceValues: List<int>.from(json['visibleDiceValues']),
      usedVisibleIndices: List<int>.from(json['usedVisibleIndices'] ?? []),
      redDiceUsed: json['redDiceUsed'] as bool? ?? false,
      blueDiceUsed: json['blueDiceUsed'] as bool? ?? false,
      totalDiceRemaining: json['totalDiceRemaining'] as int,
    );
  }
}
