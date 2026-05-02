import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../firebase/firestore_service.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import 'main_navigation.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (sessionProvider.currentSession == null) {
      return _LobbyView(currentUser: authProvider.currentUser);
    }

    return _ActiveSessionView(
      session: sessionProvider.currentSession!,
      currentUser: authProvider.currentUser,
    );
  }
}

class _LobbyView extends StatefulWidget {
  const _LobbyView({required this.currentUser});

  final UserModel? currentUser;

  @override
  State<_LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<_LobbyView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateRoomDialog(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Room'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Session Name',
              hintText: 'Ex. Friday Night Mix',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty || widget.currentUser == null) {
                  return;
                }

                await context.read<SessionProvider>().createSession(
                  sessionName: name,
                  hostUID: widget.currentUser!.uid,
                );

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.currentUser;
    final sessionProvider = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Join the Vibe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: currentUser == null
            ? null
            : () {
                _showCreateRoomDialog(context);
              },
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Join the Vibe',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search active sessions',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (sessionProvider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  sessionProvider.errorMessage!,
                  style: TextStyle(color: Colors.red.shade300),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<SessionModel>>(
                stream: FirestoreService.instance.getActiveSessions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load sessions: ${snapshot.error}'),
                    );
                  }

                  final sessions = snapshot.data ?? const <SessionModel>[];
                  final filtered = _searchQuery.isEmpty
                      ? sessions
                      : sessions
                            .where(
                              (session) => session.sessionName
                                  .toLowerCase()
                                  .contains(_searchQuery),
                            )
                            .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No active sessions found.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final session = filtered[index];
                      return _SessionCard(
                        session: session,
                        currentUser: currentUser,
                        isLoading: sessionProvider.isLoading,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.currentUser,
    required this.isLoading,
  });

  final SessionModel session;
  final UserModel? currentUser;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.sessionName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            FutureBuilder<UserModel?>(
              future: FirestoreService.instance.getUser(session.hostUID),
              builder: (context, snapshot) {
                final hostName = snapshot.data?.displayName.isNotEmpty == true
                    ? snapshot.data!.displayName
                    : 'Host: ${session.hostUID.substring(0, 6)}...';
                return Text(
                  hostName,
                  style: TextStyle(color: Colors.grey.shade400),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Collaborators: ${session.collaborators.length}'),
                const Spacer(),
                FilledButton(
                  onPressed: (currentUser == null || isLoading)
                      ? null
                      : () async {
                          await context.read<SessionProvider>().joinSession(
                            sessionId: session.sessionId,
                            userUID: currentUser!.uid,
                          );
                        },
                  child: const Text('Join'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionView extends StatelessWidget {
  const _ActiveSessionView({required this.session, required this.currentUser});

  final SessionModel session;
  final UserModel? currentUser;

  @override
  Widget build(BuildContext context) {
    final isHost = currentUser?.uid == session.hostUID;

    return Scaffold(
      appBar: AppBar(title: const Text('Active Session')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              session.sessionName,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            FutureBuilder<UserModel?>(
              future: FirestoreService.instance.getUser(session.hostUID),
              builder: (context, snapshot) {
                final hostName = snapshot.data?.displayName.isNotEmpty == true
                    ? snapshot.data!.displayName
                    : session.hostUID;
                return Text(
                  'Host: $hostName',
                  style: TextStyle(color: Colors.grey.shade400),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'You are ${isHost ? 'the host' : 'a collaborator'}',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => context.read<SessionProvider>().leaveSession(),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Leave Room'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        MainNavigation.maybeOf(context)?.switchToTab(1),
                    icon: const Icon(Icons.library_music_outlined),
                    label: const Text('Playlist'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        MainNavigation.maybeOf(context)?.switchToTab(2),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Collaborators: ${session.collaborators.length}'),
            const SizedBox(height: 8),
            Consumer<SessionProvider>(
              builder: (_, provider, __) {
                return Text('Tracks in queue: ${provider.tracks.length}');
              },
            ),
          ],
        ),
      ),
    );
  }
}
