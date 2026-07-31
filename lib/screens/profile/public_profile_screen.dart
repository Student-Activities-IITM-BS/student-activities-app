import 'package:flutter/material.dart';
import 'package:student_activities/core/predictive_back.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.email,
    this.fallbackName,
  });

  final String email;
  final String? fallbackName;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _profile;
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
    final response = await ApiClient.instance.get(
      '/profile/public/${Uri.encodeComponent(widget.email)}',
    );
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _loading = false;
        _error = response.error ?? 'This profile is not available.';
      });
      return;
    }
    setState(() {
      _profile = Map<String, dynamic>.from(response.data as Map);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return PredictiveBackScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _loading
            ? const LoadingIndicator(message: 'Loading profile')
            : _error != null
            ? ErrorDisplay(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: profile?['type'] == 'seat'
                    ? _SeatProfile(data: profile!)
                    : _PersonalProfile(
                        data: profile!,
                        fallbackName: widget.fallbackName,
                      ),
              ),
      ),
    );
  }
}

class _PersonalProfile extends StatelessWidget {
  const _PersonalProfile({required this.data, this.fallbackName});

  final Map<String, dynamic> data;
  final String? fallbackName;

  @override
  Widget build(BuildContext context) {
    final rawProfile = data['profile'];
    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : const <String, dynamic>{};
    final name = (profile['display_name']?.toString().trim().isNotEmpty == true)
        ? profile['display_name'].toString().trim()
        : fallbackName ??
              profile['email']?.toString().split('@').first ??
              'Student';
    final email = profile['email']?.toString().trim() ?? '';
    final responsibilities = _maps(data['responsibilities']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  _initials(name),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (email.isNotEmpty)
                IconButton(
                  tooltip: 'Email $name',
                  icon: const Icon(Icons.email_outlined),
                  onPressed: () => _email(context, email),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Responsibilities'),
        if (responsibilities.isEmpty)
          const AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.work_outline),
              title: Text('No responsibilities listed'),
            ),
          )
        else
          ...responsibilities.map(
            (responsibility) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(child: _ResponsibilityCard(data: responsibility)),
            ),
          ),
      ],
    );
  }
}

class _SeatProfile extends StatelessWidget {
  const _SeatProfile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final role = _role(data['role']?.toString() ?? 'Position');
    final organization = data['organization']?.toString().trim() ?? '';
    final email = data['seat_email']?.toString().trim() ?? '';
    final holders = _maps(data['holders']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                child: const Icon(Icons.badge_outlined, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role, style: Theme.of(context).textTheme.titleLarge),
                    if (organization.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        organization,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (email.isNotEmpty)
                IconButton(
                  tooltip: 'Email $role',
                  icon: const Icon(Icons.email_outlined),
                  onPressed: () => _email(context, email),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Holders'),
        if (holders.isEmpty)
          const AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.people_outline),
              title: Text('No holder history is available'),
            ),
          )
        else
          ...holders.map(
            (holder) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(child: _HolderCard(data: holder)),
            ),
          ),
      ],
    );
  }
}

class _ResponsibilityCard extends StatelessWidget {
  const _ResponsibilityCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = data['position_name']?.toString() ?? 'Responsibility';
    final organization = data['organization']?.toString().trim() ?? '';
    final description = data['description']?.toString().trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (organization.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(organization, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
        _DateRange(
          start: data['start_date']?.toString(),
          end: data['end_date']?.toString(),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(description),
        ],
      ],
    );
  }
}

class _HolderCard extends StatelessWidget {
  const _HolderCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['display_name']?.toString().trim().isNotEmpty == true
        ? data['display_name'].toString().trim()
        : 'Student';
    final email = data['user_email']?.toString().trim() ?? '';
    final description = data['description']?.toString().trim() ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(child: Text(_initials(name))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleSmall),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(email, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              _DateRange(
                start: data['start_date']?.toString(),
                end: data['end_date']?.toString(),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(description),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DateRange extends StatelessWidget {
  const _DateRange({this.start, this.end});

  final String? start;
  final String? end;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.calendar_today_outlined, size: 14),
      const SizedBox(width: 6),
      Text(
        '${_monthYear(start)} - ${end == null || end!.isEmpty ? 'Present' : _monthYear(end)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const [];

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0])
    .join()
    .toUpperCase();

String _role(String value) => value
    .split(RegExp('[-_]'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _monthYear(String? value) {
  final date = value == null ? null : DateTime.tryParse(value);
  if (date == null) return 'Unknown';
  const months = [
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
  ];
  return '${months[date.month - 1]} ${date.year}';
}

Future<void> _email(BuildContext context, String email) async {
  final opened = await launchUrl(Uri(scheme: 'mailto', path: email));
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open email.')));
  }
}
