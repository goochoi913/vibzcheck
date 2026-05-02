import 'package:flutter/material.dart';

class VoteButton extends StatelessWidget {
  const VoteButton({
    super.key,
    required this.votes,
    required this.onPressed,
    this.hasVoted = false,
  });

  final int votes;
  final VoidCallback onPressed;
  final bool hasVoted;

  @override
  Widget build(BuildContext context) {
    final iconColor = hasVoted
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade300;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.thumb_up_alt_outlined, color: iconColor),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$votes',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
