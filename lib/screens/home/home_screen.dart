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
    final sessionProvider = context.read<SessionProvider>();
    final currentUser = widget.currentUser;
    final controller = TextEditingController();

    final sessionName = await showDialog<String>(
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
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(name);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || currentUser == null || sessionName == null) {
      return;
    }

    final trimmedName = sessionName.trim();
    if (trimmedName.isEmpty) return;

    // Let the dialog route fully settle before provider state changes.
    await Future<void>.delayed(const Duration(milliseconds: 16));

    await sessionProvider.createSession(
      sessionName: trimmedName,
      hostUID: currentUser.uid,
    );
  }

  Future<void> _showJoinWithRoomIdDialog(BuildContext context) async {
    final sessionProvider = context.read<SessionProvider>();
    final currentUser = widget.currentUser;
    final controller = TextEditingController();

    final sessionId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join with Room ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Room ID',
            hintText: 'Paste session ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.of(dialogContext).pop(id);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (!mounted || currentUser == null || sessionId == null) return;

    await sessionProvider.joinSession(
      sessionId: sessionId,
      userUID: currentUser.uid,
    );

    if (!mounted) return;
    final error = sessionProvider.errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Unable to join room: $error'),
        ),
      );
    }
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
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final session = filtered[index];
                      return _SessionCard(
                        key: ValueKey<String>(session.sessionId),
                        session: session,
                        currentUser: currentUser,
                        isLoading: sessionProvider.isLoading,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: currentUser == null
                  ? null
                  : () {
                      _showJoinWithRoomIdDialog(context);
                    },
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('Join with Room ID'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    super.key,
    required this.session,
    required this.currentUser,
    required this.isLoading,
  });

  final SessionModel session;
  final UserModel? currentUser;
  final bool isLoading;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  late Future<UserModel?> _hostFuture;

  @override
  void initState() {
    super.initState();
    _hostFuture = FirestoreService.instance.getUser(widget.session.hostUID);
  }

  @override
  void didUpdateWidget(covariant _SessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.hostUID != widget.session.hostUID) {
      _hostFuture = FirestoreService.instance.getUser(widget.session.hostUID);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.session.sessionName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            FutureBuilder<UserModel?>(
              future: _hostFuture,
              builder: (context, snapshot) {
                final hostName = snapshot.data?.displayName.isNotEmpty == true
                    ? snapshot.data!.displayName
                    : 'Host: ${widget.session.hostUID.substring(0, 6)}...';
                return Text(
                  hostName,
                  style: TextStyle(color: Colors.grey.shade400),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Collaborators: ${widget.session.collaborators.length}'),
                const Spacer(),
                FilledButton(
                  onPressed: (widget.currentUser == null || widget.isLoading)
                      ? null
                      : () async {
                          await context.read<SessionProvider>().joinSession(
                            sessionId: widget.session.sessionId,
                            userUID: widget.currentUser!.uid,
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

class _ActiveSessionView extends StatefulWidget {
  const _ActiveSessionView({required this.session, required this.currentUser});

  final SessionModel session;
  final UserModel? currentUser;

  @override
  State<_ActiveSessionView> createState() => _ActiveSessionViewState();
}

class _ActiveSessionViewState extends State<_ActiveSessionView> {
  late Future<UserModel?> _hostFuture;

  @override
  void initState() {
    super.initState();
    _hostFuture = FirestoreService.instance.getUser(widget.session.hostUID);
  }

  @override
  void didUpdateWidget(covariant _ActiveSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.hostUID != widget.session.hostUID) {
      _hostFuture = FirestoreService.instance.getUser(widget.session.hostUID);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = widget.currentUser?.uid == widget.session.hostUID;

    return Scaffold(
      appBar: AppBar(title: const Text('Active Session')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.session.sessionName,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            FutureBuilder<UserModel?>(
              future: _hostFuture,
              builder: (context, snapshot) {
                final hostName = snapshot.data?.displayName.isNotEmpty == true
                    ? snapshot.data!.displayName
                    : widget.session.hostUID;
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
                    onPressed: () => MainNavigation.switchToTab(context, 1),
                    icon: const Icon(Icons.library_music_outlined),
                    label: const Text('Playlist'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => MainNavigation.switchToTab(context, 2),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Collaborators: ${widget.session.collaborators.length}'),
            const SizedBox(height: 8),
            Consumer<SessionProvider>(
              builder: (context, provider, child) {
                return Text('Tracks in queue: ${provider.tracks.length}');
              },
            ),
          ],
        ),
      ),
    );
  }
}
