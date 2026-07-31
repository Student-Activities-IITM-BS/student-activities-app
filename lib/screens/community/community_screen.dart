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

  @override
  Widget build(BuildContext context) {
    const events = [
      ('August', 'Paradox in Saavan', 'Online'),
      ('January', 'Paradox in Margazhi', 'Online'),
      ('Main event', 'Paradox', 'On campus'),
    ];
    const domains = [
      (Icons.music_note_outlined, 'Cultural'),
      (Icons.memory_outlined, 'Technical'),
      (Icons.sports_outlined, 'Sports'),
      (Icons.public_outlined, 'Outreach'),
      (Icons.local_cafe_outlined, 'Hospitality'),
      (Icons.camera_alt_outlined, 'Media'),
      (Icons.settings_suggest_outlined, 'Operations'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
      children: [
        Text('Paradox', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(
          'The flagship student festival of the IITM BS Programme.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Competitions, performances, and collaborative experiences bring students together across regions.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.25,
          children: const [
            _FestivalStat(value: '5,000+', label: 'Attendees'),
            _FestivalStat(value: '45+', label: 'Competitions'),
            _FestivalStat(value: '12', label: 'Committees'),
          ],
        ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Festival calendar'),
        ...events.map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(event.$2),
                subtitle: Text(event.$1),
                trailing: StatusChip(
                  label: event.$3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'Domains'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: domains
              .map(
                (domain) => AppCard(
                  child: Row(
                    children: [
                      Icon(domain.$1),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          domain.$2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _FestivalStat extends StatelessWidget {
  const _FestivalStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SecOverview extends StatelessWidget {
  const _SecOverview();
  @override
  Widget build(BuildContext context) {
    const departments = [
      (
        'Communications',
        'Student announcements, social media, and outreach.',
        Icons.campaign_outlined,
      ),
      (
        'Elections and ethics',
        'Elections, grievances, conduct, and student support.',
        Icons.how_to_vote_outlined,
      ),
      (
        'Finance',
        'SAF, budgets, reimbursements, and sponsorships.',
        Icons.account_balance_outlined,
      ),
      (
        'Web operations',
        'Student services, web systems, and multimedia.',
        Icons.language_outlined,
      ),
      (
        'Technical',
        'Technical events, initiatives, and execution.',
        Icons.memory_outlined,
      ),
      (
        'Cultural',
        'Creative initiatives and cultural engagement.',
        Icons.palette_outlined,
      ),
      (
        'Sports',
        'Sports events, participation, and talent development.',
        Icons.sports_outlined,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 112),
      children: [
        Text(
          'Student Executive Committee',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'The SEC coordinates student initiatives and serves as a bridge between the student body and university administration.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Departments'),
        ...departments.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.$3),
                title: Text(item.$1),
                subtitle: Text(item.$2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
