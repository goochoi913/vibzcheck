import 'package:flutter/material.dart';

import '../utils/mood_tags.dart';

class MoodTagEditorSheet extends StatefulWidget {
  const MoodTagEditorSheet({
    super.key,
    required this.initialTags,
    this.title = 'Edit Mood Tags',
    this.confirmLabel = 'Done',
  });

  final List<String> initialTags;
  final String title;
  final String confirmLabel;

  static Future<List<String>?> show({
    required BuildContext context,
    required List<String> initialTags,
    String title = 'Edit Mood Tags',
    String confirmLabel = 'Done',
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoodTagEditorSheet(
        initialTags: initialTags,
        title: title,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  State<MoodTagEditorSheet> createState() => _MoodTagEditorSheetState();
}

class _MoodTagEditorSheetState extends State<MoodTagEditorSheet> {
  late final Set<String> _selectedTags = {...widget.initialTags};

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade500,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kMoodTagOptions.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (_) => _toggleTag(tag),
                  selectedColor: colorScheme.primary.withValues(alpha: 0.95),
                  checkmarkColor: colorScheme.onPrimary,
                  labelStyle: TextStyle(
                    color: selected
                        ? colorScheme.onPrimary
                        : Colors.grey.shade200,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected
                        ? colorScheme.primary
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                  backgroundColor: Colors.transparent,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(_selectedTags.toList());
              },
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}
