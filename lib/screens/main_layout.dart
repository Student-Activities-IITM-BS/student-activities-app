import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:student_activities/core/app_preferences.dart';
import 'package:student_activities/core/predictive_back.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/screens/budget/budget_screen.dart';
import 'package:student_activities/screens/calendar/calendar_screen.dart';
import 'package:student_activities/screens/community/community_screen.dart';
import 'package:student_activities/screens/dashboard/dashboard_screen.dart';
import 'package:student_activities/screens/elections/elections_screen.dart';
import 'package:student_activities/screens/feed/feed_screen.dart';
import 'package:student_activities/screens/mess/mess_screen.dart';
import 'package:student_activities/screens/profile/profile_screen.dart';
import 'package:student_activities/screens/profile/public_profile_screen.dart';
import 'package:student_activities/screens/recruitment/recruitment_screen.dart';
import 'package:student_activities/screens/search/search_screen.dart';
import 'package:student_activities/screens/settings/settings_screen.dart';
import 'package:student_activities/screens/voices/live_chat_screen.dart';
import 'package:student_activities/screens/voices/voices_screen.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:student_activities/services/app_link_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.appLinks});

  final ValueListenable<Uri?>? appLinks;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static const _defaultRecruitmentSlug = 'webops-mm-2026';

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _builtScreens = <String, Widget>{};
  final _visited = <String>{'home'};
  String _current = 'home';
  bool _drawerOpen = false;
  late final ValueListenable<Uri?> _appLinks;
  String? _handledLink;

  static const _routes = <_AppRoute>[
    _AppRoute('home', 'Home', Icons.home_outlined, Icons.home),
    _AppRoute('updates', 'Updates', Icons.campaign_outlined, Icons.campaign),
    _AppRoute(
      'calendar',
      'Calendar',
      Icons.calendar_month_outlined,
      Icons.calendar_month,
    ),
    _AppRoute('voices', 'Voices', Icons.forum_outlined, Icons.forum),
    _AppRoute('community', 'Community', Icons.groups_outlined, Icons.groups),
    _AppRoute(
      'search',
      'Assistant',
      Icons.auto_awesome_outlined,
      Icons.auto_awesome,
    ),
    _AppRoute('mess', 'Mess', Icons.restaurant_outlined, Icons.restaurant),
    _AppRoute(
      'budget',
      'Budget',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
    ),
    _AppRoute(
      'elections',
      'Elections',
      Icons.how_to_vote_outlined,
      Icons.how_to_vote,
    ),
    _AppRoute(
      'recruitment',
      'Recruitment',
      Icons.assignment_outlined,
      Icons.assignment,
    ),
    _AppRoute('profile', 'Profile', Icons.person_outline, Icons.person),
    _AppRoute('settings', 'Settings', Icons.settings_outlined, Icons.settings),
  ];

  List<_AppRoute> get _visibleRoutes => _routes
      .where(
        (route) =>
            route.id != 'search' &&
            (route.id != 'mess' || AppPreferences.instance.showMess),
      )
      .toList(growable: false);

  _AppRoute get _route {
    return _routes.firstWhere(
      (route) => route.id == _current,
      orElse: () => _routes.first,
    );
  }

  @override
  void initState() {
    super.initState();
    AppPreferences.instance.addListener(_onPreferencesChanged);
    _appLinks = widget.appLinks ?? AppLinkService.instance.latestLink;
    _appLinks.addListener(_onAppLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAppLink());
  }

  @override
  void dispose() {
    AppPreferences.instance.removeListener(_onPreferencesChanged);
    _appLinks.removeListener(_onAppLink);
    super.dispose();
  }

  void _onPreferencesChanged() {
    if (!AppPreferences.instance.showMess && _current == 'mess') {
      _go('home');
    }
  }

  void _go(String id) {
    if (!_routes.any((route) => route.id == id)) return;
    if (id == 'mess' && !AppPreferences.instance.showMess) return;
    _dismissKeyboard();
    setState(() {
      _current = id;
      _visited.add(id);
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  void _onAppLink() {
    final uri = _appLinks.value;
    if (uri == null || uri.toString() == _handledLink || !_isAppLink(uri)) {
      return;
    }
    _handledLink = uri.toString();
    _openAppLink(uri);
  }

  bool _isAppLink(Uri uri) =>
      uri.scheme == 'iitmbs' ||
      (uri.scheme == 'https' &&
          (uri.host == 'iitmbs.org' || uri.host == 'www.iitmbs.org'));

  List<String> _linkSegments(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList();
    if (uri.scheme == 'iitmbs' && uri.host.isNotEmpty) {
      return [uri.host, ...segments];
    }
    return segments;
  }

  Future<void> _openAppLink(Uri uri) async {
    final segments = _linkSegments(uri);
    if (segments.isEmpty) {
      _go('home');
      return;
    }

    final root = segments.first.toLowerCase();
    final rest = root == 'dashboard' ? segments.skip(1).toList() : segments;
    if (rest.isEmpty) {
      _go('home');
      return;
    }

    switch (rest.first.toLowerCase()) {
      case 'privacy':
        return;
      case 'recruitment':
        final slug = rest.length > 1 ? rest[1] : null;
        if (slug == null || slug.isEmpty || slug == 'admin') {
          _go('recruitment');
        } else {
          _pushPage(RecruitmentScreen(slug: slug));
        }
        return;
      case 'community':
        await _openCommunityLink(rest.skip(1).toList());
        return;
      case 'house':
      case 'houses':
        await _openCommunityLink(['house', ...rest.skip(1)]);
        return;
      case 'society':
      case 'societies':
        await _openCommunityLink(['society', ...rest.skip(1)]);
        return;
      case 'voices':
        if (rest.length > 1 && rest[1].toLowerCase() == 'chat') {
          _pushPage(const LiveChatScreen());
        } else {
          _go('voices');
        }
        return;
      case 'updates':
      case 'update':
        _go('updates');
        return;
      case 'calendar':
      case 'events':
        _go('calendar');
        return;
      case 'mess':
        _go('mess');
        return;
      case 'budget':
        _go('budget');
        return;
      case 'elections':
      case 'election':
        _go('elections');
        return;
      case 'assistant':
      case 'search':
        _go('search');
        return;
      case 'settings':
        _go('settings');
        return;
      case 'profile':
        if (rest.length > 1 && rest[1].contains('@')) {
          _pushPage(PublicProfileScreen(email: rest[1]));
        } else {
          _go('profile');
        }
        return;
      default:
        _go('home');
    }
  }

  Future<void> _openCommunityLink(List<String> parts) async {
    if (parts.isEmpty) {
      _go('community');
      return;
    }
    final section = parts.first.toLowerCase();
    final tab = switch (section) {
      'house' || 'houses' => 0,
      'society' || 'societies' => 1,
      'paradox' => 2,
      'sec' => 3,
      _ => 0,
    };
    if (parts.length == 1 || tab > 1) {
      if (tab == 0 && parts.length == 1) {
        _pushPage(CommunityScreen(initialTab: tab));
      } else if (tab > 0) {
        _pushPage(CommunityScreen(initialTab: tab));
      } else {
        _go('community');
      }
      return;
    }

    final endpoint = tab == 0 ? '/public/houses' : '/public/societies';
    final response = await ApiClient.instance.get(endpoint);
    if (!mounted) return;
    final payload = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    final groups = (payload['data'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => CommunityGroup.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final target = parts[1];
    CommunityGroup? group;
    for (final item in groups) {
      final slug = item.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      if (item.id == target ||
          item.groupId == target ||
          item.societyId == target ||
          slug == target) {
        group = item;
        break;
      }
    }
    if (group != null) {
      _pushPage(CommunityDetailScreen(group: group));
    } else {
      _pushPage(CommunityScreen(initialTab: tab));
    }
  }

  void _pushPage(Widget page) {
    if (!mounted) return;
    _dismissKeyboard();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PredictiveBackScope(child: page)));
  }

  Widget _screenFor(String id) => _builtScreens.putIfAbsent(
    id,
    () => switch (id) {
      'home' => DashboardScreen(onNavigate: _go),
      'updates' => const FeedScreen(),
      'calendar' => const CalendarScreen(),
      'voices' => const VoicesScreen(),
      'community' => const CommunityScreen(),
      'search' => const SearchScreen(),
      'mess' => const MessScreen(),
      'budget' => const BudgetScreen(),
      'elections' => const ElectionsScreen(),
      'recruitment' => const RecruitmentScreen(slug: _defaultRecruitmentSlug),
      'profile' => const ProfileScreen(),
      'settings' => const SettingsScreen(),
      _ => const SizedBox.shrink(),
    },
  );

  Widget _body() => Stack(
    children: _visited
        .map(
          (id) => Offstage(
            offstage: id != _current,
            child: Focus(
              canRequestFocus: id == _current,
              descendantsAreFocusable: id == _current,
              child: TickerMode(enabled: id == _current, child: _screenFor(id)),
            ),
          ),
        )
        .toList(),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) return _wideLayout(context);
          return _phoneLayout(context);
        },
      ),
    );
  }

  Widget _phoneLayout(BuildContext context) {
    final preferences = AppPreferences.instance;
    final route = _route;
    final primaryRoutes = _visibleRoutes.take(4).toList(growable: false);
    final primaryIndex = primaryRoutes.indexWhere(
      (item) => item.id == _current,
    );
    final selectedIndex = _current == 'profile'
        ? primaryRoutes.length
        : primaryIndex >= 0
        ? primaryIndex
        : 0;
    return PopScope(
      canPop: preferences.predictiveBack && _current == 'home' && !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_drawerOpen) {
          _scaffoldKey.currentState?.closeDrawer();
        } else if (_current != 'home') {
          _go('home');
        } else if (!preferences.predictiveBack) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBody:
            preferences.floatingNavigation && preferences.glassNavigation,
        onDrawerChanged: (open) {
          _dismissKeyboard();
          setState(() => _drawerOpen = open);
        },
        appBar: _appBar(
          context,
          route,
          leading: preferences.floatingNavigation
              ? null
              : IconButton(
                  tooltip: 'Open navigation',
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    _dismissKeyboard();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
        ),
        drawer: preferences.floatingNavigation
            ? null
            : Drawer(child: _drawer(context)),
        body: _body(),
        bottomNavigationBar: _bottomNavigation(
          context,
          routes: primaryRoutes,
          selectedIndex: _drawerOpen ? 0 : selectedIndex,
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context, _AppRoute route, {Widget? leading}) {
    final preferences = AppPreferences.instance;
    final blurChrome = preferences.chromeBlur;
    final scheme = Theme.of(context).colorScheme;
    final chromeSurface = preferences.visualStyle == AppVisualStyle.uix
        ? scheme.surface
        : scheme.surfaceContainer;
    return AppBar(
      title: Text(route.label),
      leading: leading,
      backgroundColor: blurChrome ? Colors.transparent : chromeSurface,
      flexibleSpace: blurChrome
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: ColoredBox(color: chromeSurface.withValues(alpha: 0.84)),
              ),
            )
          : null,
      actions: [
        IconButton(
          tooltip: 'Academic assistant',
          icon: const Icon(Icons.auto_awesome_outlined),
          onPressed: () => _go('search'),
        ),
      ],
    );
  }

  Widget _bottomNavigation(
    BuildContext context, {
    required List<_AppRoute> routes,
    required int selectedIndex,
  }) {
    final preferences = AppPreferences.instance;
    final useFloating = preferences.floatingNavigation;
    final useGlass = useFloating && preferences.glassNavigation;
    final scheme = Theme.of(context).colorScheme;
    final profileRoute = _routes.firstWhere((route) => route.id == 'profile');
    final profileIndex = routes.length;
    final navigation = NavigationBar(
      backgroundColor: Colors.transparent,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == profileIndex) {
          _go(profileRoute.id);
        } else {
          _go(routes[index].id);
        }
      },
      destinations: [
        for (final item in routes)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: item.label,
          ),
        NavigationDestination(
          icon: Icon(profileRoute.icon),
          selectedIcon: Icon(profileRoute.activeIcon),
          label: profileRoute.label,
        ),
      ],
    );
    if (!useFloating) {
      final content = ColoredBox(
        color: preferences.chromeBlur
            ? Colors.transparent
            : scheme.surfaceContainer,
        child: navigation,
      );
      return SafeArea(
        top: false,
        child: preferences.chromeBlur
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: ColoredBox(
                    color: scheme.surfaceContainer.withValues(alpha: 0.84),
                    child: navigation,
                  ),
                ),
              )
            : content,
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -180) {
              _showFloatingMenu();
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _LiquidNavigationDock(
              glass: useGlass,
              topBorderOnly: true,
              selectedIndex: selectedIndex,
              items: [
                for (final route in routes)
                  _LiquidNavigationItem(
                    label: route.label,
                    icon: route.icon,
                    selectedIcon: route.activeIcon,
                  ),
                _LiquidNavigationItem(
                  label: profileRoute.label,
                  icon: profileRoute.icon,
                  selectedIcon: profileRoute.activeIcon,
                ),
              ],
              onSelected: (index) {
                if (index == profileIndex) {
                  _go(profileRoute.id);
                } else {
                  _go(routes[index].id);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFloatingMenu() async {
    if (!mounted || !AppPreferences.instance.floatingNavigation) return;
    _dismissKeyboard();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _FloatingNavigationSheet(
        routes: _visibleRoutes,
        current: _current,
        onSelected: (id) {
          Navigator.of(sheetContext).pop();
          _go(id);
        },
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    final routes = _visibleRoutes;
    final routeIndex = routes.indexWhere((route) => route.id == _current);
    final selectedIndex = routeIndex >= 0 ? routeIndex : 0;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _go(routes[index].id),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.school_outlined),
              ),
              destinations: routes
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(appBar: _appBar(context, _route), body: _body()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawer(BuildContext context) {
    final routes = _visibleRoutes;
    final selectedIndex = routes.indexWhere((route) => route.id == _current);
    return SafeArea(
      child: NavigationDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          Navigator.pop(context);
          _go(routes[index].id);
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 24, 16, 12),
            child: Text(
              'Student Activities',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ),
          for (final item in routes)
            NavigationDrawerDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: Text(item.label),
            ),
        ],
      ),
    );
  }
}

