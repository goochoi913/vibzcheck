import 'package:flutter/material.dart';

class VoteButton extends StatefulWidget {
  const VoteButton({
    super.key,
    required this.votes,
    required this.hasVoted,
    required this.pulseToken,
    this.onPressed,
  });

  final int votes;
  final bool hasVoted;
  final int pulseToken;
  final VoidCallback? onPressed;

  @override
  State<VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<VoteButton> {
  double _scale = 1.0;

  @override
  void didUpdateWidget(covariant VoteButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.pulseToken != oldWidget.pulseToken) {
      _runPulse();
    }
  }

  Future<void> _runPulse() async {
    if (!mounted) return;
    setState(() {
      _scale = 1.2;
    });

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = widget.onPressed != null;

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: widget.hasVoted
                  ? colorScheme.primary.withValues(
                      alpha: isEnabled ? 0.95 : 0.4,
                    )
                  : Colors.transparent,
              border: Border.all(
                color: widget.hasVoted
                    ? colorScheme.primary
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.thumb_up_alt_outlined,
                  size: 18,
                  color: widget.hasVoted
                      ? colorScheme.onPrimary
                      : Colors.grey.shade300,
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.votes}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: widget.hasVoted
                        ? colorScheme.onPrimary
                        : Colors.grey.shade200,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
