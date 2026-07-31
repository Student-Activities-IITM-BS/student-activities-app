import 'package:flutter/material.dart';
import 'package:student_activities/core/predictive_back.dart';
import 'package:student_activities/core/theme.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/services/api_client.dart';

class ElectionsScreen extends StatefulWidget {
  const ElectionsScreen({super.key});

  @override
  State<ElectionsScreen> createState() => _ElectionsScreenState();
}

class _ElectionsScreenState extends State<ElectionsScreen> {
  List<Election> _elections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await ApiClient.instance.get('/elections');
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _loading = false;
        _error = response.error ?? 'Unable to load elections.';
      });
      return;
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    setState(() {
      _elections = (payload['data'] as List<dynamic>? ?? const [])
          .map(
            (item) => Election.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator(message: 'Loading elections');
    if (_error != null) return ErrorDisplay(message: _error!, onRetry: _load);
    if (_elections.isEmpty) {
      return const EmptyState(
        icon: Icons.how_to_vote_outlined,
        title: 'No elections are available',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        itemCount: _elections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final election = _elections[index];
          return AppCard(
            onTap: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => ElectionDetailScreen(election: election),
                  ),
                )
                .then((_) => _load()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(
                      label: _statusLabel(election.status),
                      color: _statusColor(election.status),
                    ),
                    const Spacer(),
                    if (election.voted) const Icon(Icons.verified_outlined),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  election.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (election.position.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    election.position,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (election.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    election.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  _windowLabel(election),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ElectionDetailScreen extends StatefulWidget {
  const ElectionDetailScreen({super.key, required this.election});
  final Election election;

  @override
  State<ElectionDetailScreen> createState() => _ElectionDetailScreenState();
}

class _ElectionDetailScreenState extends State<ElectionDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  Election get _election =>
      _detail == null ? widget.election : Election.fromJson(_detail!);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await ApiClient.instance.get(
      '/elections/${widget.election.id}',
    );
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _loading = false;
        _error = response.error ?? 'Unable to load election.';
      });
      return;
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    setState(() {
      _detail = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'] as Map)
          : payload;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _candidates =>
      (_detail?['candidates'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<void> _vote() async {
    final election = _election;
    if (!election.eligible ||
        election.voted ||
        election.status != 'voting_open') {
      return;
    }
    String? selected;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cast your vote'),
          content: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (!_submitting) {
                  setDialogState(() => selected = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._candidates.map((candidate) {
                    final student = candidate['student'] is Map
                        ? Map<String, dynamic>.from(candidate['student'] as Map)
                        : const <String, dynamic>{};
                    return RadioListTile<String>(
                      value: candidate['id']?.toString() ?? '',
                      title: Text(
                        student['full_name']?.toString() ?? 'Candidate',
                      ),
                    );
                  }),
                  RadioListTile<String>(
                    value: '__nota__',
                    enabled: !_submitting,
                    title: const Text('NOTA'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Confirm vote'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    setState(() => _submitting = true);
    final response = await ApiClient.instance.post(
      '/elections/${election.id}/vote',
      body: selected == '__nota__'
          ? {'nota': true}
          : {'candidate_id': selected},
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Vote could not be recorded.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your vote has been recorded.')),
    );
    await _load();
  }

  Future<void> _showResults() async {
    final response = await ApiClient.instance.get(
      '/elections/${_election.id}/results',
    );
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Results are not available yet.'),
        ),
      );
      return;
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    final candidates = (data['candidates'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Results',
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
                child: ListView(
                  children: [
                    ...candidates.map((candidate) {
                      final student = candidate['student'] is Map
                          ? Map<String, dynamic>.from(
                              candidate['student'] as Map,
                            )
                          : const <String, dynamic>{};
                      final winner =
                          data['winner_candidate_id']?.toString() ==
                          candidate['id']?.toString();
                      return ListTile(
                        leading: Icon(
                          winner
                              ? Icons.emoji_events_outlined
                              : Icons.person_outline,
                        ),
                        title: Text(
                          student['full_name']?.toString() ?? 'Candidate',
                        ),
                        trailing: Text('${candidate['vote_count'] ?? 0} votes'),
                      );
                    }),
                    if (data['show_nota'] == true)
                      ListTile(
                        leading: const Icon(Icons.not_interested_outlined),
                        title: const Text('NOTA'),
                        trailing: Text('${data['nota_votes'] ?? 0} votes'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PredictiveBackScope(
        child: Scaffold(body: LoadingIndicator(message: 'Loading election')),
      );
    }
    if (_error != null) {
      return PredictiveBackScope(
        child: Scaffold(
          appBar: AppBar(),
          body: ErrorDisplay(message: _error!, onRetry: _load),
        ),
      );
    }
    final election = _election;
    return PredictiveBackScope(
      child: Scaffold(
        appBar: AppBar(title: Text(election.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StatusChip(
              label: _statusLabel(election.status),
              color: _statusColor(election.status),
            ),
            const SizedBox(height: 12),
            Text(
              election.position,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (election.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                election.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _Timeline(
                    label: 'Nominations',
                    start: election.nominationStart,
                    end: election.nominationEnd,
                  ),
                  const Divider(),
                  _Timeline(
                    label: 'Voting',
                    start: election.votingStart,
                    end: election.votingEnd,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Candidates'),
            if (_candidates.isEmpty)
              const AppCard(
                child: Text('Candidates will be listed once approved.'),
              )
            else
              ..._candidates.map((candidate) {
                final student = candidate['student'] is Map
                    ? Map<String, dynamic>.from(candidate['student'] as Map)
                    : const <String, dynamic>{};
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['full_name']?.toString() ?? 'Candidate',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (candidate['nomination_statement']
                                ?.toString()
                                .isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 6),
                          Text(candidate['nomination_statement'].toString()),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            if (election.status == 'voting_open' && !election.voted)
              FilledButton.icon(
                onPressed: _submitting || !election.eligible ? null : _vote,
                icon: const Icon(Icons.how_to_vote_outlined),
                label: Text(
                  election.eligible ? 'Cast vote' : 'Not eligible to vote',
                ),
              ),
            if (election.voted)
              const AppCard(
                child: ListTile(
                  leading: Icon(Icons.verified_outlined),
                  title: Text('Vote recorded'),
                ),
              ),
            if (election.status == 'results_published')
              OutlinedButton.icon(
                onPressed: _showResults,
                icon: const Icon(Icons.leaderboard_outlined),
                label: const Text('View results'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.label, this.start, this.end});
  final String label;
  final DateTime? start;
  final DateTime? end;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.schedule_outlined),
    title: Text(label),
    subtitle: Text('${_format(start)} - ${_format(end)}'),
  );
  String _format(DateTime? time) =>
      time == null ? 'Not scheduled' : '${time.day}/${time.month}/${time.year}';
}

String _statusLabel(String value) => switch (value) {
  'nominations_open' => 'Nominations open',
  'nominations_closed' => 'Nominations closed',
  'voting_open' => 'Voting open',
  'winner_pending' => 'Winner pending',
  'results_published' => 'Results published',
  _ => value.replaceAll('_', ' '),
};

Color _statusColor(String value) => switch (value) {
  'nominations_open' => Colors.deepPurple,
  'voting_open' => Colors.green,
  'results_published' => Colors.blue,
  'closed' => Colors.grey,
  _ => AppTheme.accentAmber,
};

String _windowLabel(Election election) {
  if (election.status == 'voting_open') return 'Voting is currently open';
  if (election.status == 'nominations_open') {
    return 'Nominations are currently open';
  }
  return election.term?.isNotEmpty == true
      ? election.term!
      : 'View election details';
}
