import 'package:flutter/material.dart';
import 'package:student_activities/core/theme.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _filters = const ['All', 'Upcoming', 'Ongoing', 'Completed'];
  List<CalendarEvent> _events = [];
  String _filter = 'All';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await ApiClient.instance.get(
      '/calendar/events',
      queryParams: {'limit': 100},
    );
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _loading = false;
        _error = response.error ?? 'Unable to load calendar.';
      });
      return;
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    final events =
        (payload['data'] as List<dynamic>? ?? const [])
            .map(
              (event) => CalendarEvent.fromJson(
                Map<String, dynamic>.from(event as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  List<CalendarEvent> get _visibleEvents {
    if (_filter == 'All') return _events;
    return _events
        .where((event) => event.status.toLowerCase() == _filter.toLowerCase())
        .toList();
  }

  String _month(DateTime date) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][date.month - 1];

  String _time(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dayLabel(CalendarEvent event) =>
      '${event.startTime.day} ${_month(event.startTime)}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator(message: 'Loading calendar');
    if (_error != null) {
      return ErrorDisplay(message: _error!, onRetry: _loadEvents);
    }
    final events = _visibleEvents;
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<String>(
                segments: _filters
                    .map(
                      (filter) =>
                          ButtonSegment(value: filter, label: Text(filter)),
                    )
                    .toList(),
                selected: {_filter},
                showSelectedIcon: false,
                onSelectionChanged: (values) =>
                    setState(() => _filter = values.first),
              ),
            ),
          ),
          if (events.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.event_busy_outlined,
                title: 'No events in this view',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              sliver: SliverList.separated(
                itemCount: events.length,
                itemBuilder: (context, index) => _CalendarCard(
                  event: events[index],
                  dayLabel: _dayLabel(events[index]),
                  timeLabel:
                      '${_time(events[index].startTime)} - ${_time(events[index].endTime)}',
                  onOpen: () => _showEvent(events[index]),
                ),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
              ),
            ),
        ],
      ),
    );
  }

  void _showEvent(CalendarEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        minChildSize: 0.38,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
            StatusChip(
              label: event.status,
              color: AppTheme.statusColor(event.status),
            ),
            const SizedBox(height: 12),
            Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              text:
                  '${_dayLabel(event)} · ${_time(event.startTime)} - ${_time(event.endTime)}',
            ),
            if (event.organizerName.isNotEmpty)
              _DetailRow(
                icon: Icons.groups_outlined,
                text: event.organizerName,
              ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                event.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.55),
              ),
            ],
            if ((event.formLink?.isNotEmpty ?? false) ||
                (event.otherLink?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 24),
              if (event.formLink?.isNotEmpty ?? false)
                FilledButton.icon(
                  onPressed: () => _openUrl(event.formLink!),
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('Open registration'),
                ),
              if ((event.formLink?.isNotEmpty ?? false) &&
                  (event.otherLink?.isNotEmpty ?? false))
                const SizedBox(height: 10),
              if (event.otherLink?.isNotEmpty ?? false)
                OutlinedButton.icon(
                  onPressed: () => _openUrl(event.otherLink!),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open event link'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    final url = Uri.tryParse(value);
    if (url == null ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
    }
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.event,
    required this.dayLabel,
    required this.timeLabel,
    required this.onOpen,
  });

  final CalendarEvent event;
  final String dayLabel;
  final String timeLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppTheme.categoryColor(event.category);
    return AppCard(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${event.startTime.day}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  dayLabel.split(' ').last,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: categoryColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusChip(
                      label: event.status,
                      color: AppTheme.statusColor(event.status),
                    ),
                    StatusChip(label: event.category, color: categoryColor),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
