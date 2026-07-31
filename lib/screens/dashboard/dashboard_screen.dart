import 'package:flutter/material.dart';
import 'package:student_activities/core/app_preferences.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:student_activities/services/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<CalendarEvent> _events = [];
  List<EventUpdate> _updates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final responses = await Future.wait([
      ApiClient.instance.get('/calendar/events', queryParams: {'limit': 5}),
      ApiClient.instance.get('/events-updates', queryParams: {'limit': 3}),
    ]);
    if (!mounted) return;
    List<dynamic> list(ApiResponse response) {
      if (!response.success || response.data is! Map) return const [];
      return Map<String, dynamic>.from(response.data as Map)['data']
              as List<dynamic>? ??
          const [];
    }

    final now = DateTime.now();
    setState(() {
      _events = list(responses[0])
          .map(
            (item) =>
                CalendarEvent.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((event) => event.endTime.isAfter(now))
          .toList();
      _updates = list(responses[1])
          .map(
            (item) =>
                EventUpdate.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      _loading = false;
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.instance.userName.split(' ').first;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 112),
        children: [
          Text(_greeting, style: Theme.of(context).textTheme.titleMedium),
          Text(name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          _QuickActions(onNavigate: widget.onNavigate),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Coming up',
            actionLabel: 'Calendar',
            action: () => widget.onNavigate('calendar'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_events.isEmpty)
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('No upcoming events'),
              ),
            )
          else
            ..._events
                .take(3)
                .map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => widget.onNavigate('calendar'),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${event.startTime.day}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _date(event.startTime),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          const SectionHeader(
            title: 'Latest updates',
            actionLabel: 'Updates',
            action: null,
          ),
          if (!_loading && _updates.isEmpty)
            const AppCard(child: Text('No activity updates yet.'))
          else
            ..._updates
                .take(3)
                .map(
                  (update) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => widget.onNavigate('updates'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            update.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            update.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  String _date(DateTime date) =>
      '${date.day}/${date.month} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) {
        final visibleActions = [
          ('updates', 'Updates', Icons.campaign_outlined),
          ('calendar', 'Calendar', Icons.calendar_month_outlined),
          ('search', 'Assistant', Icons.auto_awesome_outlined),
          ('community', 'Community', Icons.groups_outlined),
          ('voices', 'Voices', Icons.forum_outlined),
          if (AppPreferences.instance.showMess)
            ('mess', 'Mess', Icons.restaurant_outlined),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620 ? 4 : 3;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: visibleActions.map((action) {
                return SizedBox(
                  width: width,
                  height: width / 1.18,
                  child: AppCard(
                    onTap: () => onNavigate(action.$1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          action.$3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action.$2,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
