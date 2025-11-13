import 'package:flutter/material.dart';
import '../models/player.dart';

enum PlayerCardStyle {
  lobby, // For lobby screen
  results, // For round results (with ranking)
  handResults, // For hand results
  rolling, // For rolling phase in game screen
  compact, // Minimal display
}

class PlayerCard extends StatelessWidget {
  final Player player;
  final PlayerCardStyle style;
  final bool isMe;
  final int? position; // For results screen ranking
  final bool isWinner; // For hand results
  final bool isReady; // For lobby screen
  final bool isRolling; // For rolling phase
  final bool hasRolled; // For rolling phase
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
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Position medal (for results screen)
            if (style == PlayerCardStyle.results && position != null) ...[
              _buildPositionMedal(),
              const SizedBox(width: 16),
            ],

            // Winner trophy (for hand results)
            if (style == PlayerCardStyle.handResults && isWinner) ...[
              Icon(Icons.emoji_events, color: Colors.amber[700], size: 24),
              const SizedBox(width: 8),
            ],

            // Avatar
            CircleAvatar(
              backgroundColor: player.isHost ? Colors.amber : Colors.blue,
              radius: _getAvatarRadius(),
              child: Text(
                player.name[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
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
                    Text(
                      'Total Score',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
    if (style == PlayerCardStyle.rolling) {
      if (isRolling) return Colors.orange[50]!;
      if (hasRolled) return Colors.green[50]!;
      return Colors.grey[100]!;
    }
    if (isWinner) return Colors.amber[50]!;
    if (isMe) return Colors.blue[50]!;
    return Colors.white;
  }

  Color _getDefaultBorderColor() {
    if (style == PlayerCardStyle.rolling) {
      if (isRolling) return Colors.orange;
      if (hasRolled) return Colors.green;
      return Colors.grey[300]!;
    }
    if (isWinner) return Colors.amber[700]!;
    if (isMe) return Colors.blue[300]!;
    return Colors.grey[300]!;
  }

  double _getDefaultBorderWidth() {
    if (isWinner || isMe) return 3;
    if (style == PlayerCardStyle.rolling && isRolling) return 2;
    return 1;
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
      medalColor = Colors.amber[700];
      medalIcon = Icons.emoji_events;
    } else if (position == 2) {
      medalColor = Colors.grey[600];
      medalIcon = Icons.military_tech;
    } else if (position == 3) {
      medalColor = Colors.orange[700];
      medalIcon = Icons.military_tech;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: medalColor ?? Colors.grey[300],
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
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Edit name button
        if (isMe && onEditName != null && style == PlayerCardStyle.lobby) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onEditName,
            child: Icon(Icons.edit, size: 16, color: Colors.blue[700]),
          ),
        ],

        // Host badge
        if (player.isHost) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'HOST',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
        ? Colors.green
        : Colors.grey[600];

    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: color,
        fontWeight: hasRolled ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildPointsDisplay() {
    Color? medalColor;
    if (position == 1)
      medalColor = Colors.amber[700];
    else if (position == 2)
      medalColor = Colors.grey[600];
    else if (position == 3)
      medalColor = Colors.orange[700];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${player.totalPoints}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: medalColor ?? Colors.grey[700],
          ),
        ),
        Text('points', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLobbyStatus() {
    if (player.isHost) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
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
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (hasRolled) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
    }
    return const SizedBox(width: 24);
  }
}
