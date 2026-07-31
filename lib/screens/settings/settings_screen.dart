import 'package:flutter/material.dart';
import 'package:student_activities/core/app_preferences.dart';
import 'package:student_activities/core/predictive_back.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/screens/settings/about_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) {
        final preferences = AppPreferences.instance;
        if (preferences.visualStyle == AppVisualStyle.uix) {
          return _UixSettingsContent(preferences: preferences);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            const SectionHeader(title: 'Appearance'),
            _SettingsGroup(
              children: [
                _SettingSegmented<ThemeMode>(
                  icon: Icons.brightness_6_outlined,
                  title: 'Color mode',
                  selected: preferences.themeMode,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  onChanged: preferences.setThemeMode,
                ),
                const Divider(height: 1),
                _SettingSegmented<AppVisualStyle>(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Interface',
                  selected: preferences.visualStyle,
                  segments: const [
                    ButtonSegment(
                      value: AppVisualStyle.material,
                      label: Text('Material'),
                    ),
                    ButtonSegment(
                      value: AppVisualStyle.uix,
                      label: Text('UIX'),
                    ),
                  ],
                  onChanged: preferences.setVisualStyle,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Navigation and motion'),
            _SettingsGroup(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.blur_on_outlined),
                  title: const Text('Blur top and bottom bars'),
                  value: preferences.chromeBlur,
                  onChanged: preferences.setChromeBlur,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.call_to_action_outlined),
                  title: const Text('Floating navigation'),
                  value: preferences.floatingNavigation,
                  onChanged: preferences.setFloatingNavigation,
                ),
                if (preferences.floatingNavigation) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const Icon(Icons.water_drop_outlined),
                    title: const Text('Liquid glass navigation'),
                    value: preferences.glassNavigation,
                    onChanged: preferences.setGlassNavigation,
                  ),
                ],
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.keyboard_backspace_outlined),
                  title: const Text('Predictive back'),
                  value: preferences.predictiveBack,
                  onChanged: preferences.setPredictiveBack,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Features'),
            _SettingsGroup(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.restaurant_outlined),
                  title: const Text('Mess'),
                  value: preferences.showMess,
                  onChanged: preferences.setShowMess,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'App'),
            _SettingsGroup(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('Student Activities · Version 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAbout(context),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPrivacy(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

void _openAbout(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const PredictiveBackScope(child: AboutScreen()),
    ),
  );
}

