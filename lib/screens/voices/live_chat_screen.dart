import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_activities/core/constants.dart';
import 'package:student_activities/core/predictive_back.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/services/auth_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  static const _pageSize = 30;
  final _composer = TextEditingController();
  io.Socket? _socket;
  List<_ChatMessage> _messages = [];
  bool _hasOlder = false;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _sending = false;
  bool? _canWrite;
  int _activeCount = 0;
  String _status = 'Connecting';
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _composer.dispose();
    _socket?.dispose();
    super.dispose();
  }

  void _connect() {
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'Disconnected';
        _error = 'Your session has expired. Sign in again to use live chat.';
      });
      return;
    }
    _socket?.dispose();
    final socket = io.io(
      AppConstants.apiBaseUrl,
      io.OptionBuilder()
          .setPath('/ws')
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setReconnectionAttempts(3)
          .setReconnectionDelay(800)
          .setReconnectionDelayMax(3000)
          .setTimeout(8000)
          .enableForceNew()
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) {
      if (!mounted) return;
      setState(() {
        _status = 'Connected';
        _error = null;
      });
      _loadNewest();
    });
    socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() => _status = 'Disconnected');
    });
    socket.on('connect_error', (dynamic error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Disconnected';
        _error = _socketError(error);
      });
    });
    socket.on('chat:session-expired', (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Session expired';
        _error = 'Your session has expired. Sign in again to use live chat.';
      });
      socket.disconnect();
    });
    socket.on('chat:me', (dynamic raw) {
      if (!mounted || raw is! Map) return;
      setState(() => _canWrite = raw['canWrite'] == true);
    });
    socket.on('chat:active', (dynamic raw) {
      if (!mounted || raw is! Map) return;
      setState(() => _activeCount = _asInt(raw['count']));
    });
    socket.on('chat:new', (dynamic raw) {
      final message = _ChatMessage.tryParse(raw);
      if (!mounted || message == null) return;
      setState(() {
        if (message.parentId == null) {
          _messages = _mergeMessages(_messages, [message]);
        } else {
          _messages = _messages
              .map(
                (item) => item.id == message.parentId && !message.restored
                    ? item.copyWith(replyCount: item.replyCount + 1)
                    : item,
              )
              .toList();
        }
      });
    });
    socket.on('chat:removed', (dynamic raw) {
      if (!mounted || raw is! Map) return;
      final id = raw['id']?.toString();
      final parentId = raw['parent_id']?.toString();
      final deleted = raw['deleted'] == true;
      if (id == null) return;
      setState(() {
        _messages = _messages
            .where((item) => item.id != id)
            .map(
              (item) => deleted && item.id == parentId
                  ? item.copyWith(
                      replyCount: (item.replyCount - 1).clamp(0, 1 << 30),
                    )
                  : item,
            )
            .toList();
      });
    });
  }

  Future<void> _loadNewest() async {
    final response = await _request('chat:history', {'limit': _pageSize});
    if (!mounted) return;
    if (response['ok'] != true) {
      setState(() {
        _loading = false;
        _error = response['error']?.toString() ?? 'Unable to load live chat.';
      });
      return;
    }
    final data = _map(response['data']);
    final messages = _readMessages(data['messages']);
    setState(() {
      _messages = _mergeMessages(_messages, messages);
      _hasOlder = data['hasMore'] == true;
      _loading = false;
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    final response = await _request('chat:history', {
      'beforeSeq': _messages.first.seq,
      'limit': _pageSize,
    });
    if (!mounted) return;
    if (response['ok'] == true) {
      final data = _map(response['data']);
      setState(() {
        _messages = _mergeMessages(_messages, _readMessages(data['messages']));
        _hasOlder = data['hasMore'] == true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error']?.toString() ?? 'Could not load older messages.',
          ),
        ),
      );
    }
    if (mounted) setState(() => _loadingOlder = false);
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    final response = await _request('chat:send', {'content': content});
    if (!mounted) return;
    setState(() => _sending = false);
    if (response['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error']?.toString() ?? 'Message could not be sent.',
          ),
        ),
      );
      return;
    }
    _composer.clear();
  }

  Future<void> _report(_ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report message?'),
        content: const Text(
          'The moderation team will review this anonymous message.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final response = await _request('chat:report', {
      'messageId': message.id,
      'reason': 'other',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['ok'] == true
              ? 'Message reported.'
              : response['error']?.toString() ??
                    'Report could not be submitted.',
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _request(
    String event,
    Map<String, dynamic> data,
  ) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.value({
        'ok': false,
        'error': 'Not connected to live chat.',
      });
    }
    return _socketRequest(socket, event, data);
  }

  void _openThread(_ChatMessage parent) {
    final socket = _socket;
    if (socket == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LiveChatThreadScreen(
          socket: socket,
          parent: parent,
          canWrite: _canWrite == true,
          onReport: _report,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (_status) {
      'Connected' => Theme.of(context).colorScheme.primary,
      'Connecting' => Theme.of(context).colorScheme.tertiary,
      _ => Theme.of(context).colorScheme.error,
    };
    return PredictiveBackScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Live chat'),
          actions: [
            if (_activeCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: StatusChip(
                    label: '$_activeCount online',
                    color: color,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(label: _status, color: color),
              ),
            ),
            Expanded(child: _buildMessages()),
            _Composer(
              controller: _composer,
              enabled: _canWrite == true && _status == 'Connected',
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const LoadingIndicator(message: 'Loading live chat');
    if (_messages.isEmpty && _error != null) {
      return ErrorDisplay(message: _error!, onRetry: _connect);
    }
    if (_messages.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No messages yet',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadNewest,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        children: [
          if (_hasOlder)
            Center(
              child: OutlinedButton(
                onPressed: _loadingOlder ? null : _loadOlder,
                child: _loadingOlder
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load older messages'),
              ),
            ),
          ..._messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChatMessageCard(
                message: message,
                canWrite: _canWrite == true,
                onOpenThread: () => _openThread(message),
                onReport: () => _report(message),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveChatThreadScreen extends StatefulWidget {
  const _LiveChatThreadScreen({
    required this.socket,
    required this.parent,
    required this.canWrite,
    required this.onReport,
  });

  final io.Socket socket;
  final _ChatMessage parent;
  final bool canWrite;
  final Future<void> Function(_ChatMessage message) onReport;

  @override
  State<_LiveChatThreadScreen> createState() => _LiveChatThreadScreenState();
}

class _LiveChatThreadScreenState extends State<_LiveChatThreadScreen> {
  static const _pageSize = 30;
  final _composer = TextEditingController();
  List<_ChatMessage> _replies = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await _socketRequest(widget.socket, 'chat:thread', {
      'parentId': widget.parent.id,
      'afterSeq': 0,
      'limit': _pageSize,
    });
    if (!mounted) return;
    if (response['ok'] != true) {
      setState(() {
        _loading = false;
        _error = response['error']?.toString() ?? 'Unable to load replies.';
      });
      return;
    }
    final data = _map(response['data']);
    setState(() {
      _replies = _readMessages(data['messages']);
      _loading = false;
    });
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    final response = await _socketRequest(widget.socket, 'chat:send', {
      'content': content,
      'parentId': widget.parent.id,
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (response['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error']?.toString() ?? 'Reply could not be sent.',
          ),
        ),
      );
      return;
    }
    _composer.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) => PredictiveBackScope(
    child: Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const LoadingIndicator(message: 'Loading thread')
                : _error != null
                ? ErrorDisplay(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      children: [
                        _ChatMessageCard(
                          message: widget.parent,
                          canWrite: widget.canWrite,
                          onReport: () => widget.onReport(widget.parent),
                        ),
                        if (_replies.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(6, 18, 6, 10),
                            child: Text('Replies'),
                          ),
                          ..._replies.map(
                            (reply) => Padding(
                              padding: const EdgeInsets.only(
                                left: 18,
                                bottom: 10,
                              ),
                              child: _ChatMessageCard(
                                message: reply,
                                canWrite: widget.canWrite,
                                onReport: () => widget.onReport(reply),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          _Composer(
            controller: _composer,
            enabled: widget.canWrite && widget.socket.connected,
            sending: _sending,
            onSend: _send,
            hintText: 'Write a reply',
          ),
        ],
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
    this.hintText = 'Write a message',
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;
  final String hintText;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: 1,
        maxLines: 3,
        maxLength: 500,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => onSend(),
        decoration: InputDecoration(
          hintText: enabled
              ? hintText
              : 'Posting is unavailable for this account',
          suffixIcon: IconButton(
            tooltip: 'Send',
            onPressed: enabled && !sending ? onSend : null,
            icon: sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
          ),
        ),
      ),
    ),
  );
}

class _ChatMessageCard extends StatelessWidget {
  const _ChatMessageCard({
    required this.message,
    required this.canWrite,
    required this.onReport,
    this.onOpenThread,
  });

  final _ChatMessage message;
  final bool canWrite;
  final VoidCallback onReport;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text('Anonymous', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              _relativeTime(message.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          message.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (onOpenThread != null)
              TextButton.icon(
                onPressed: onOpenThread,
                icon: const Icon(Icons.reply_outlined, size: 17),
                label: Text('${message.replyCount}'),
              ),
            const Spacer(),
            if (canWrite)
              IconButton(
                tooltip: 'Report message',
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined),
              ),
            if (onOpenThread != null)
              IconButton(
                tooltip: 'Open thread',
                onPressed: onOpenThread,
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.seq,
    required this.content,
    required this.createdAt,
    required this.parentId,
    required this.replyCount,
    required this.restored,
  });

  final String id;
  final int seq;
  final String content;
  final DateTime createdAt;
  final String? parentId;
  final int replyCount;
  final bool restored;

  factory _ChatMessage.fromMap(Map<String, dynamic> json) => _ChatMessage(
    id: json['id']?.toString() ?? '',
    seq: _asInt(json['seq']),
    content: json['content']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    parentId: json['parent_id']?.toString(),
    replyCount: _asInt(json['reply_count']),
    restored: json['restored'] == true,
  );

  static _ChatMessage? tryParse(dynamic raw) {
    final value = _map(raw);
    final message = _ChatMessage.fromMap(value);
    return message.id.isEmpty || message.content.isEmpty ? null : message;
  }

  _ChatMessage copyWith({int? replyCount}) => _ChatMessage(
    id: id,
    seq: seq,
    content: content,
    createdAt: createdAt,
    parentId: parentId,
    replyCount: replyCount ?? this.replyCount,
    restored: restored,
  );
}

Map<String, dynamic> _map(dynamic raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

int _asInt(dynamic raw) =>
    raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;

List<_ChatMessage> _readMessages(dynamic raw) => raw is List
    ? raw.map(_ChatMessage.tryParse).whereType<_ChatMessage>().toList()
    : <_ChatMessage>[];

List<_ChatMessage> _mergeMessages(
  List<_ChatMessage> current,
  List<_ChatMessage> incoming,
) {
  final byId = {for (final message in current) message.id: message};
  for (final message in incoming) {
    byId[message.id] = message;
  }
  final messages = byId.values.toList()
    ..sort((left, right) => left.seq.compareTo(right.seq));
  return messages;
}

Future<Map<String, dynamic>> _socketRequest(
  io.Socket socket,
  String event,
  Map<String, dynamic> data,
) {
  if (!socket.connected) {
    return Future.value({'ok': false, 'error': 'Not connected to live chat.'});
  }
  final response = Completer<Map<String, dynamic>>();
  final timer = Timer(const Duration(seconds: 8), () {
    if (!response.isCompleted) {
      response.complete({
        'ok': false,
        'error': 'Request timed out. Check your connection.',
      });
    }
  });
  socket.emitWithAck(
    event,
    data,
    ack: (dynamic raw) {
      timer.cancel();
      if (!response.isCompleted) response.complete(_map(raw));
    },
  );
  return response.future;
}

String _relativeTime(DateTime value) {
  final delta = DateTime.now().difference(value);
  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inHours < 1) return '${delta.inMinutes}m ago';
  if (delta.inDays < 1) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

String _socketError(dynamic error) {
  if (error is Map && error['message'] != null) {
    return error['message'].toString();
  }
  final message = error?.toString().trim();
  if (message?.contains('was not upgraded to websocket') == true) {
    return 'Live chat is temporarily unavailable. Please try again shortly.';
  }
  return message == null || message.isEmpty
      ? 'Unable to connect to live chat.'
      : message;
}
