import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _joinCodeController = TextEditingController();

  int _selectedRounds = 3;
  int _selectedMaxPlayers = 4;
  bool _isLoading = false;

  late final AnimationController _rotController;

  @override
  void initState() {
    super.initState();
    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _rotController.dispose();
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
          MaterialPageRoute(builder: (_) => LobbyScreen(gameId: gameId)),
        );
      } else {
        _showError('Failed to create game');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGame() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) { _showError('Please enter a join code'); return; }
    if (!_authService.isSignedIn) { _showError('Please wait, signing in...'); return; }

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
          MaterialPageRoute(builder: (_) => LobbyScreen(gameId: gameId)),
        );
      } else {
        _showError('Game not found or is full');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCreateGameDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          backgroundColor: AppTheme.cardIvory,
          title: Text('Create Game', style: AppTheme.heading(color: AppTheme.navy)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Number of Rounds: $_selectedRounds',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: _selectedRounds.toDouble(),
                min: 1, max: 10, divisions: 9,
                activeColor: AppTheme.gold,
                label: _selectedRounds.toString(),
                onChanged: (v) {
                  setD(() => _selectedRounds = v.toInt());
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              Text('Max Players: $_selectedMaxPlayers',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: _selectedMaxPlayers.toDouble(),
                min: 2, max: 8, divisions: 6,
                activeColor: AppTheme.gold,
                label: _selectedMaxPlayers.toString(),
                onChanged: (v) {
                  setD(() => _selectedMaxPlayers = v.toInt());
                  setState(() {});
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
              onPressed: () { Navigator.pop(context); _createGame(); },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
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
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Animated casino dice icon ─────────────────────────
                  AnimatedBuilder(
                    animation: _rotController,
                    builder: (_, __) => Transform.rotate(
                      angle: math.sin(_rotController.value * math.pi * 2) * 0.18,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.goldLight, AppTheme.gold, AppTheme.goldDark],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x88D4AF37),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.casino, size: 60, color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Title ─────────────────────────────────────────────
                  Text('Dice Game', style: AppTheme.display(size: 44))
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: -0.3, end: 0, duration: 600.ms),

                  const SizedBox(height: 8),

                  Text(
                    'Multiplayer Strategy',
                    style: AppTheme.heading(size: 16, color: Colors.white70, weight: FontWeight.w400),
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                  const SizedBox(height: 56),

                  // ── Create Game button ────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _showCreateGameDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('Create Game',
                              style: AppTheme.heading(
                                size: 20,
                                color: AppTheme.navy,
                                weight: FontWeight.bold,
                              )),
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                  const SizedBox(height: 24),

                  // ── Divider ───────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white38)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR',
                            style: AppTheme.heading(
                              size: 13,
                              color: Colors.white60,
                              weight: FontWeight.w400,
                            )),
                      ),
                      const Expanded(child: Divider(color: Colors.white38)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Join Game section ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Join Game',
                            style: AppTheme.heading(size: 18, weight: FontWeight.w600)),
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
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _joinGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Join',
                                style: AppTheme.heading(
                                    size: 18, weight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
