import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../firebase/firestore_service.dart';
import '../../models/user_stats.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<UserStats>? _statsFuture;
  String? _statsUserUID;

  void _ensureStatsFuture(String userUID) {
    if (_statsUserUID == userUID && _statsFuture != null) return;
    _statsUserUID = userUID;
    _statsFuture = FirestoreService.instance.getUserStats(userUID);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user profile found. Please sign in.')),
      );
    }

    _ensureStatsFuture(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: UserAvatar(
                  photoURL: user.photoURL,
                  displayName: user.displayName,
                  radius: 46,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user.email,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              ),
              const SizedBox(height: 28),
              const Text(
                'Favorite Genres',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              user.favoriteGenres.isEmpty
                  ? Text(
                      'No genres added yet.',
                      style: TextStyle(color: Colors.grey.shade500),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        children: user.favoriteGenres
                            .map(
                              (genre) => Chip(
                                label: Text(genre),
                                backgroundColor: Colors.cyan.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
              const SizedBox(height: 28),
              const Text(
                'My Listening Stats',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              FutureBuilder<UserStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _StatsLoadingSkeleton();
                  }

                  if (snapshot.hasError) {
                    return Text(
                      'Unable to load stats right now.',
                      style: TextStyle(color: Colors.red.shade300),
                    );
                  }

                  final stats =
                      snapshot.data ??
                      const UserStats(
                        sessionsJoined: 0,
                        tracksAdded: 0,
                        votesCast: 0,
                      );

                  return Column(
                    children: [
                      _StatTile(
                        label: 'Sessions joined',
                        value: '${stats.sessionsJoined}',
                      ),
                      _StatTile(
                        label: 'Total votes cast',
                        value: '${stats.votesCast}',
                      ),
                      _StatTile(
                        label: 'Tracks added',
                        value: '${stats.tracksAdded}',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              TextButton(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsLoadingSkeleton extends StatelessWidget {
  const _StatsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [_StatSkeletonTile(), _StatSkeletonTile(), _StatSkeletonTile()],
    );
  }
}

class _StatSkeletonTile extends StatefulWidget {
  const _StatSkeletonTile();

  @override
  State<_StatSkeletonTile> createState() => _StatSkeletonTileState();
}

class _StatSkeletonTileState extends State<_StatSkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final base = Colors.grey.shade700;
        final highlight = Colors.grey.shade500;
        final blended = Color.lerp(base, highlight, _controller.value) ?? base;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: blended,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 26),
              Container(
                width: 34,
                height: 14,
                decoration: BoxDecoration(
                  color: blended,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
