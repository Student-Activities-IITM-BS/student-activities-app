import 'package:flutter/material.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/screens/auth/login_screen.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:student_activities/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  StudentProfile? _student;
  List<StudentSociety> _societies = [];
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
    final responses = await Future.wait([
      ApiClient.instance.get('/profile'),
      ApiClient.instance.get('/student/profile'),
      ApiClient.instance.get('/student/societies'),
    ]);
    if (!mounted) return;
    final profileResponse = responses[0];
    final studentResponse = responses[1];
    final societiesResponse = responses[2];
    final profileData = profileResponse.data is Map
        ? Map<String, dynamic>.from(profileResponse.data as Map)
        : null;
    final studentData = studentResponse.data is Map
        ? Map<String, dynamic>.from(studentResponse.data as Map)
        : null;
    final societyData = societiesResponse.data is Map
        ? Map<String, dynamic>.from(societiesResponse.data as Map)
        : null;
    setState(() {
      if (profileData != null) _profile = UserProfile.fromJson(profileData);
      if (studentData != null) {
        final rawStudent = studentData['student'] is Map
            ? Map<String, dynamic>.from(studentData['student'] as Map)
            : studentData;
        _student = StudentProfile.fromJson(rawStudent);
      }
      if (societyData != null) {
        _societies = (societyData['societies'] as List<dynamic>? ?? const [])
            .map(
              (item) => StudentSociety.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      _loading = false;
      if (_student == null && _profile == null) {
        _error =
            studentResponse.error ??
            profileResponse.error ??
            'Unable to load your profile.';
      }
    });
  }

  String get _name => _student?.fullName.isNotEmpty == true
      ? _student!.fullName
      : _profile?.displayName.isNotEmpty == true
      ? _profile!.displayName
      : AuthService.instance.userName;

  String get _email => _student?.email.isNotEmpty == true
      ? _student!.email
      : AuthService.instance.userEmail;

  Future<void> _open(String? value) async {
    final url = value == null ? null : Uri.tryParse(value);
    if (url == null ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
    }
  }

  Future<void> _editLinks() async {
    final student = _student;
    if (student == null) return;
    final github = TextEditingController(text: student.github ?? '');
    final linkedin = TextEditingController(text: student.linkedin ?? '');
    final leetcode = TextEditingController(text: student.leetcode ?? '');
    var isPublic = student.isPublic;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final scheme = Theme.of(context).colorScheme;

          Widget linkField({
            required TextEditingController controller,
            required String label,
            required IconData icon,
          }) {
            return TextField(
              controller: controller,
              enabled: !saving,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: label,
                hintText: 'https://',
                prefixIcon: Icon(icon),
              ),
            );
          }

          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Edit profile',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(
                        'Add links classmates can use to find your work.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'LINKS',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                      ),
                      const SizedBox(height: 10),
                      linkField(
                        controller: github,
                        label: 'GitHub URL',
                        icon: Icons.code,
                      ),
                      const SizedBox(height: 10),
                      linkField(
                        controller: linkedin,
                        label: 'LinkedIn URL',
                        icon: Icons.business_center_outlined,
                      ),
                      const SizedBox(height: 10),
                      linkField(
                        controller: leetcode,
                        label: 'LeetCode URL',
                        icon: Icons.terminal_outlined,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'VISIBILITY',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          secondary: Icon(
                            isPublic
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          title: const Text('Public student profile'),
                          subtitle: const Text(
                            'Let authenticated students discover your profile.',
                          ),
                          value: isPublic,
                          onChanged: saving
                              ? null
                              : (value) =>
                                    setDialogState(() => isPublic = value),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    setDialogState(() => saving = true);
                                    final response = await ApiClient.instance
                                        .patch(
                                          '/student/links',
                                          body: {
                                            'github': github.text.trim(),
                                            'linkedin': linkedin.text.trim(),
                                            'leetcode': leetcode.text.trim(),
                                            'is_public': isPublic,
                                          },
                                        );
                                    if (!context.mounted) return;
                                    if (!response.success) {
                                      setDialogState(() => saving = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            response.error ??
                                                'Could not save profile links.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(context);
                                    await _load();
                                  },
                            icon: saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Save changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    github.dispose();
    linkedin.dispose();
    leetcode.dispose();
  }

  Future<void> _manageSocieties() async {
    final allResponse = await ApiClient.instance.get(
      '/public/filters/societies',
    );
    if (!mounted) return;
    if (!allResponse.success || allResponse.data is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allResponse.error ?? 'Could not load societies.'),
        ),
      );
      return;
    }
    final data = Map<String, dynamic>.from(allResponse.data as Map);
    final all = (data['data'] as List<dynamic>? ?? const [])
        .map(
          (item) => SocietyFilterItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final selected = _societies.map((society) => society.societyId).toSet();
    var query = '';
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final shown = all
              .where(
                (society) =>
                    society.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: const Text('Your societies'),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => setDialogState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search societies',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, index) {
                        final society = shown[index];
                        final checked = selected.contains(society.id);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(society.name),
                          subtitle: society.societyType == null
                              ? null
                              : Text(society.societyType!),
                          value: checked,
                          onChanged: saving
                              ? null
                              : (value) => setDialogState(() {
                                  if (value == true) {
                                    selected.add(society.id);
                                  } else {
                                    selected.remove(society.id);
                                  }
                                }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        final response = await ApiClient.instance.patch(
                          '/student/societies',
                          body: {'society_ids': selected.toList()},
                        );
                        if (!context.mounted) return;
                        if (!response.success) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                response.error ?? 'Could not update societies.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        await _load();
                      },
                child: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access student services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator(message: 'Loading profile');
    if (_error != null) return ErrorDisplay(message: _error!, onRetry: _load);
    final student = _student;
    final user = AuthService.instance;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: user.userPicture == null
                      ? null
                      : NetworkImage(user.userPicture!),
                  child: user.userPicture == null
                      ? Text(
                          _name.isEmpty
                              ? '?'
                              : _name.characters.first.toUpperCase(),
                          style: Theme.of(context).textTheme.headlineSmall,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      StatusChip(
                        label: student?.isPublic == true
                            ? 'Public profile'
                            : 'Private profile',
                        color: student?.isPublic == true
                            ? Colors.green
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (student != null) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Student profile'),
            AppCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.home_outlined,
                    label: 'House',
                    value: student.house?.name ?? 'Not selected',
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Region',
                    value: student.region?.name ?? 'Not selected',
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit links and visibility'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editLinks,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.interests_outlined),
                    title: const Text('Manage societies'),
                    subtitle: Text(
                      _societies.isEmpty
                          ? 'No societies selected'
                          : '${_societies.length} selected',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _manageSocieties,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Links'),
            AppCard(
              child: Column(
                children: [
                  _LinkTile(
                    icon: Icons.code,
                    label: 'GitHub',
                    url: student.github,
                    onOpen: _open,
                  ),
                  const Divider(),
                  _LinkTile(
                    icon: Icons.business_center_outlined,
                    label: 'LinkedIn',
                    url: student.linkedin,
                    onOpen: _open,
                  ),
                  const Divider(),
                  _LinkTile(
                    icon: Icons.terminal_outlined,
                    label: 'LeetCode',
                    url: student.leetcode,
                    onOpen: _open,
                  ),
                ],
              ),
            ),
            if (_societies.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader(title: 'Societies'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _societies
                    .map((society) => Chip(label: Text(society.name)))
                    .toList(),
              ),
            ],
          ],
          if (_profile?.responsibilities.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Responsibilities'),
            ..._profile!.responsibilities.map(
              (responsibility) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: _Responsibility(responsibility: responsibility),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      Text(value, style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.url,
    required this.onOpen,
  });
  final IconData icon;
  final String label;
  final String? url;
  final Future<void> Function(String?) onOpen;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(url?.isNotEmpty == true ? url! : 'Not connected'),
    trailing: const Icon(Icons.open_in_new),
    enabled: url?.isNotEmpty == true,
    onTap: url?.isNotEmpty == true ? () => onOpen(url) : null,
  );
}

class _Responsibility extends StatelessWidget {
  const _Responsibility({required this.responsibility});
  final Responsibility responsibility;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        responsibility.positionName,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      if (responsibility.organization?.isNotEmpty == true) ...[
        const SizedBox(height: 3),
        Text(responsibility.organization!),
      ],
      const SizedBox(height: 7),
      Text(
        '${responsibility.startDate.split('T').first} - ${responsibility.endDate?.split('T').first ?? 'Present'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (responsibility.description?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        Text(responsibility.description!),
      ],
    ],
  );
}
