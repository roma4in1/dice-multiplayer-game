enum DiceType { visible, red, blue }

class DiceInfo {
  final int value;
  final int index;
  final DiceType type;
  final bool isUsed;

  const DiceInfo({
    required this.value,
    required this.index,
    required this.type,
    this.isUsed = false,
  });

  DiceInfo copyWith({int? value, int? index, DiceType? type, bool? isUsed}) {
    return DiceInfo(
      value: value ?? this.value,
      index: index ?? this.index,
      type: type ?? this.type,
      isUsed: isUsed ?? this.isUsed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'index': index,
      'type': type.toString().split('.').last,
      'isUsed': isUsed,
    };
  }

  factory DiceInfo.fromJson(Map<String, dynamic> json) {
    return DiceInfo(
      value: json['value'] as int,
      index: json['index'] as int,
      type: DiceType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      isUsed: json['isUsed'] as bool? ?? false,
    );
  }
}

class HiddenDice {
  final DiceInfo red;
  final DiceInfo blue;

  const HiddenDice({required this.red, required this.blue});

  Map<String, dynamic> toJson() {
    return {'red': red.toJson(), 'blue': blue.toJson()};
  }

  factory HiddenDice.fromJson(Map<String, dynamic> json) {
    return HiddenDice(
      red: DiceInfo.fromJson(json['red']),
      blue: DiceInfo.fromJson(json['blue']),
    );
  }
}

class PlayerDice {
  final List<DiceInfo> visibleDice;
  final HiddenDice hiddenDice;
  final List<int> usedIndices;

  const PlayerDice({
    required this.visibleDice,
    required this.hiddenDice,
    this.usedIndices = const [],
  });

  List<DiceInfo> get allDice {
    return [hiddenDice.red, hiddenDice.blue, ...visibleDice];
  }

  List<DiceInfo> get availableDice {
    return allDice.where((d) => !usedIndices.contains(d.index)).toList();
  }

  int get remainingCount {
    return 11 - usedIndices.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'visibleDice': visibleDice.map((d) => d.toJson()).toList(),
      'hiddenDice': hiddenDice.toJson(),
      'usedIndices': usedIndices,
    };
  }

  factory PlayerDice.fromJson(Map<String, dynamic> json) {
    return PlayerDice(
      visibleDice: (json['visibleDice'] as List)
          .map((d) => DiceInfo.fromJson(d))
          .toList(),
      hiddenDice: HiddenDice.fromJson(json['hiddenDice']),
      usedIndices: List<int>.from(json['usedIndices'] ?? []),
    );
  }
}
