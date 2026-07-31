import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:student_activities/core/markdown.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _categories = {};
  Timer? _keyboardDismissTimer;
  bool _sending = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardDismissTimer?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty || !_inputFocus.hasFocus) return;
    final keyboardVisible = views.first.viewInsets.bottom > 0;
    if (keyboardVisible) {
      _keyboardDismissTimer?.cancel();
      return;
    }
    _keyboardDismissTimer?.cancel();
    _keyboardDismissTimer = Timer(const Duration(milliseconds: 180), () {
      final currentViews = WidgetsBinding.instance.platformDispatcher.views;
      if (currentViews.isNotEmpty &&
          currentViews.first.viewInsets.bottom == 0 &&
          _inputFocus.hasFocus) {
        _dismissInputFocus();
      }
    });
  }

  void _dismissInputFocus() {
    _inputFocus.unfocus(disposition: UnfocusDisposition.scope);
  }

  Future<void> _send() async {
    final message = _input.text.trim();
    if (message.isEmpty || _sending) return;
    final history = _messages
        .where((item) => item.role == 'user' || item.role == 'assistant')
        .take(10)
        .map((item) => {'role': item.role, 'content': item.content})
        .toList();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: message));
      _sending = true;
      _input.clear();
    });
    _scrollToEnd();
    final response = await ApiClient.instance.post(
      '/documents/chat',
      body: {
        'message': message,
        'history': history,
        if (_categories.isNotEmpty)
          'filters': {'entity_categories': _categories.toList()},
        'stream': false,
      },
    );
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content:
                response.error ?? 'I could not answer that question right now.',
          ),
        );
        _sending = false;
      });
      _scrollToEnd();
      return;
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    final answer = payload['answer']?.toString() ?? 'No answer was returned.';
    final sources = (payload['sources'] as List<dynamic>? ?? const [])
        .map(
          (item) => ChatSource.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    setState(() {
      _messages.add(
        ChatMessage(role: 'assistant', content: answer, sources: sources),
      );
      _sending = false;
    });
    _scrollToEnd();
    await _saveTurn(message, answer, sources, payload['model']?.toString());
  }

  Future<void> _saveTurn(
    String question,
    String answer,
    List<ChatSource> sources,
    String? model,
  ) async {
    final response = await ApiClient.instance.post(
      '/documents/history',
      body: {
        if (_conversationId != null) 'conv_id': _conversationId,
        'user_msg': question,
        'assistant_msg': answer,
        'sources': sources
            .map(
              (source) => {
                'doc_id': source.docId,
                'title': source.title,
                'heading': source.heading,
                'score': 0,
              },
            )
            .toList(),
        'model': ?model,
      },
    );
    if (response.success && response.data is Map) {
      final payload = Map<String, dynamic>.from(response.data as Map);
      if (mounted && payload['conv_id'] != null) {
        setState(() => _conversationId = payload['conv_id'].toString());
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _newConversation() {
    setState(() {
      _messages.clear();
      _conversationId = null;
    });
  }

  Future<void> _showHistory() async {
    var loading = true;
    List<Map<String, dynamic>> conversations = [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> load() async {
            final response = await ApiClient.instance.get('/documents/history');
            if (!context.mounted) return;
            final data = response.data is Map
                ? Map<String, dynamic>.from(response.data as Map)
                : const <String, dynamic>{};
            setSheetState(() {
              conversations =
                  (data['conversations'] as List<dynamic>? ?? const [])
                      .map((item) => Map<String, dynamic>.from(item as Map))
                      .toList();
              loading = false;
            });
          }

          if (loading && conversations.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => load());
          }
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                    child: Row(
                      children: [
                        Text(
                          'Conversations',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : conversations.isEmpty
                        ? const EmptyState(
                            icon: Icons.history_outlined,
                            title: 'No saved conversations',
                          )
                        : ListView.separated(
                            itemCount: conversations.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final conversation = conversations[index];
                              return ListTile(
                                title: Text(
                                  conversation['title']?.toString() ??
                                      'Conversation',
                                ),
                                subtitle: Text(
                                  _historyTime(
                                    conversation['updated_at']?.toString(),
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Delete conversation',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final id = conversation['conv_id']
                                        ?.toString();
                                    if (id == null) return;
                                    await ApiClient.instance.delete(
                                      '/documents/history/$id',
                                    );
                                    setSheetState(
                                      () => conversations.removeAt(index),
                                    );
                                    if (_conversationId == id) {
                                      _newConversation();
                                    }
                                  },
                                ),
                                onTap: () async {
                                  final id = conversation['conv_id']
                                      ?.toString();
                                  if (id == null) return;
                                  final response = await ApiClient.instance.get(
                                    '/documents/history/$id',
                                  );
                                  if (!context.mounted ||
                                      !response.success ||
                                      response.data is! Map) {
                                    return;
                                  }
                                  final payload = Map<String, dynamic>.from(
                                    response.data as Map,
                                  );
                                  final turns =
                                      payload['turns'] as List<dynamic>? ??
                                      const [];
                                  setState(() {
                                    _conversationId = id;
                                    _messages
                                      ..clear()
                                      ..addAll(
                                        turns.expand((turn) {
                                          final data =
                                              Map<String, dynamic>.from(
                                                turn as Map,
                                              );
                                          final sources =
                                              (data['sources']
                                                          as List<dynamic>? ??
                                                      const [])
                                                  .map(
                                                    (
                                                      item,
                                                    ) => ChatSource.fromJson(
                                                      Map<String, dynamic>.from(
                                                        item as Map,
                                                      ),
                                                    ),
                                                  )
                                                  .toList();
                                          return [
                                            ChatMessage(
                                              role: 'user',
                                              content:
                                                  data['user_msg']
                                                      ?.toString() ??
                                                  '',
                                            ),
                                            ChatMessage(
                                              role: 'assistant',
                                              content:
                                                  data['assistant_msg']
                                                      ?.toString() ??
                                                  '',
                                              sources: sources,
                                              turnId: data['turn_id']
                                                  ?.toString(),
                                            ),
                                          ];
                                        }),
                                      );
                                  });
                                  if (context.mounted) Navigator.pop(context);
                                  _scrollToEnd();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _historyTime(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children:
                      ['courses', 'exams', 'policies', 'assessments', 'roles']
                          .map(
                            (category) => FilterChip(
                              label: Text(_label(category)),
                              selected: _categories.contains(category),
                              onSelected: (selected) => setState(
                                () => selected
                                    ? _categories.add(category)
                                    : _categories.remove(category),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              IconButton(
                tooltip: 'Conversation history',
                onPressed: _showHistory,
                icon: const Icon(Icons.history_outlined),
              ),
              IconButton(
                tooltip: 'New conversation',
                onPressed: _newConversation,
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 44),
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Academic assistant',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ask about courses, exams, policies, assessments, or student roles.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                                'How is course grading calculated?',
                                'What happens if I miss an OPPE?',
                                'What are the diploma requirements?',
                              ]
                              .map(
                                (question) => ActionChip(
                                  label: Text(question),
                                  onPressed: () {
                                    _input.text = question;
                                    _send();
                                  },
                                ),
                              )
                              .toList(),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == _messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return _ChatBubble(message: _messages[index]);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    onTapOutside: (_) => _dismissInputFocus(),
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask a question',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _label(String value) => switch (value) {
    'courses' => 'Courses',
    'exams' => 'Exams',
    'policies' => 'Policies',
    'assessments' => 'Assessments',
    _ => 'Roles',
  };
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mine)
              SelectableText(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: scheme.onPrimaryContainer,
                ),
              )
            else
              GptMarkdown(
                normalizeMarkdownLinks(message.content),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: scheme.onSurface,
                ),
                useDollarSignsForLatex: true,
                onLinkTap: (url, _) async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) await launchUrl(uri);
                },
              ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Sources', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ...message.sources.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '• ${source.title}${source.heading?.isNotEmpty == true ? ' — ${source.heading}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
