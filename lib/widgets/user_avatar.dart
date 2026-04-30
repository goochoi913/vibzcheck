import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.photoURL, this.radius = 18});

  final String? photoURL;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (photoURL != null && photoURL!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoURL!),
      );
    }

    return CircleAvatar(
      radius: radius,
      child: const Icon(Icons.person_outline),
    );
  }
}
