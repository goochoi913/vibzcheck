import 'package:flutter/material.dart';

class TrackCard extends StatelessWidget {
  const TrackCard({
    super.key,
    required this.trackName,
    required this.artistName,
  });

  final String trackName;
  final String artistName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(trackName), subtitle: Text(artistName)),
    );
  }
}
