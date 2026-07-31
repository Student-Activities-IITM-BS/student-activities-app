import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:student_activities/core/markdown.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:student_activities/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();
  final Map<String, String> _votes = {};
  List<EventUpdate> _updates = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVotes();
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadVotes() async {
    final votes = await StorageService.instance.getUpdateVotes();
    if (mounted) setState(() => _votes.addAll(votes));
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 280) _loadMore();
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _error = null;
      });
    }
    if (_page == 1) setState(() => _isLoading = true);

    final response = await ApiClient.instance.get(
      '/events-updates',
      queryParams: {'page': _page, 'limit': 20},
    );
    if (!mounted) return;

    if (!response.success || response.data is! Map) {
      setState(() {
        _error = response.error ?? 'Unable to load updates.';
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    final payload = Map<String, dynamic>.from(response.data as Map);
    final items = (payload['data'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              EventUpdate.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final pagination = payload['pagination'] is Map
        ? Map<String, dynamic>.from(payload['pagination'] as Map)
        : const <String, dynamic>{};
    setState(() {
      _updates = _page == 1 ? items : [..._updates, ...items];
      _hasMore = pagination['hasMore'] == true;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _page += 1;
    await _loadFeed();
  }

  Future<void> _toggleVote(EventUpdate update, String nextVote) async {
    final previousVote = _votes[update.id];
    final action = previousVote == nextVote ? 'un$nextVote' : nextVote;
    final optimisticVote = previousVote == nextVote ? null : nextVote;
    final index = _updates.indexWhere((item) => item.id == update.id);
    if (index < 0) return;

    setState(() {
      if (optimisticVote == null) {
        _votes.remove(update.id);
      } else {
        _votes[update.id] = optimisticVote;
      }
      _updates[index] = EventUpdate(
        id: update.id,
        title: update.title,
        content: update.content,
        imageUrls: update.imageUrls,
        authorName: update.authorName,
        authorEmail: update.authorEmail,
        likesCount:
            update.likesCount +
            _countDelta(previousVote, optimisticVote, 'upvote'),
        dislikesCount:
            update.dislikesCount +
            _countDelta(previousVote, optimisticVote, 'downvote'),
        createdAt: update.createdAt,
        updatedAt: update.updatedAt,
      );
    });

    final response = await ApiClient.instance.post(
      '/events-updates/${update.id}/$action',
    );
    if (response.success) {
      await StorageService.instance.saveUpdateVotes(_votes);
      return;
    }

    if (!mounted) return;
    setState(() {
      if (previousVote == null) {
        _votes.remove(update.id);
      } else {
        _votes[update.id] = previousVote;
      }
      _updates[index] = update;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.error ?? 'Vote could not be saved.')),
    );
  }

  int _countDelta(String? before, String? after, String vote) {
    return (after == vote ? 1 : 0) - (before == vote ? 1 : 0);
  }

  String _relativeTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingIndicator(message: 'Loading updates');
    if (_error != null && _updates.isEmpty) {
      return ErrorDisplay(
        message: _error!,
        onRetry: () => _loadFeed(refresh: true),
      );
    }
    if (_updates.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadFeed(refresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 180),
            EmptyState(icon: Icons.campaign_outlined, title: 'No updates yet'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFeed(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        itemCount: _updates.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _updates.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _UpdateCard(
            update: _updates[index],
            vote: _votes[_updates[index].id],
            relativeTime: _relativeTime(_updates[index].createdAt),
            onVote: _toggleVote,
          );
        },
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
    required this.vote,
    required this.relativeTime,
    required this.onVote,
  });

  final EventUpdate update;
  final String? vote;
  final String relativeTime;
  final Future<void> Function(EventUpdate update, String vote) onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    child: Text(
                      update.authorName.isEmpty
                          ? '?'
                          : update.authorName.characters.first.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          update.authorName.isEmpty
                              ? 'Student Activities'
                              : update.authorName,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(relativeTime, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz),
                ],
              ),
              const SizedBox(height: 14),
              Text(update.title, style: theme.textTheme.titleMedium),
              if (update.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                GptMarkdown(
                  normalizeMarkdownLinks(update.content),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  onLinkTap: (url, _) async {
                    final uri = Uri.tryParse(url);
                    if (uri != null) await launchUrl(uri);
                  },
                ),
              ],
              if (update.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ImageStrip(urls: update.imageUrls),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _VoteButton(
                    icon: Icons.thumb_up_outlined,
                    count: update.likesCount,
                    selected: vote == 'upvote',
                    onPressed: () => onVote(update, 'upvote'),
                  ),
                  const SizedBox(width: 8),
                  _VoteButton(
                    icon: Icons.thumb_down_outlined,
                    count: update.dislikesCount,
                    selected: vote == 'downvote',
                    onPressed: () => onVote(update, 'downvote'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Open update',
                    onPressed: () => _showDetail(context),
                    icon: const Icon(Icons.open_in_new),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              update.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Posted by ${update.authorName.isEmpty ? 'Student Activities' : update.authorName} · $relativeTime',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (update.content.isNotEmpty) ...[
              const SizedBox(height: 20),
              GptMarkdown(
                normalizeMarkdownLinks(update.content),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.55),
                useDollarSignsForLatex: true,
                onLinkTap: (url, _) async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) await launchUrl(uri);
                },
              ),
            ],
            if (update.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...update.imageUrls.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
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

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 192,
      child: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (_, index) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            urls[index],
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text('$count'),
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
