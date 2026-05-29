import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/player.dart';

enum PlayerCardStyle {
  lobby,
  results,
  handResults,
  rolling,
  compact,
}

class PlayerCard extends StatelessWidget {
  final Player player;
  final PlayerCardStyle style;
  final bool isMe;
  final int? position;
  final bool isWinner;
  final bool isReady;
  final bool isRolling;
  final bool hasRolled;
  final VoidCallback? onEditName;
  final Widget? trailing;
  final Widget? subtitle;
  final Color? borderColor;
  final double? borderWidth;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const PlayerCard({
    super.key,
    required this.player,
    this.style = PlayerCardStyle.compact,
    this.isMe = false,
    this.position,
    this.isWinner = false,
    this.isReady = false,
    this.isRolling = false,
    this.hasRolled = false,
    this.onEditName,
    this.trailing,
    this.subtitle,
    this.borderColor,
    this.borderWidth,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: style == PlayerCardStyle.lobby
          ? const EdgeInsets.only(bottom: 8)
          : const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? _getDefaultBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? _getDefaultBorderColor(),
          width: borderWidth ?? _getDefaultBorderWidth(),
        ),
        boxShadow: _getDefaultShadow(),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Position medal (for results screen)
            if (style == PlayerCardStyle.results && position != null) ...[
              _buildPositionMedal(),
              const SizedBox(width: 14),
            ],

            // Winner trophy (for hand results)
            if (style == PlayerCardStyle.handResults && isWinner) ...[
              const Icon(Icons.emoji_events, color: AppTheme.gold, size: 24),
              const SizedBox(width: 8),
            ],

            // Avatar
            CircleAvatar(
              backgroundColor:
                  player.isHost ? AppTheme.gold : AppTheme.navyLight,
              radius: _getAvatarRadius(),
              child: Text(
                player.name[0].toUpperCase(),
                style: TextStyle(
                  color: player.isHost ? AppTheme.navy : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: _getAvatarRadius() * 0.9,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Name and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNameRow(context),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    subtitle!,
                  ] else if (style == PlayerCardStyle.results) ...[
                    const Text(
                      'Total Score',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ] else if (style == PlayerCardStyle.rolling) ...[
                    const SizedBox(height: 4),
                    _buildRollingStatus(),
                  ],
                ],
              ),
            ),

            // Trailing widget
            if (trailing != null)
              trailing!
            else if (style == PlayerCardStyle.results)
              _buildPointsDisplay()
            else if (style == PlayerCardStyle.lobby)
              _buildLobbyStatus()
            else if (style == PlayerCardStyle.rolling)
              _buildRollingTrailing(),
          ],
        ),
      ),
    );
  }

  Color _getDefaultBackgroundColor() {
    // Rolling phase: caller provides explicit colors — these are fallbacks
    if (style == PlayerCardStyle.rolling) {
      if (isRolling) return Colors.orange.withValues(alpha: 0.12);
      if (hasRolled) return Colors.green.withValues(alpha: 0.1);
      return AppTheme.cardIvory;
    }
    if (isWinner) return AppTheme.gold.withValues(alpha: 0.1);
    if (isMe) return AppTheme.gold.withValues(alpha: 0.06);
    return AppTheme.cardIvory;
  }

  Color _getDefaultBorderColor() {
    if (style == PlayerCardStyle.rolling) {
      if (isRolling) return Colors.orange;
      if (hasRolled) return Colors.greenAccent;
      return AppTheme.cardBorder;
    }
    if (isWinner) return AppTheme.gold;
    if (isMe) return AppTheme.gold.withValues(alpha: 0.5);
    return AppTheme.cardBorder;
  }

  double _getDefaultBorderWidth() {
    if (isWinner || isMe) return 2.5;
    if (style == PlayerCardStyle.rolling && isRolling) return 2;
    return 1.5;
  }

  List<BoxShadow>? _getDefaultShadow() {
    if (isWinner) {
      return [
        BoxShadow(
          color: AppTheme.gold.withValues(alpha: 0.25),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];
    }
    return null;
  }

  double _getAvatarRadius() {
    switch (style) {
      case PlayerCardStyle.results:
      case PlayerCardStyle.handResults:
        return 20;
      case PlayerCardStyle.rolling:
        return 16;
      case PlayerCardStyle.lobby:
        return 20;
      default:
        return 16;
    }
  }

  Widget _buildPositionMedal() {
    Color? medalColor;
    IconData? medalIcon;

    if (position == 1) {
      medalColor = AppTheme.gold;
      medalIcon = Icons.emoji_events;
    } else if (position == 2) {
      medalColor = const Color(0xFF9E9E9E);
      medalIcon = Icons.military_tech;
    } else if (position == 3) {
      medalColor = const Color(0xFFCD7F32);
      medalIcon = Icons.military_tech;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: medalColor ?? Colors.grey[400],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: medalIcon != null
            ? Icon(medalIcon, color: Colors.white, size: 24)
            : Text(
                '$position',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildNameRow(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            isMe ? '${player.name} (You)' : player.name,
            style: TextStyle(
              fontSize: style == PlayerCardStyle.results ? 18 : 16,
              fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
              color: AppTheme.navy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Edit name button
        if (isMe && onEditName != null && style == PlayerCardStyle.lobby) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onEditName,
            child: const Icon(Icons.edit, size: 16, color: AppTheme.goldDark),
          ),
        ],

        // Host badge
        if (player.isHost) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.goldLight, AppTheme.gold],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'HOST',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.navy,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRollingStatus() {
    final text = isRolling
        ? 'Rolling...'
        : hasRolled
        ? '✓ Rolled'
        : 'Waiting to roll';

    final color = isRolling
        ? Colors.orange
        : hasRolled
        ? Colors.green[700]!
        : Colors.grey[500]!;

    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: color,
        fontWeight: hasRolled ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildPointsDisplay() {
    Color? medalColor;
    if (position == 1) medalColor = AppTheme.gold;
    else if (position == 2) medalColor = const Color(0xFF9E9E9E);
    else if (position == 3) medalColor = const Color(0xFFCD7F32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${player.totalPoints}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: medalColor ?? AppTheme.navy,
          ),
        ),
        const Text('points',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLobbyStatus() {
    if (player.isHost) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'READY',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      );
    }

    return Icon(
      isReady ? Icons.check_circle : Icons.schedule,
      color: isReady ? Colors.green : Colors.grey,
      size: 24,
    );
  }

  Widget _buildRollingTrailing() {
    if (isRolling) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
      );
    } else if (hasRolled) {
      return const Icon(Icons.check_circle,
          color: Colors.greenAccent, size: 24);
    }
    return const SizedBox(width: 24);
  }
}
