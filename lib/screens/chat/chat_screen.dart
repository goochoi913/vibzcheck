import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../firebase/firestore_service.dart';
import '../../models/message_model.dart';
import '../../models/track_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const List<String> _reactionOptions = ['🔥', '❤️', '😂', '😮', '👍', '👏'];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _lastMessageCount = 0;
  bool _showTrackBanner = false;
  TrackModel? _bannerTrack;
  Timer? _bannerTimer;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final authProvider = context.read<AuthProvider>();
    final sessionProvider = context.read<SessionProvider>();
    final user = authProvider.currentUser;
    final session = sessionProvider.currentSession;
    final text = _messageController.text.trim();

    if (user == null || session == null || text.isEmpty) return;

    await FirestoreService.instance.sendMessage(
      sessionId: session.sessionId,
      senderUID: user.uid,
      senderName: user.displayName,
      text: text,
    );

    _messageController.clear();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showReactionMenu({
    required LongPressStartDetails details,
    required String sessionId,
    required String messageId,
  }) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: _reactionOptions
          .map(
            (emoji) => PopupMenuItem<String>(
              value: emoji,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          )
          .toList(),
    );

    if (selected == null) return;

    await FirestoreService.instance.addReaction(
      sessionId: sessionId,
      messageId: messageId,
      reaction: selected,
    );
  }

  Future<void> _openComposerEmojiPicker() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(18, 520, 18, 90),
      items: _reactionOptions
          .map(
            (emoji) => PopupMenuItem<String>(
              value: emoji,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          )
          .toList(),
    );

    if (selected == null) return;

    _messageController.text = '${_messageController.text}$selected';
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _triggerTrackBanner(TrackModel track) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerTrack = track;
      _showTrackBanner = true;
    });

    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _showTrackBanner = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final session = sessionProvider.currentSession;
    final currentUser = authProvider.currentUser;

    if (sessionProvider.newTrackAdded && sessionProvider.latestTrack != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _triggerTrackBanner(sessionProvider.latestTrack!);
        context.read<SessionProvider>().consumeNewTrackBanner();
      });
    }

    if (session == null || currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Join a session first to start chatting.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat'),
            Text(
              session.sessionName,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: FirestoreService.instance.getMessagesStream(session.sessionId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Unable to load chat: ${snapshot.error}'));
                    }

                    final messages = snapshot.data ?? const <MessageModel>[];

                    if (messages.length > _lastMessageCount) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_scrollController.hasClients) return;
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        );
                      });
                    }
                    _lastMessageCount = messages.length;

                    if (messages.isEmpty) {
                      return const Center(child: Text('No messages yet. Say hi to the room.'));
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(12, 12, 12, _showTrackBanner ? 132 : 92),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderUID == currentUser.uid;

                        return GestureDetector(
                          onLongPressStart: (details) {
                            _showReactionMenu(
                              details: details,
                              sessionId: session.sessionId,
                              messageId: message.messageId,
                            );
                          },
                          child: _MessageBubble(message: message, isMine: isMine),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onChanged: (_) => setState(() {}),
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Send a message',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openComposerEmojiPicker,
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        tooltip: 'Add emoji',
                      ),
                      IconButton(
                        onPressed: _messageController.text.trim().isEmpty ? null : _sendMessage,
                        icon: const Icon(Icons.send),
                        tooltip: 'Send',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            left: 12,
            right: 12,
            bottom: _showTrackBanner ? 74 : -120,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _showTrackBanner ? 1 : 0,
              child: _bannerTrack == null
                  ? const SizedBox.shrink()
                  : Material(
                      elevation: 4,
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _bannerTrack!.albumArt,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 36,
                                  height: 36,
                                  color: Colors.white10,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.music_note, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Now in queue: ${_bannerTrack!.trackName} by ${_bannerTrack!.artistName}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final MessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.84)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            UserAvatar(photoURL: null, displayName: message.senderName, radius: 15),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.senderName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(message.text),
                    ],
                  ),
                ),
                if (message.reaction != null && message.reaction!.isNotEmpty)
                  Positioned(
                    right: -6,
                    bottom: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(message.reaction!),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