void _showPrivacy(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Authentication tokens are stored using the device’s encrypted credential storage. Your public profile visibility is controlled from Profile.',
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final opened = await launchUrl(
                      Uri.parse('https://iitmbs.org/privacy'),
                      mode: LaunchMode.inAppWebView,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open the privacy policy.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Privacy policy'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _SettingSegmented<T> extends StatelessWidget {
  const _SettingSegmented({
    required this.icon,
    required this.title,
    required this.selected,
    required this.segments,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T selected;
  final List<ButtonSegment<T>> segments;
  final Future<void> Function(T value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 16),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              segments: segments,
              selected: {selected},
              showSelectedIcon: false,
              onSelectionChanged: (values) => onChanged(values.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _UixSettingsContent extends StatelessWidget {
  const _UixSettingsContent({required this.preferences});

  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 112),
      children: [
        _UixSettingsGroup(
          children: [
            _UixChoicePreference<ThemeMode>(
              icon: Icons.brightness_6_outlined,
              title: 'Color mode',
              value: preferences.themeMode,
              choices: const [
                _UixChoice(ThemeMode.system, 'System'),
                _UixChoice(ThemeMode.light, 'Light'),
                _UixChoice(ThemeMode.dark, 'Dark'),
              ],
              onChanged: preferences.setThemeMode,
            ),
            _UixChoicePreference<AppVisualStyle>(
              icon: Icons.dashboard_customize_outlined,
              title: 'Interface',
              value: preferences.visualStyle,
              choices: const [
                _UixChoice(AppVisualStyle.uix, 'UIX'),
                _UixChoice(AppVisualStyle.material, 'Material'),
              ],
              onChanged: preferences.setVisualStyle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _UixSettingsGroup(
          children: [
            _UixSwitchPreference(
              icon: Icons.blur_on_outlined,
              title: 'Blur top and bottom bars',
              value: preferences.chromeBlur,
              onChanged: preferences.setChromeBlur,
            ),
            _UixSwitchPreference(
              icon: Icons.call_to_action_outlined,
              title: 'Floating navigation',
              value: preferences.floatingNavigation,
              onChanged: preferences.setFloatingNavigation,
            ),
            if (preferences.floatingNavigation)
              _UixSwitchPreference(
                icon: Icons.water_drop_outlined,
                title: 'Liquid glass navigation',
                value: preferences.glassNavigation,
                onChanged: preferences.setGlassNavigation,
              ),
            _UixSwitchPreference(
              icon: Icons.keyboard_backspace_outlined,
              title: 'Predictive back',
              value: preferences.predictiveBack,
              onChanged: preferences.setPredictiveBack,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _UixSettingsGroup(
          children: [
            _UixSwitchPreference(
              icon: Icons.restaurant_outlined,
              title: 'Mess',
              value: preferences.showMess,
              onChanged: preferences.setShowMess,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _UixSettingsGroup(
          children: [
            _UixPreferenceRow(
              icon: Icons.info_outline,
              title: 'About',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openAbout(context),
            ),
            _UixPreferenceRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPrivacy(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _UixSettingsGroup extends StatelessWidget {
  const _UixSettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _UixPreferenceRow extends StatelessWidget {
  const _UixPreferenceRow({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: scheme.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(color: scheme.onSurfaceVariant),
                      child: trailing!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UixSwitchPreference extends StatelessWidget {
  const _UixSwitchPreference({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _UixPreferenceRow(
      icon: icon,
      title: title,
      onTap: () => onChanged(!value),
      trailing: _UixSwitch(value: value, onChanged: onChanged),
    );
  }
}

class _UixSwitch extends StatelessWidget {
  const _UixSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value
                ? scheme.primary
                : scheme.onSurfaceVariant.withValues(
                    alpha: isDark ? 0.34 : 0.24,
                  ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: value ? Colors.white : scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const SizedBox(width: 26, height: 26),
            ),
          ),
        ),
      ),
    );
  }
}

class _UixChoice<T> {
  const _UixChoice(this.value, this.label);

  final T value;
  final String label;
}

class _UixChoicePreference<T> extends StatefulWidget {
  const _UixChoicePreference({
    required this.icon,
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<_UixChoice<T>> choices;
  final Future<void> Function(T value) onChanged;

  @override
  State<_UixChoicePreference<T>> createState() =>
      _UixChoicePreferenceState<T>();
}

class _UixChoicePreferenceState<T> extends State<_UixChoicePreference<T>> {
  final _rowKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final selected = widget.choices.firstWhere(
      (choice) => choice.value == widget.value,
    );
    return _UixPreferenceRow(
      key: _rowKey,
      icon: widget.icon,
      title: widget.title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(selected.label),
          const SizedBox(width: 2),
          const Icon(Icons.unfold_more_rounded, size: 20),
        ],
      ),
      onTap: _showChoiceMenu,
    );
  }

  Future<void> _showChoiceMenu() async {
    final rowContext = _rowKey.currentContext;
    if (rowContext == null) return;
    final rowBox = rowContext.findRenderObject()! as RenderBox;
    final overlayBox =
        Navigator.of(rowContext).overlay!.context.findRenderObject()!
            as RenderBox;
    final topLeft = rowBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx + rowBox.size.width * 0.54,
        topLeft.dy + 4,
        rowBox.size.width * 0.42,
        rowBox.size.height - 8,
      ),
      Offset.zero & overlayBox.size,
    );
    final next = await showMenu<T>(
      context: rowContext,
      position: position,
      items: [
        for (final choice in widget.choices)
          PopupMenuItem<T>(
            value: choice.value,
            height: 52,
            child: Row(
              children: [
                Expanded(child: Text(choice.label)),
                if (choice.value == widget.value)
                  Icon(
                    Icons.check_rounded,
                    color: Theme.of(rowContext).colorScheme.primary,
                  ),
              ],
            ),
          ),
      ],
    );
    if (next != null && next != widget.value) await widget.onChanged(next);
  }
}