class _FloatingNavigationSheet extends StatelessWidget {
  const _FloatingNavigationSheet({
    required this.routes,
    required this.current,
    required this.onSelected,
  });

  final List<_AppRoute> routes;
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.42,
      minChildSize: 0.25,
      maxChildSize: 0.84,
      builder: (context, controller) => Material(
        color: scheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: Column(
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Navigation',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 92,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  final route = routes[index];
                  final selected = route.id == current;
                  return Material(
                    color: selected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => onSelected(route.id),
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected ? route.activeIcon : route.icon,
                            color: selected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            route.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidNavigationDock extends StatefulWidget {
  const _LiquidNavigationDock({
    required this.glass,
    required this.topBorderOnly,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final bool glass;
  final bool topBorderOnly;
  final int selectedIndex;
  final List<_LiquidNavigationItem> items;
  final ValueChanged<int> onSelected;

  @override
  State<_LiquidNavigationDock> createState() => _LiquidNavigationDockState();
}

class _LiquidNavigationDockState extends State<_LiquidNavigationDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectionController;
  double _fromIndex = 0;
  double _toIndex = 0;
  double? _dragIndex;
  int? _lastPreviewedIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex.toDouble();
    _toIndex = _fromIndex;
    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _LiquidNavigationDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex && _dragIndex == null) {
      _fromIndex = _visualIndex;
      _toIndex = widget.selectedIndex.toDouble();
      _selectionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  double get _visualIndex {
    if (_dragIndex case final double dragIndex) return dragIndex;
    final progress = Curves.easeOutCubic.transform(_selectionController.value);
    return lerpDouble(_fromIndex, _toIndex, progress) ?? _toIndex;
  }

  void _select(int index, {bool feedback = true}) {
    if (index != _toIndex.round()) {
      _fromIndex = _visualIndex;
      _toIndex = index.toDouble();
      _dragIndex = null;
      _selectionController.forward(from: 0);
    }
    if (feedback && index != widget.selectedIndex) {
      HapticFeedback.selectionClick();
    }
    widget.onSelected(index);
  }

  void _beginDrag() {
    _selectionController.stop();
    _lastPreviewedIndex = widget.selectedIndex;
    setState(() => _dragIndex = _visualIndex);
  }

  void _updateDrag(DragUpdateDetails details, double width) {
    final preview =
        (details.localPosition.dx / width * widget.items.length - 0.5).clamp(
          0.0,
          (widget.items.length - 1).toDouble(),
        );
    final nearest = preview.round();
    if (nearest != _lastPreviewedIndex) {
      _lastPreviewedIndex = nearest;
      HapticFeedback.selectionClick();
    }
    setState(() => _dragIndex = preview);
  }

  void _endDrag() {
    final preview = _dragIndex ?? widget.selectedIndex.toDouble();
    final target = preview.round();
    setState(() {
      _fromIndex = preview;
      _toIndex = target.toDouble();
      _dragIndex = null;
    });
    _selectionController.forward(from: 0);
    if (target != widget.selectedIndex) {
      widget.onSelected(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUix = AppPreferences.instance.visualStyle == AppVisualStyle.uix;
    final radius = BorderRadius.circular(isUix ? 26 : 20);
    final background = widget.glass
        ? scheme.surfaceContainer.withValues(alpha: isDark ? 0.68 : 0.78)
        : scheme.surfaceContainer;
    final borderColor = widget.glass
        ? scheme.onSurface.withValues(alpha: isDark ? 0.18 : 0.12)
        : scheme.outlineVariant.withValues(alpha: 0.62);

    final dock = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: widget.topBorderOnly
            ? Border(top: BorderSide(color: borderColor))
            : Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.1),
            blurRadius: widget.glass ? 20 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / widget.items.length;
          final visualIndex = _visualIndex;
          final travel = _dragIndex == null
              ? (_toIndex - _fromIndex).abs()
              : (visualIndex - widget.selectedIndex).abs();
          final motion = _dragIndex == null
              ? math.sin(math.pi * _selectionController.value)
              : 1.0;
          final widthFactor =
              0.82 + (0.13 * motion * travel.clamp(0, 1).toDouble());
          final indicatorWidth = itemWidth * widthFactor;
          final left = ((visualIndex + 0.5) * itemWidth - indicatorWidth / 2)
              .clamp(5.0, constraints.maxWidth - indicatorWidth - 5.0)
              .toDouble();
          final activeIndex = visualIndex.round();

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _beginDrag(),
            onHorizontalDragUpdate: (details) =>
                _updateDrag(details, constraints.maxWidth),
            onHorizontalDragEnd: (_) => _endDrag(),
            onHorizontalDragCancel: _endDrag,
            child: SizedBox(
              height: isUix ? 72 : 76,
              child: Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 7,
                    bottom: 7,
                    width: indicatorWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.glass
                            ? scheme.primary.withValues(
                                alpha: isDark ? 0.3 : 0.2,
                              )
                            : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(isUix ? 22 : 18),
                        border: widget.glass
                            ? Border.all(
                                color: scheme.onSurface.withValues(alpha: 0.16),
                              )
                            : null,
                        boxShadow: widget.glass
                            ? [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < widget.items.length; index++)
                        Expanded(
                          child: _LiquidNavigationDockItem(
                            item: widget.items[index],
                            selected: index == activeIndex,
                            color: index == activeIndex
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                            onTap: () => _select(index),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: widget.glass
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: dock,
              )
            : dock,
      ),
    );
  }
}

class _LiquidNavigationDockItem extends StatelessWidget {
  const _LiquidNavigationDockItem({
    required this.item,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final _LiquidNavigationItem item;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                    child: Text(item.label, maxLines: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidNavigationItem {
  const _LiquidNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _AppRoute {
  const _AppRoute(this.id, this.label, this.icon, this.activeIcon);
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
