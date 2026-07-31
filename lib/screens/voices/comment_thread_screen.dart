import 'package:flutter/material.dart';
import 'package:student_activities/core/predictive_back.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:student_activities/services/storage_service.dart';
import 'package:student_activities/services/voices_chat_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class CommentThreadScreen extends StatefulWidget {
  const CommentThreadScreen({super.key, required this.parentComment});
  final Map<String, dynamic> parentComment;

  @override
  State<CommentThreadScreen> createState() => _CommentThreadScreenState();
}

class _CommentThreadScreenState extends State<CommentThreadScreen> {
  final _reply = TextEditingController();
  final _chat = VoicesChatService();
  final _votes = <String, String>{};
  List<Map<String, dynamic>> _replies = [];
  io.Socket? _roomSocket;
  io.Socket? _capabilitiesSocket;
  String? _joinedRoom;
  bool _loading = true;
  bool _posting = false;
  bool _canWrite = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVotes();
    _loadReplies();
  }

  @override
  void dispose() {
    _reply.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _loadVotes() async {
    final values = await StorageService.instance.getCommentVotes();
    if (mounted) setState(() => _votes.addAll(values));
  }

  Future<void> _loadReplies() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final id = widget.parentComment['id']?.toString();
    final groupId = widget.parentComment['group_id']?.toString();
    if (id == null || groupId == null || groupId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'This discussion is unavailable.';
        });
      }
      return;
    }
    final socket = await _ensureRoom(groupId);
    if (!mounted) return;
    final response = socket == null
        ? <String, dynamic>{
            'ok': false,
            'error': 'Unable to connect to this discussion.',
          }
        : await _chat.request(socket, 'chat:thread', {
            'parentId': id,
            'afterSeq': 0,
            'limit': 30,
          });
    if (!mounted) return;
    if (response['ok'] != true) {
      setState(() {
        _loading = false;
        _error = response['error']?.toString() ?? 'Unable to load replies.';
      });
      return;
    }
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : const <String, dynamic>{};
    setState(() {
      _replies = (data['messages'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _loading = false;
    });
  }

  Future<io.Socket?> _ensureRoom(String groupId) async {
    var socket = await _chat.connect();
    if (socket == null) return null;
    if (!identical(_roomSocket, socket) || _joinedRoom != groupId) {
      final joined = await _chat.join(groupId);
      if (joined['ok'] != true) return null;
      _joinedRoom = groupId;
      _roomSocket = socket;
    }
    if (!identical(_capabilitiesSocket, socket)) {
      _capabilitiesSocket = socket;
      socket.on('chat:me', _handleCapabilities);
    }
    return socket;
  }

  void _handleCapabilities(dynamic raw) {
    if (!mounted || raw is! Map) return;
    setState(() => _canWrite = raw['canWrite'] == true);
  }

  Future<void> _sendReply() async {
    final content = _reply.text.trim();
    final parentId = widget.parentComment['id']?.toString();
    final groupId = widget.parentComment['group_id']?.toString();
    if (content.isEmpty || parentId == null || groupId == null || !_canWrite) {
      return;
    }
    setState(() => _posting = true);
    final socket = await _ensureRoom(groupId);
    final response = socket == null
        ? <String, dynamic>{
            'ok': false,
            'error': 'Unable to connect to this discussion.',
          }
        : await _chat.send(socket, content, parentId: parentId);
    if (!mounted) return;
    setState(() => _posting = false);
    if (response['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error']?.toString() ?? 'Could not post reply.',
          ),
        ),
      );
      return;
    }
    _reply.clear();
    await _loadReplies();
  }

  Future<void> _vote(Map<String, dynamic> comment, String type) async {
    final id = comment['id']?.toString();
    if (id == null) return;
    final before = _votes[id];
    final after = before == type ? null : type;
    final upBefore = _number(comment['upvotes_count']);
    final downBefore = _number(comment['downvotes_count']);
    setState(() {
      if (after == null) {
        _votes.remove(id);
      } else {
        _votes[id] = after;
      }
      comment['upvotes_count'] =
          upBefore + (after == 'up' ? 1 : 0) - (before == 'up' ? 1 : 0);
      comment['downvotes_count'] =
          downBefore + (after == 'down' ? 1 : 0) - (before == 'down' ? 1 : 0);
    });
    await StorageService.instance.saveCommentVotes(_votes);
    final actions = <String>[];
    if (before == 'up') actions.add('unupvote');
    if (before == 'down') actions.add('undownvote');
    if (after == 'up') actions.add('upvote');
    if (after == 'down') actions.add('downvote');
    for (final action in actions) {
      final response = await ApiClient.instance.post(
        '/voices/comments/$id/$action',
      );
      if (!response.success && mounted) {
        setState(() {
          if (before == null) {
            _votes.remove(id);
          } else {
            _votes[id] = before;
          }
          comment['upvotes_count'] = upBefore;
          comment['downvotes_count'] = downBefore;
        });
        await StorageService.instance.saveCommentVotes(_votes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error ?? 'Vote could not be saved.')),
        );
        return;
      }
    }
  }

  Future<void> _report(Map<String, dynamic> comment) async {
    final id = comment['id']?.toString();
    if (id == null) return;
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final option in const [
              'Spam',
              'Harassment',
              'Inappropriate',
              'Other',
            ])
              ListTile(
                title: Text(option),
                onTap: () => Navigator.pop(context, option.toLowerCase()),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    final groupId = widget.parentComment['group_id']?.toString();
    final socket = groupId == null ? null : await _ensureRoom(groupId);
    final response = socket == null
        ? <String, dynamic>{
            'ok': false,
            'error': 'Unable to connect to this discussion.',
          }
        : await _chat.request(socket, 'chat:report', {
            'messageId': id,
            'reason': reason,
          });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['ok'] == true
              ? 'Comment reported.'
              : response['error']?.toString() ?? 'Could not report comment.',
        ),
      ),
    );
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    return PredictiveBackScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Discussion')),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const LoadingIndicator(message: 'Loading replies')
                  : _error != null
                  ? ErrorDisplay(message: _error!, onRetry: _loadReplies)
                  : RefreshIndicator(
                      onRefresh: _loadReplies,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        children: [
                          _ThreadComment(
                            comment: widget.parentComment,
                            vote:
                                _votes[widget.parentComment['id']?.toString()],
                            isParent: true,
                            onVote: _vote,
                            onReport: _report,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text('Replies'),
                          ),
                          if (_replies.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: EmptyState(
                                icon: Icons.reply_outlined,
                                title: 'No replies yet',
                              ),
                            )
                          else
                            ..._replies.map(
                              (comment) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ThreadComment(
                                  comment: comment,
                                  vote: _votes[comment['id']?.toString()],
                                  onVote: _vote,
                                  onReport: _report,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _reply,
                  enabled: _canWrite,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendReply(),
                  decoration: InputDecoration(
                    hintText: _canWrite
                        ? 'Write a reply'
                        : 'Posting is unavailable for this account',
                    suffixIcon: IconButton(
                      tooltip: 'Send reply',
                      onPressed: _canWrite && !_posting ? _sendReply : null,
                      icon: _posting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadComment extends StatelessWidget {
  const _ThreadComment({
    required this.comment,
    required this.vote,
    required this.onVote,
    required this.onReport,
    this.isParent = false,
  });
  final Map<String, dynamic> comment;
  final String? vote;
  final bool isParent;
  final Future<void> Function(Map<String, dynamic>, String) onVote;
  final Future<void> Function(Map<String, dynamic>) onReport;

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isParent ? Icons.forum_outlined : Icons.person_outline,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isParent ? 'Original post' : 'Anonymous',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Report',
              visualDensity: VisualDensity.compact,
              onPressed: () => onReport(comment),
              icon: const Icon(Icons.flag_outlined, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          comment['content']?.toString() ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => onVote(comment, 'up'),
              icon: const Icon(Icons.arrow_upward, size: 17),
              label: Text('${_number(comment['upvotes_count'])}'),
              style: TextButton.styleFrom(
                foregroundColor: vote == 'up'
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            TextButton.icon(
              onPressed: () => onVote(comment, 'down'),
              icon: const Icon(Icons.arrow_downward, size: 17),
              label: Text('${_number(comment['downvotes_count'])}'),
              style: TextButton.styleFrom(
                foregroundColor: vote == 'down'
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
