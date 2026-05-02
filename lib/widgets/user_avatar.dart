import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.photoURL,
    required this.displayName,
    this.radius = 28,
  });

  final String? photoURL;
  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final normalizedName = displayName.trim();
    final safeName = normalizedName.isEmpty ? '?' : normalizedName;
    final initials = _initialsFromName(safeName);

    if (photoURL != null && photoURL!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade900,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoURL!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorFromName(safeName),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.65,
        ),
      ),
    );
  }

  String _initialsFromName(String name) {
    final parts = name
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Color _colorFromName(String name) {
    final seed = name.runes.fold<int>(0, (sum, rune) => sum + rune);
    final palette = <Color>[
      const Color(0xFF00ACC1),
      const Color(0xFF7CB342),
      const Color(0xFFF4511E),
      const Color(0xFF5E35B1),
      const Color(0xFFD81B60),
      const Color(0xFF3949AB),
      const Color(0xFF00897B),
    ];
    return palette[seed % palette.length];
  }
}
