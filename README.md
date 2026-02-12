# 🎲 Dice Multiplayer Game

A real-time multiplayer dice game built with Flutter and Firebase. Players compete across 2-8 devices simultaneously in strategic poker-style dice matches.

## 🎮 Features

- **Real-time Multiplayer**: 2-8 players on separate devices
- **Simple Lobbies**: Join games with 6-digit codes
- **Strategic Gameplay**: Poker-style hands (Triple, Straight, Pair, High Card)
- **Betting System**: Predict your performance for bonus points
- **Hidden Information**: 2 secret dice per player create bluffing opportunities
- **Cross-Platform**: Works on iOS, Android, and Web

## 🚀 Quick Start

### Play Now

Visit: **https://dice-multiplayer-game.web.app**

### Run Locally

```bash
# Clone the repository
git clone https://github.com/roma4in1/dice-multiplayer-game.git
cd dice-multiplayer-game

# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Run on Android/iOS
flutter run
```

## 🏗️ Tech Architecture

### Stack Overview

```
┌─────────────────────────────────────────────────────┐
│                     Flutter App                     │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐│
│  │   Device 1  │   │   Device 2  │   │   Device 3  ││
│  │  (iOS/Web)  │   │  (Android)  │   │    (Web)    ││
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘│
│         │                 │                 │       │
│         └─────────────────┴─────────────────┘       │
│                           │                         │
│              ┌────────────▼───────────────┐         │
│              │   Firebase Firestore       │         │
│              │  (Real-time Database)      │         │
│              └────────────┬───────────────┘         │
│                           │                         │
│              ┌────────────▼───────────────┐         │
│              │   Firebase Auth            │         │
│              │  (Anonymous Sign-in)       │         │
│              └────────────────────────────┘         │
└─────────────────────────────────────────────────────┘
```

### Key Technologies

| Component            | Technology         | Purpose                     |
| -------------------- | ------------------ | --------------------------- |
| **Frontend**         | Flutter 3.x        | Cross-platform UI framework |
| **Backend**          | Firebase Firestore | Real-time NoSQL database    |
| **Authentication**   | Firebase Auth      | Anonymous user sessions     |
| **Hosting**          | Firebase Hosting   | Web deployment              |
| **State Management** | StreamBuilder      | Reactive UI updates         |
| **Language**         | Dart               | Type-safe programming       |

### Data Architecture

#### Firestore Structure

```
games/
  {gameId}/
    ├── gameId: string
    ├── joinCode: string (6-digit)
    ├── status: enum (waiting|rolling|betting|playing|roundEnd|gameEnd)
    ├── hostId: string
    ├── currentRound: int
    ├── currentHand: int
    ├── players: map
    │   └── {playerId}:
    │       ├── name: string
    │       ├── totalPoints: int
    │       ├── currentBet: string
    │       └── isReady: boolean
    ├── handSubmissions: map
    ├── handResults: map
    ├── currentRoundPoints: map
    └── playersReadyToContinue: array

    playerSecrets/  (subcollection)
      {playerId}/
        ├── allDice: array[11]
        ├── hiddenDice: {red, blue}
        ├── visibleDice: array[9]
        └── usedIndices: array
```

#### Security Model

- **Public Data**: Game state, visible dice, player names
- **Private Data**: Hidden dice values stored in subcollection
- **Access Control**: Firestore Security Rules enforce read/write permissions

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Games are readable by anyone, writable by participants
    match /games/{gameId} {
      allow read: if true;
      allow write: if request.auth != null;

      // Player secrets only readable by owner
      match /playerSecrets/{playerId} {
        allow read: if request.auth.uid == playerId;
        allow write: if request.auth.uid == playerId;
      }
    }
  }
}
```

### Real-Time Synchronization

**How It Works:**

1. **Stream-Based Updates**

```dart
Stream<GameState?> getGameStream(String gameId) {
  return _firestore
    .collection('games')
    .doc(gameId)
    .snapshots()
    .map((snapshot) => GameState.fromJson(snapshot.data()!));
}
```

2. **Reactive UI**

```dart
StreamBuilder<GameState?>(
  stream: _firestoreService.getGameStream(gameId),
  builder: (context, snapshot) {
    final game = snapshot.data!;
    // UI rebuilds automatically on data changes
    return GameWidget(game);
  },
)
```

3. **Atomic Operations**

```dart
// Transaction ensures no race conditions
await _firestore.runTransaction((transaction) async {
  final gameDoc = await transaction.get(gameRef);
  transaction.update(gameRef, {'currentTurn': nextPlayerId});
});
```

### Game Flow State Machine

```
WAITING (Lobby)
    ↓
