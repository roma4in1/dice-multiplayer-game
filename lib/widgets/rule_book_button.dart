import 'package:flutter/material.dart';

class RuleBookButton extends StatelessWidget {
  const RuleBookButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Hand Rankings',
      onPressed: () => _showRuleBook(context),
    );
  }

  void _showRuleBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[700]),
            const SizedBox(width: 8),
            const Text('Hand Rankings'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'From strongest to weakest:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),

              // Triple
              _buildRankCard(
                rank: '1. Triple',
                description: 'All three dice show the same value',
                examples: ['6-6-6', '5-5-5', '1-1-1'],
                color: Colors.purple,
                icon: Icons.filter_3,
              ),

              const SizedBox(height: 12),

              // Straight
              _buildRankCard(
                rank: '2. Straight',
                description: 'Three consecutive values',
                examples: ['4-5-6', '3-4-5', '1-2-3'],
                color: Colors.blue,
                icon: Icons.trending_up,
              ),

              const SizedBox(height: 12),

              // Pair
              _buildRankCard(
                rank: '3. Pair',
                description: 'Two dice show the same value',
                examples: ['6-6-3', '4-4-1', '2-2-5'],
                color: Colors.green,
                icon: Icons.filter_2,
              ),

              const SizedBox(height: 12),

              // High Card
              _buildRankCard(
                rank: '4. High Card',
                description: 'No matching or consecutive values',
                examples: ['6-4-1', '5-3-1', '6-2-1'],
                color: Colors.orange,
                icon: Icons.filter_1,
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Tiebreaker rules
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Tiebreaker Rules:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Same rank? Compare highest die value\n'
                      '• Still tied? Compare sum of all dice\n'
                      '• Still tied? Players split the points',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Points info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Each hand is worth 5 points\nWinner takes all (or split if tied)',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard({
    required String rank,
    required String description,
    required List<String> examples,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                rank,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: examples.map((example) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  example,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
