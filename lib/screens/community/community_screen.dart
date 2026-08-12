import 'package:flutter/material.dart';
import 'package:student_activities/core/predictive_back.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/screens/profile/public_profile_screen.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<CommunityGroup> _houses = [];
  List<CommunityGroup> _societies = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final responses = await Future.wait([
      ApiClient.instance.get('/public/houses'),
      ApiClient.instance.get('/public/societies'),
    ]);
    if (!mounted) return;
    List<CommunityGroup> read(ApiResponse response) {
      if (!response.success || response.data is! Map) return [];
      final payload = Map<String, dynamic>.from(response.data as Map);
      return (payload['data'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                CommunityGroup.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }

    final houses = read(responses[0]);
    final societies = read(responses[1]);
    setState(() {
      _houses = houses;
      _societies = societies;
      _loading = false;
      if (houses.isEmpty && societies.isEmpty) {
        _error =
            responses[0].error ??
            responses[1].error ??
            'Unable to load communities.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator(message: 'Loading communities');
    if (_error != null) return ErrorDisplay(message: _error!, onRetry: _load);
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Houses'),
              Tab(text: 'Societies'),
              Tab(text: 'Paradox'),
              Tab(text: 'SEC'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _GroupList(groups: _houses, type: 'House'),
              _GroupList(groups: _societies, type: 'Society'),
              const _ParadoxOverview(),
              const _SecOverview(),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups, required this.type});
  final List<CommunityGroup> groups;
  final String type;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.groups_outlined,
        title: 'No $type communities available',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      itemCount: groups.length,
      itemBuilder: (_, index) {
        final group = groups[index];
        return AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CommunityDetailScreen(group: group),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                child: Icon(
                  type == 'House'
                      ? Icons.home_work_outlined
                      : Icons.interests_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (group.societyType?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        group.societyType!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
    );
  }
}

class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({super.key, required this.group});
  final CommunityGroup group;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  Map<String, dynamic>? _data;
  late final PageController _galleryController;
  bool _loading = true;
  String? _error;
  int _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();
    _load();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final isHouse = widget.group.type == 'HOUSE';
    final pageIdentifier = isHouse
        ? widget.group.id
        : (widget.group.groupId ?? widget.group.id);
    final response = await ApiClient.instance.get(
      isHouse
          ? '/house-pages/$pageIdentifier'
          : '/public/society-pages/$pageIdentifier',
    );
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _loading = false;
        _error = response.error ?? 'This community page is not available yet.';
      });
      return;
    }
    final responseData = Map<String, dynamic>.from(response.data as Map);
    setState(() {
      _data = responseData['data'] is Map
          ? Map<String, dynamic>.from(responseData['data'] as Map)
          : responseData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = _data;
    final isHouse = widget.group.type == 'HOUSE';
    final name = _text(page, [
      'society_name',
      'societyName',
      'name',
    ], widget.group.name);
    final headline = _text(
      page,
      isHouse ? ['powerful_line', 'powerfulLine'] : ['one_liner', 'oneLiner'],
    );
    final values = _strings(page, ['core_values', 'coreValues']);
    final leaders = _leaders(page);
    final coordinators = _coordinators(page);
    final regions = _regionNames(page);
    final activities = _activities(page);
    final gallery = _strings(page, ['gallery_images', 'galleryImages']);
    final links = _links(page, isHouse: isHouse);
    final logoUrl = _imageUrl(page);
    final slogan = _text(page, ['motto', 'tagline']);
    return PredictiveBackScope(
      child: Scaffold(
        appBar: AppBar(title: Text(name)),
        body: _loading
            ? const LoadingIndicator(message: 'Loading community')
            : _error != null
            ? ErrorDisplay(message: _error!, onRetry: _load)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Row(
                    children: [
                      if (logoUrl != null)
                        Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      if (logoUrl != null) const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (slogan.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                slogan,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isHouse && _text(page, ['domain']).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    StatusChip(
                      label: _text(page, ['domain']),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                  if (!isHouse && _text(page, ['year_established']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Established ${_text(page, ['year_established'])}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (headline.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      headline,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                  if (_text(page, ['description']).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _text(page, ['description']),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ],
                  if (_text(page, ['vision']).isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _DetailSection(
                      title: 'Vision',
                      child: Text(_text(page, ['vision'])),
                    ),
                  ],
                  if (_text(page, ['mission']).isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _DetailSection(
                      title: 'Mission',
                      child: Text(_text(page, ['mission'])),
                    ),
                  ],
                  if (_text(page, [
                    'field_of_interest',
                    'fieldOfInterest',
                  ]).isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _DetailSection(
                      title: 'Field of interest',
                      child: Text(
                        _text(page, ['field_of_interest', 'fieldOfInterest']),
                      ),
                    ),
                  ],
                  if (values.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const SectionHeader(title: 'Core values'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: values
                          .map((item) => Chip(label: Text(item)))
                          .toList(),
                    ),
                  ],
                  if (activities.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const SectionHeader(title: 'Core activities'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: activities
                          .map(
                            (activity) => Chip(
                              avatar: Icon(activity.icon, size: 16),
                              label: Text(activity.label),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (regions.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    SectionHeader(title: 'Regions mapped to $name'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: regions
                          .map((region) => Chip(label: Text(region)))
                          .toList(),
                    ),
                  ],
                  if (leaders.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const SectionHeader(title: 'Leadership'),
                    ...leaders.map(
                      (leader) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PersonCard(
                          person: leader,
                          onOpenLink: _openExternalLink,
                          onOpenProfile: _openPublicProfile,
                        ),
                      ),
                    ),
                  ],
                  if (coordinators.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionHeader(title: 'Coordinators'),
                    ...coordinators.map(
                      (coordinator) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PersonCard(
                          person: coordinator,
                          onOpenLink: _openExternalLink,
                          onOpenProfile: _openPublicProfile,
                        ),
                      ),
                    ),
                  ],
                  if (gallery.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const SectionHeader(title: 'Gallery'),
                    _Gallery(
                      images: gallery,
                      controller: _galleryController,
                      index: _galleryIndex,
                      onChanged: (index) =>
                          setState(() => _galleryIndex = index),
                      onPrevious: () => _selectGallery(gallery.length, -1),
                      onNext: () => _selectGallery(gallery.length, 1),
                    ),
                  ],
                  if (_text(page, ['join_link', 'joinLink']).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _openExternalLink(
                        _text(page, ['join_link', 'joinLink']),
                      ),
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text('Join $name'),
                    ),
                  ],
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Links'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: links
                          .map(
                            (link) => OutlinedButton.icon(
                              onPressed: () => _openExternalLink(link.url),
                              icon: Icon(link.icon, size: 18),
                              label: Text(link.label),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  String _text(
    Map<String, dynamic>? page,
    List<String> keys, [
    String fallback = '',
  ]) {
    if (page == null) return fallback;
    for (final key in keys) {
      final value = page[key]?.toString().trim();
      if (value?.isNotEmpty == true) return value!;
    }
    return fallback;
  }

  String? _imageUrl(Map<String, dynamic>? page) {
    final value = _text(page, ['logo_url', 'logoUrl', 'photo_url', 'photo']);
    return value.isEmpty ? null : value;
  }

  List<String> _strings(Map<String, dynamic>? page, List<String> keys) {
    if (page == null) return [];
    for (final key in keys) {
      final value = page[key];
      if (value is List) {
        return value
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  List<_CommunityPerson> _leaders(Map<String, dynamic>? page) {
    if (page == null) return const [];
    final leadership = page['leadership'] ?? page['team_members'];
    final people = leadership is List
        ? leadership
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    for (final item in [
      ('secretary', 'Secretary'),
      ('deputy_secretary', 'Deputy Secretary'),
      ('web_tech_lead', 'Web / Tech Lead'),
    ]) {
      final raw = page[item.$1];
      if (raw is Map) {
        people.add({...Map<String, dynamic>.from(raw), 'role': item.$2});
      }
    }
    return people
        .map(_CommunityPerson.tryParse)
        .whereType<_CommunityPerson>()
        .toList(growable: false);
  }

  List<_CommunityPerson> _coordinators(Map<String, dynamic>? page) {
    final raw = page?['coordinators'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => _CommunityPerson.tryParse(Map<String, dynamic>.from(item)),
        )
        .whereType<_CommunityPerson>()
        .toList(growable: false);
  }

  List<String> _regionNames(Map<String, dynamic>? page) {
    final raw = page?['regions'];
    if (raw is! List) return const [];
    return raw
        .map(
          (item) => item is Map
              ? (item['region_name'] ?? item['name'])?.toString()
              : item?.toString(),
        )
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<_CommunityActivity> _activities(Map<String, dynamic>? page) {
    final raw = page?['activities'];
    if (raw is! Map) return const [];
    const options = [
      ('research', 'Research and study circles', Icons.science_outlined),
      ('projects', 'Projects and technical work', Icons.handyman_outlined),
      ('workshops', 'Workshops', Icons.menu_book_outlined),
      (
        'hackathons',
        'Hackathons and competitions',
        Icons.emoji_events_outlined,
      ),
      ('discussions', 'Discussions and meetups', Icons.forum_outlined),
      ('collaborations', 'Collaborations', Icons.handshake_outlined),
    ];
    return options
        .where((option) => raw[option.$1] == true)
        .map((option) => _CommunityActivity(label: option.$2, icon: option.$3))
        .toList(growable: false);
  }

  List<_CommunityLink> _links(
    Map<String, dynamic>? page, {
    required bool isHouse,
  }) {
    final otherLinks = page?['other_links'];
    String value(String key, [String? fallback]) =>
        _text(page, fallback == null ? [key] : [key, fallback]);
    final candidates = [
      (
        value(isHouse ? 'instagram_url' : 'instagram'),
        'Instagram',
        Icons.camera_alt_outlined,
      ),
      (
        value(isHouse ? 'youtube_url' : 'youtube'),
        'YouTube',
        Icons.play_circle_outline,
      ),
      (value('linkedin_page'), 'LinkedIn', Icons.work_outline),
      (value('website', 'website_url'), 'Website', Icons.language_outlined),
      (
        value(isHouse ? 'gallery_url' : 'gallery_drive_link'),
        'Gallery',
        Icons.photo_library_outlined,
      ),
      (value('core_team_photos_link'), 'Team photos', Icons.groups_outlined),
      (
        otherLinks is Map ? otherLinks['website_link']?.toString() ?? '' : '',
        'Website',
        Icons.language_outlined,
      ),
    ];
    final seen = <String>{};
    return candidates
        .where((candidate) => _isExternalUrl(candidate.$1))
        .where((candidate) => seen.add(candidate.$1))
        .map(
          (candidate) => _CommunityLink(
            url: candidate.$1,
            label: candidate.$2,
            icon: candidate.$3,
          ),
        )
        .toList(growable: false);
  }

  void _selectGallery(int count, int delta) {
    final target = (_galleryIndex + delta) % count;
    _galleryController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isExternalUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  bool _isSafeLink(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' ||
            uri.scheme == 'http' ||
            uri.scheme == 'mailto');
  }

  Future<void> _openExternalLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !_isSafeLink(value)) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  void _openPublicProfile(_CommunityPerson person) {
    if (person.email.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PublicProfileScreen(email: person.email, fallbackName: person.name),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        child: child,
      ),
    ],
  );
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.onOpenLink,
    required this.onOpenProfile,
  });

  final _CommunityPerson person;
  final ValueChanged<String> onOpenLink;
  final ValueChanged<_CommunityPerson> onOpenProfile;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: person.email.isEmpty ? null : () => onOpenProfile(person),
    child: Row(
      children: [
        CircleAvatar(
          foregroundImage: person.photoUrl == null
              ? null
              : NetworkImage(person.photoUrl!),
          child: const Icon(Icons.person_outline),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.name, style: Theme.of(context).textTheme.titleSmall),
              if (person.role.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(person.role, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (person.bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  person.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (person.email.isNotEmpty)
          IconButton(
            tooltip: 'Email ${person.name}',
            icon: const Icon(Icons.email_outlined),
            onPressed: () => onOpenLink('mailto:${person.email}'),
          ),
        if (person.linkedin.isNotEmpty)
          IconButton(
            tooltip: 'Open ${person.name} on LinkedIn',
            icon: const Icon(Icons.work_outline),
            onPressed: () => onOpenLink(person.linkedin),
          ),
      ],
    ),
  );
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.images,
    required this.controller,
    required this.index,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final List<String> images;
  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: images.length,
                onPageChanged: onChanged,
                itemBuilder: (_, itemIndex) => Image.network(
                  images[itemIndex],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              if (images.length > 1) ...[
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: 'Previous image',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: onPrevious,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: 'Next image',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: onNext,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      if (images.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (itemIndex) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: itemIndex == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: itemIndex == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _CommunityPerson {
  const _CommunityPerson({
    required this.name,
    required this.role,
    required this.bio,
    required this.email,
    required this.linkedin,
    required this.photoUrl,
  });

  final String name;
  final String role;
  final String bio;
  final String email;
  final String linkedin;
  final String? photoUrl;

  static _CommunityPerson? tryParse(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['fullName'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final photo = (data['photo_url'] ?? data['photo'] ?? '').toString().trim();
    return _CommunityPerson(
      name: name,
      role: (data['role'] ?? data['position'] ?? '').toString().trim(),
      bio: data['bio']?.toString().trim() ?? '',
      email: data['email']?.toString().trim() ?? '',
      linkedin: (data['linkedin'] ?? data['linkedIn'] ?? '').toString().trim(),
      photoUrl: photo.isEmpty ? null : photo,
    );
  }
}

class _CommunityActivity {
  const _CommunityActivity({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _CommunityLink {
  const _CommunityLink({
    required this.url,
    required this.label,
    required this.icon,
  });

  final String url;
  final String label;
  final IconData icon;
}

class _ParadoxOverview extends StatelessWidget {
  const _ParadoxOverview();

  static const _calendar = [
    ('Saavan', 'September term break', 'Online events and activities'),
    ('Margazhi', 'December term break', 'Online events and activities'),
    (
      'Paradox',
      'Final week of May',
      'A four-day festival at the IIT Madras campus',
    ),
  ];
  static const _departments = [
    'Technicals',
    'Culturals',
    'Sports',
    'Sponsorship',
    'Multimedia Productions',
    'Student Relations',
    'Safety & Security',
    'WebOps',
    'Finance and Operations',
    'Hospitality Relations',
  ];
  static const _eligibility = [
    'A preferred minimum CGPA of 7.',
    'No malpractice record under the IITM BS Code of Conduct.',
    'No other Position of Responsibility in the Degree while serving with Paradox.',
    'Age 25 or below, unless the Steering Committee approves an exception.',
    'Availability for campus participation when required, with at least two months notice.',
    'A commitment of 21 hours a week to Paradox work, meetings, training, and fest activities.',
  ];
  static const _workingStandards = [
    'Complete assigned work on time and update the task tracker regularly.',
    'Complete post-fest work after Saavan, Margazhi, and Paradox.',
    'Use official communication channels for official matters.',
    'Keep the reporting structure in place and use the escalation process when needed.',
  ];
  static const _teamLadder = [
    'Steering Committee',
    'Secretaries',
    'Department Head and Deputy Department Head',
    'Super Coordinator',
    'Coordinator',
    'Volunteer',
  ];
  static const _eventRoles = [
    'Event Coordinator',
    'Event Deputy Coordinator',
    'Event Volunteer',
  ];
  static const _charterUrl =
      'https://docs.google.com/document/d/1RzkXftE0x07uMX1QUxm9D0sGfa0uoIson2SCKlHxy1c/edit?tab=t.0#heading=h.on5izq22fb74';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
      children: [
        Text(
          'IIT Madras BS student festival',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        Text('Paradox', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          '"Three fests. One spirit."',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Paradox is the annual student-run festival for IIT Madras BS Degree students. Its on-campus edition runs for four days and brings together technical, sports, and cultural events.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Festival calendar'),
        ..._calendar.map(
          (fest) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.calendar_month_outlined,
                  color: scheme.primary,
                ),
                title: Text(fest.$1),
                subtitle: Text('${fest.$2}\n${fest.$3}'),
                isThreeLine: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CommunityPanel(
          title: 'The team behind Paradox',
          icon: Icons.groups_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paradox is organised by students through its Steering Committee, Secretaries, department teams, and event teams.',
              ),
              const SizedBox(height: 16),
              ..._teamLadder.indexed.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          (item.$1 + 1).toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Text(item.$2)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              const Text(
                'Event teams',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${_eventRoles.join(', ')}. Event Coordinators and Deputy Coordinators lead planning and delivery for individual events.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CommunityPanel(
          title: 'Departments',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Teams work across the following departments.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _departments
                    .map((item) => Chip(label: Text(item)))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CommunityPanel(
          title: 'Joining the organising team',
          icon: Icons.verified_user_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._eligibility.map(
                (item) => _BulletText(text: item, icon: Icons.shield_outlined),
              ),
              const Divider(height: 24),
              const Text(
                'Promotion requires a completed term in the current role and is decided through application screening and interviews. Applying does not guarantee selection.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CommunityPanel(
          title: 'Working in Paradox',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._workingStandards.map((item) => _BulletText(text: item)),
              const Divider(height: 24),
              const Text(
                'Event proposals',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Paradox accepts event proposals from individual students. House and Society members may submit on behalf of their House or Society, and should state this in the proposal.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CommunityPanel(
          title: 'Grievances and event support',
          icon: Icons.mail_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'For an event-related concern, contact the relevant department core. If a concern is not resolved through the event team or department core within 48 hours, use the standard escalation path below.',
              ),
              const SizedBox(height: 14),
              ...[
                ('Technicals', 'technicals@iitmparadox.org'),
                ('Sports', 'sports@iitmparadox.org'),
                ('Culturals', 'culturals@iitmparadox.org'),
              ].map(
                (contact) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.email_outlined, color: scheme.primary),
                  title: Text(contact.$1),
                  subtitle: Text(contact.$2),
                  onTap: () => _openCommunityUrl('mailto:${contact.$2}'),
                ),
              ),
              const Divider(height: 18),
              const Text(
                'Escalation path',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('1. Grievance team - grievances@iitmparadox.org'),
              const Text('2. Secretaries - secretaries@iitmparadox.org'),
              const Text(
                '3. Steering Committee - steering-committee@iitmparadox.org',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CommunityPanel(
          title: 'Full Paradox Charter',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Read the full Charter for departmental SOPs, code-of-conduct provisions, repercussions, and the amendment process.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openCommunityUrl(_charterUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Charter'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecOverview extends StatelessWidget {
  const _SecOverview();

  static const _secretaries = [
    (
      'Student Relations Secretary',
      'SRS',
      '7.5',
      [
        'Supports operational queries, including meeting recording and streaming.',
        'Manages official Student Activities communication channels and social-media handles.',
        'Issues bulletins and newsletters, and manages the Student Activity Calendar and announcements Google Group.',
      ],
    ),
    (
      'Finance Secretary',
      'FS',
      '7.5',
      [
        'Convenes the Finance Committee constituted by Student Affairs.',
        'Processes Student Activities Fund applications and maintains ledgers.',
        'Reviews budgets, reimbursements, MOUs, sponsorship agreements, and fund workflows.',
      ],
    ),
    (
      'Sports Secretary',
      'SpS',
      '7.5',
      [
        'Convenes the Sports Committee and routes sports fund proposals through it.',
        'Oversees sports activities and supports the sports talent pool.',
      ],
    ),
    (
      'Technical Secretary',
      'TS',
      '7.5',
      [
        'Convenes the Technicals Committee and routes technical fund proposals through it.',
        'Oversees technical activities and supports the technical talent pool.',
      ],
    ),
    (
      'Cultural Secretary',
      'CS',
      '7.5',
      [
        'Convenes the Cultural Committee and routes cultural fund proposals through it.',
        'Oversees cultural activities and supports the cultural talent pool.',
      ],
    ),
    (
      'Election & Ethics Secretary',
      'EES',
      '7.5',
      [
        'Coordinates with the Student Election Commission and Grievance Redressal Committee.',
        'Facilitates General Student Body Elections.',
        'Maintains awareness of conduct and interaction guidelines.',
      ],
    ),
    (
      'Web Operations & Multimedia Secretary',
      'WOMS',
      '7.5',
      [
        'Maintains the official student website and election portal.',
        'Maintains a unified student portal for services and announcements.',
        'Creates and publishes multimedia content.',
      ],
    ),
  ];
  static const _eligibility = [
    'Be enrolled in the Programme when appointed.',
    'Have a CGPA of at least 7.5, unless the position has a higher threshold.',
    'Have no active Registration-Keep-Alive status.',
    'Have no academic or non-academic misconduct conviction.',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
      children: [
        Text(
          'Student leadership and operations',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Student Executive Committee',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          'The Student Executive Committee (SEC) supports the Student Affairs team in maintaining student-community infrastructure and coordinating the Upper House Council, Lower House Council, Societies, and the Paradox team. It facilitates student initiatives across the Programme.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 24),
        const _CommitteeStat(value: '08', label: 'Committees'),
        const SizedBox(height: 26),
        _CommunityPanel(
          title: 'Eligibility and tenure',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _eligibility
                .map(
                  (item) =>
                      _BulletText(text: item, icon: Icons.check_circle_outline),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Voting secretaries'),
        Text(
          'Responsibilities by office',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'These seven secretary offices coordinate student activities. Current office-holder details are shared through official Student Activities channels.',
        ),
        const SizedBox(height: 14),
        ..._secretaries.map(
          (position) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SecretaryCard(
              title: position.$1,
              designation: position.$2,
              minimumCgpa: position.$3,
              responsibilities: position.$4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _CommunityPanel(
          title: 'Student Activities Fund',
          icon: Icons.account_balance_wallet_outlined,
          child: const Text(
            'The Finance Secretary administers the SAF in accordance with Institute financial rules. A disbursement requires a written proposal endorsed by the relevant Domain Committee, majority approval of the SEC, and a Student Affairs countersignature where mandated.',
          ),
        ),
        const SizedBox(height: 12),
        _CommunityPanel(
          title: 'Conduct and authority',
          icon: Icons.balance_outlined,
          child: const Text(
            'SEC members must act with integrity, inclusivity, and respect for Institute regulations. Student Affairs may remove or replace a member for misconduct, academic ineligibility, a breach of conduct standards, or failure to carry out the role.',
          ),
        ),
      ],
    );
  }
}

class _CommunityPanel extends StatelessWidget {
  const _CommunityPanel({required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
          ],
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DefaultTextStyle.merge(
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(height: 1.45),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.text, this.icon = Icons.circle});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _CommitteeStat extends StatelessWidget {
  const _CommitteeStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _SecretaryCard extends StatelessWidget {
  const _SecretaryCard({
    required this.title,
    required this.designation,
    required this.minimumCgpa,
    required this.responsibilities,
  });

  final String title;
  final String designation;
  final String minimumCgpa;
  final List<String> responsibilities;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: designation, color: scheme.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum CGPA: $minimumCgpa',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (responsibilities.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...responsibilities.map((item) => _BulletText(text: item)),
          ],
        ],
      ),
    );
  }
}

Future<void> _openCommunityUrl(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