ROLLING (Each player rolls 11 dice)
    ↓
BETTING (Choose strategy: ZERO/MINIMUM/MAXIMUM/WINNER)
    ↓
PLAYING (Play 3 hands per round)
    ↓  → (Repeat 3x)
    ↓
ROUND_END (Evaluate bets, award points)
    ↓  → (Repeat N rounds)
    ↓
GAME_END (Final standings)
```

### Code Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase config
│
├── models/                      # Data models
│   ├── game_state.dart         # Game state & enums
│   ├── player.dart             # Player & public data
│   ├── dice_info.dart          # Dice structures
│   └── hand_result.dart        # Hand evaluation
│
├── screens/                     # UI screens
│   ├── home_screen.dart        # Main menu
│   ├── lobby_screen.dart       # Pre-game lobby
│   ├── game_screen.dart        # Main gameplay
│   ├── betting_screen.dart     # Betting phase
│   ├── hand_results_screen.dart # Hand winner
│   └── round_results_screen.dart # Round standings
│
├── services/                    # Business logic
│   ├── auth_service.dart       # Authentication
│   └── firestore_service.dart  # Game logic & DB
│
└── widgets/                     # Reusable components
    ├── dice_widget.dart        # Dice display
    ├── rolling_dice_widget.dart # Animated dice
    └── player_card.dart        # Player info card
```

## 🎯 Game Rules

### Objective

Win the most points across multiple rounds by forming the best dice combinations and successfully predicting your performance.

### Gameplay

1. **Rolling Phase**
   - Each player receives 11 dice
   - 2 hidden (red & blue) - only you see these
   - 9 visible - everyone sees these
   - Visible dice sorted low to high for easier analysis

2. **Betting Phase**
   - Predict your round performance:
     - **ZERO**: Win 0 points (high risk, +20 pts bonus)
     - **MINIMUM**: Win 3-7 points (×2 multiplier)
     - **MAXIMUM**: Win 8-9 points (×2 multiplier)
     - **WINNER**: Win the most points (×2 multiplier)

3. **Playing Phase** (3 hands per round)
   - Select 3 dice to form a hand
   - Hand rankings (high to low):
     - **Triple**: Three of the same (e.g., 5-5-5)
     - **Straight**: Three in sequence (e.g., 3-4-5)
     - **Pair**: Two of the same (e.g., 4-4-6)
     - **High Card**: No combination (e.g., 2-4-6)
   - Winner takes all 5 points
   - Ties split points equally
   - Used dice cannot be reused
   - Last hand's winner plays first next hand

4. **Round End**
   - Bets evaluated
   - Bonus points awarded for successful bets
   - Leaderboard updated

## 🔧 Development

### Prerequisites

- Flutter SDK 3.0+
- Firebase CLI
- Android Studio / Xcode (for mobile)

### Firebase Setup

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in project
firebase init

# Deploy to Firebase Hosting
firebase deploy
```

### Testing Multiplayer Locally

**Option 1: Multiple Browser Tabs**

```bash
flutter run -d chrome
# Open multiple tabs at localhost:PORT
```

**Option 2: Web + Mobile**

```bash
# Terminal 1: Run on web
flutter run -d chrome

# Terminal 2: Run on Android
flutter run -d android

# Both connect to same Firebase instance
```

**Option 3: Multiple Emulators**

```bash
# Start multiple Android emulators
emulator -avd Pixel_6_API_33
emulator -avd Pixel_4_API_30
```

### Building for Production

```bash
# Web build
flutter build web
firebase deploy --only hosting

# Android APK
flutter build apk --release

# iOS IPA
flutter build ios --release
```

## 📊 Performance

- **Response Time**: <100ms (Firebase real-time updates)
- **Concurrent Games**: Unlimited (Firebase auto-scaling)
- **Players per Game**: 2-8
- **Platform Support**: iOS 12+, Android 5.0+, Modern Web Browsers

## 🤝 Contributing

This is a personal learning project, but suggestions are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is for educational purposes. Feel free to use and modify.

## 🙏 Acknowledgments

- Built as a learning project to explore Flutter and Firebase
- Inspired by classic dice games and poker mechanics
- Thanks to the Flutter and Firebase communities

## 📧 Contact

Romain - GitHub: @roma4in1

Project Link: https://github.com/roma4in1/dice-multiplayer-game

---

**Built using Flutter & Firebase**
