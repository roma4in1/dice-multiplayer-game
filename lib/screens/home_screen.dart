import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _joinCodeController = TextEditingController();

  int _selectedRounds = 3;
  int _selectedMaxPlayers = 4;
  bool _isLoading = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _createGame() async {
    if (!_authService.isSignedIn) {
      _showError('Please wait, signing in...');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gameId = await _firestoreService.createGame(
        hostId: _authService.currentUserId!,
        hostName: _authService.getDisplayName(),
        maxPlayers: _selectedMaxPlayers,
        totalRounds: _selectedRounds,
      );

      if (!mounted) return;

      if (gameId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => LobbyScreen(gameId: gameId)),
        );
      } else {
        _showError('Failed to create game');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinGame() async {
    final code = _joinCodeController.text.trim();

    if (code.isEmpty) {
      _showError('Please enter a join code');
      return;
    }

    if (!_authService.isSignedIn) {
      _showError('Please wait, signing in...');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gameId = await _firestoreService.joinGame(
        joinCode: code,
        playerId: _authService.currentUserId!,
        playerName: _authService.getDisplayName(),
      );

      if (!mounted) return;

      if (gameId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => LobbyScreen(gameId: gameId)),
        );
      } else {
        _showError('Game not found or is full');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCreateGameDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Number of Rounds:'),
              Slider(
                value: _selectedRounds.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _selectedRounds.toString(),
                onChanged: (value) {
                  setState(() => _selectedRounds = value.toInt());
                  this.setState(() {});
                },
              ),
              const SizedBox(height: 16),
              const Text('Max Players:'),
              Slider(
                value: _selectedMaxPlayers.toDouble(),
                min: 2,
                max: 8,
                divisions: 6,
                label: _selectedMaxPlayers.toString(),
                onChanged: (value) {
                  setState(() => _selectedMaxPlayers = value.toInt());
                  this.setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createGame();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[700]!, Colors.purple[700]!],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Game Title
                  const Icon(Icons.casino, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Dice Game',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Multiplayer Strategy',
                    style: TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                  const SizedBox(height: 60),

                  // Create Game Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _showCreateGameDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.purple[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Create Game',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white54)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white54)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Join Game Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Join Game',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _joinCodeController,
                          decoration: InputDecoration(
                            hintText: 'Enter 6-digit code',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _joinGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Join',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
