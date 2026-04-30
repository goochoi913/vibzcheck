import 'package:flutter/material.dart';

class VoteButton extends StatelessWidget {
  const VoteButton({super.key, required this.votes, required this.onPressed});

  final int votes;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.thumb_up_alt_outlined),
      label: Text('$votes'),
    );
  }
}
