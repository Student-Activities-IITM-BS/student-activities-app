import 'package:flutter/material.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/screens/voices/comment_thread_screen.dart';
import 'package:student_activities/screens/voices/live_chat_screen.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:student_activities/services/storage_service.dart';
import 'package:student_activities/services/voices_chat_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class VoicesScreen extends StatefulWidget {
  const VoicesScreen({super.key});

  @override
  State<VoicesScreen> createState() => _VoicesScreenState();
}

class _VoicesScreenState extends State<VoicesScreen> {
  final _composer = TextEditingController();
  final _chat = VoicesChatService();
  List<VoicesGroup> _groups = [];
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _words = [];
  Map<String, String> _votes = {};
  List<String> _wordChoices = [];
  Map<String, String> _wordVotes = {};
  VoicesGroup? _selectedGroup;
  bool _loading = true;
  bool _loadingComments = false;
  bool _posting = false;
  bool _submittingWord = false;
  String? _joinedRoom;
  io.Socket? _eventsSocket;
  bool _canWrite = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVotes();
    _loadWordData();
    _loadGroups();
  }

  @override
  void dispose() {
    _composer.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _loadVotes() async {
    final values = await StorageService.instance.getCommentVotes();
    if (mounted) setState(() => _votes = values);
  }

  Future<void> _loadWordData() async {
    final responses = await Future.wait([
      ApiClient.instance.get('/voices/words'),
      ApiClient.instance.get('/voices/my-votes'),
    ]);
    if (!mounted) return;
    final wordsPayload = responses[0].data;
    final votesPayload = responses[1].data;
    final words = wordsPayload is Map && wordsPayload['words'] is List
        ? (wordsPayload['words'] as List)
              .map((word) => word.toString())
              .where((word) => word.isNotEmpty)
              .toList()
        : <String>[];
    final values = <String, String>{};
    if (votesPayload is Map && votesPayload['votes'] is List) {
      for (final rawVote in votesPayload['votes'] as List) {
        if (rawVote is! Map) continue;
        final groupId = rawVote['group_id']?.toString();
        final word = rawVote['word']?.toString();
        if (groupId?.isNotEmpty == true && word?.isNotEmpty == true) {
          values[groupId!] = word!;
        }
      }
    }
    setState(() {
      _wordChoices = words;
      _wordVotes = values;
    });
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await ApiClient.instance.get('/voices/groups');
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _loading = false;
        _error = response.error ?? 'Unable to load communities.';
      });
      return;
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final groups = (data['groups'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              VoicesGroup.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    setState(() {
      _groups = groups;
      _selectedGroup = groups.isEmpty ? null : groups.first;
      _loading = false;
    });
    await _loadGroupContent();
  }

  String? get _commentGroupId {
    final group = _selectedGroup;
    if (group == null) return null;
    return group.type == 'SOCIETY' ? group.groupId ?? group.id : group.id;
  }

  Future<void> _loadGroupContent() async {
    final group = _selectedGroup;
    final groupId = _commentGroupId;
    if (group == null || groupId == null) return;
    setState(() => _loadingComments = true);
    final socket = await _chat.connect();
    if (!mounted) return;
    if (socket == null) {
      setState(() => _loadingComments = false);
      return;
    }
    _attachSocketEvents(socket);
    final joined = await _chat.join(groupId);
    if (!mounted) return;
    if (joined['ok'] != true) {
      setState(() => _loadingComments = false);
      return;
    }
    _joinedRoom = groupId;
    final wordParams = group.type == 'SOCIETY'
        ? {'societyId': group.id}
        : {'groupId': group.id};
    final responses = await Future.wait([
      _chat.history(socket),
      ApiClient.instance.get('/voices/votes', queryParams: wordParams),
    ]);
    if (!mounted) return;
    if (_selectedGroup?.id != group.id || _commentGroupId != groupId) return;
    final commentsResponse = responses[0] as Map<String, dynamic>;
    final wordsResponse = responses[1] as ApiResponse;
    final commentsData = commentsResponse['data'] is Map
        ? Map<String, dynamic>.from(commentsResponse['data'] as Map)
        : const <String, dynamic>{};
    final wordsData = wordsResponse.data is Map
        ? Map<String, dynamic>.from(wordsResponse.data as Map)
        : const <String, dynamic>{};
    setState(() {
      _comments = (commentsData['comments'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (_comments.isEmpty && commentsData['messages'] is List) {
        _comments = _rootMessages(commentsData['messages'] as List);
      }
      _words = (wordsData['wordCloud'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _loadingComments = false;
    });
  }

  Future<void> _submit() async {
    final content = _composer.text.trim();
    final group = _selectedGroup;
    if (content.isEmpty || group == null) return;
    setState(() => _posting = true);
    final groupId = group.type == 'SOCIETY'
        ? group.groupId ?? group.id
        : group.id;
    io.Socket? socket = await _chat.connect();
    if (socket != null) _attachSocketEvents(socket);
    if (socket == null || _joinedRoom != groupId) {
      final joined = await _chat.join(groupId);
      if (joined['ok'] == true) _joinedRoom = groupId;
      socket ??= _chat.socket;
    }
    final response = socket == null || _joinedRoom != groupId
        ? <String, dynamic>{
            'ok': false,
            'error': 'Unable to connect to this discussion space.',
          }
        : await _chat.send(socket, content);
    if (!mounted) return;
    setState(() => _posting = false);
    if (response['ok'] != true) {
      debugPrint(
        '[Voices] Comment submission failed: room=$groupId, '
        'error=${response['error']}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error']?.toString() ?? 'Could not post your comment.',
          ),
        ),
      );
      return;
    }
    _composer.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Posted anonymously.')));
    await _loadGroupContent();
  }

  void _attachSocketEvents(io.Socket socket) {
    if (identical(_eventsSocket, socket)) return;
    _eventsSocket = socket;
    socket.onDisconnect((_) {
      if (identical(_eventsSocket, socket)) {
        _eventsSocket = null;
        _joinedRoom = null;
      }
    });
    socket.on('chat:me', (dynamic raw) {
      if (!mounted || raw is! Map) return;
      setState(() => _canWrite = raw['canWrite'] != false);
    });
    socket.on('chat:new', (dynamic raw) {
      if (!mounted || raw is! Map) return;
      final message = Map<String, dynamic>.from(raw);
      if (message['group_id']?.toString() != _commentGroupId ||
          message['parent_id'] != null) {
        return;
      }
      setState(() {
        final id = message['id']?.toString();
        if (id == null) return;
        final index = _comments.indexWhere((item) => item['id'] == id);
        if (index >= 0) {
          _comments[index] = message;
        } else {
          _comments = [
            ..._comments,
            message,
          ]..sort((left, right) => _sequence(left).compareTo(_sequence(right)));
        }
      });
    });
    socket.on('chat:removed', (dynamic raw) {
      if (!mounted || raw is! Map) return;
      final id = raw['id']?.toString();
      if (id == null) return;
      setState(() => _comments.removeWhere((item) => item['id'] == id));
    });
    socket.on('chat:votes', (dynamic raw) {
      if (!mounted || raw is! Map) return;
      final id = raw['id']?.toString();
      if (id == null) return;
      final index = _comments.indexWhere((item) => item['id'] == id);
      if (index < 0) return;
      setState(() {
        _comments[index]['upvotes_count'] = raw['upvotes_count'] ?? 0;
        _comments[index]['downvotes_count'] = raw['downvotes_count'] ?? 0;
      });
    });
  }

  List<Map<String, dynamic>> _rootMessages(List<dynamic> raw) => raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) => item['parent_id'] == null)
      .toList();

  int _sequence(Map<String, dynamic> message) => message['seq'] is num
      ? (message['seq'] as num).toInt()
      : int.tryParse(message['seq']?.toString() ?? '') ?? 0;

  Future<void> _showDiscussionSpacePicker() async {
    final selected = await showModalBottomSheet<VoicesGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.68;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: Text(
                    'Discussion space',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Choose where you want to read and post anonymously.',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (_, index) {
                      final group = _groups[index];
                      final isSelected = group.id == _selectedGroup?.id;
                      final isSociety = group.type == 'SOCIETY';
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          foregroundColor: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          child: Icon(
                            isSociety
                                ? Icons.interests_outlined
                                : Icons.home_work_outlined,
                            size: 20,
                          ),
                        ),
                        title: Text(group.name),
                        subtitle: Text(isSociety ? 'Society' : 'House'),
                        trailing: isSelected
                            ? Icon(Icons.check, color: scheme.primary)
                            : null,
                        onTap: () => Navigator.pop(sheetContext, group),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null || selected.id == _selectedGroup?.id) {
      return;
    }
    setState(() => _selectedGroup = selected);
    await _loadGroupContent();
  }

  Future<void> _submitWordVote(String word) async {
    final group = _selectedGroup;
    if (group == null || _submittingWord) return;
    setState(() => _submittingWord = true);
    final body = <String, dynamic>{'word': word};
    if (group.type == 'SOCIETY') {
      body['societyId'] = group.id;
    } else {
      body['groupId'] = group.id;
    }
    final response = await ApiClient.instance.post('/voices/vote', body: body);
    if (!mounted) return;
    setState(() => _submittingWord = false);
    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Word vote could not be saved.'),
        ),
      );
      return;
    }
    setState(() => _wordVotes[group.id] = word);
    await _loadGroupContent();
  }

  Future<void> _showWordVote() async {
    final group = _selectedGroup;
    if (group == null || _wordChoices.isEmpty) return;
    var selected = _wordVotes[group.id];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Describe ${group.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose one word. You can change it later when voting reopens.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _wordChoices
                          .map(
                            (word) => ChoiceChip(
                              label: Text(word),
                              selected: selected == word,
                              onSelected: (_) =>
                                  setModalState(() => selected = word),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submittingWord
                          ? null
                          : () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: selected == null || _submittingWord
                          ? null
                          : () async {
                              await _submitWordVote(selected!);
                              if (sheetContext.mounted &&
                                  mounted &&
                                  !_submittingWord) {
                                Navigator.pop(sheetContext);
                              }
                            },
                      child: _submittingWord
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save vote'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _vote(Map<String, dynamic> comment, String nextVote) async {
    final id = comment['id']?.toString();
    if (id == null || id.isEmpty) return;
    final before = _votes[id];
    final after = before == nextVote ? null : nextVote;
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
    final calls = <String>[];
    if (before == 'up') calls.add('unupvote');
    if (before == 'down') calls.add('undownvote');
    if (after == 'up') calls.add('upvote');
    if (after == 'down') calls.add('downvote');
    for (final call in calls) {
      final response = await ApiClient.instance.post(
        '/voices/comments/$id/$call',
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
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error ?? 'Vote could not be saved.')),
        );
        return;
      }
    }
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  String _relativeTime(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) return '';
    final delta = DateTime.now().difference(date);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator(message: 'Loading Voices');
    if (_error != null) {
      return ErrorDisplay(message: _error!, onRetry: _loadGroups);
    }
    if (_groups.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No discussion spaces available',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGroupContent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: _showDiscussionSpacePicker,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer,
                      child: Icon(
                        _selectedGroup?.type == 'SOCIETY'
                            ? Icons.interests_outlined
                            : Icons.home_work_outlined,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discussion space',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedGroup?.name ?? 'Choose a space',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LiveChatScreen())),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Live chat'),
            ),
          ),
          const SizedBox(height: 16),
          if (_words.isNotEmpty || _wordChoices.isNotEmpty) ...[
            const SectionHeader(title: 'Pulse'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _words.take(24).map((word) {
                      final text =
                          word['word']?.toString() ??
                          word['text']?.toString() ??
                          '';
                      final count = _number(word['count'] ?? word['votes']);
                      if (text.isEmpty) return const SizedBox.shrink();
                      return Chip(
                        label: Text(count > 0 ? '$text · $count' : text),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _wordChoices.isEmpty ? null : _showWordVote,
                      icon: const Icon(Icons.how_to_vote_outlined),
                      label: Text(
                        _selectedGroup != null &&
                                _wordVotes.containsKey(_selectedGroup!.id)
                            ? 'Update word vote'
                            : 'Vote on a word',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          const SectionHeader(title: 'Anonymous discussion'),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _composer,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Share a thought with this community',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _posting || !_canWrite ? null : _submit,
                    icon: _posting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Post anonymously'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingComments)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'Start the conversation',
              ),
            )
          else
            ..._comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CommentCard(
                  comment: comment,
                  userVote: _votes[comment['id']?.toString()],
                  relativeTime: _relativeTime(
                    comment['created_at']?.toString(),
                  ),
                  onVote: _vote,
                  onOpen: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CommentThreadScreen(parentComment: comment),
                        ),
                      )
                      .then((_) => _loadGroupContent()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.userVote,
    required this.relativeTime,
    required this.onVote,
    required this.onOpen,
  });

  final Map<String, dynamic> comment;
  final String? userVote;
  final String relativeTime;
  final Future<void> Function(Map<String, dynamic>, String) onVote;
  final VoidCallback onOpen;

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text('Anonymous', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text(relativeTime, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment['content']?.toString() ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CommentAction(
                icon: Icons.arrow_upward,
                label: '${_number(comment['upvotes_count'])}',
                selected: userVote == 'up',
                onTap: () => onVote(comment, 'up'),
              ),
              _CommentAction(
                icon: Icons.arrow_downward,
                label: '${_number(comment['downvotes_count'])}',
                selected: userVote == 'down',
                onTap: () => onVote(comment, 'down'),
              ),
              _CommentAction(
                icon: Icons.reply_outlined,
                label: '${_number(comment['reply_count'])}',
                onTap: onOpen,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Open thread',
                onPressed: onOpen,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
