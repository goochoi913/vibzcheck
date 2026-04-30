import 'package:flutter/material.dart';

class MoodTagChip extends StatelessWidget {
  const MoodTagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
