import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:student_activities/core/app_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';
  static const projectUrl =
      'https://github.com/Student-Activities-IITM-BS/student-activities-app';
  static const developerGithubUrl = 'https://github.com/AbhiTheModder';
  static const privacyUrl = 'https://iitmbs.org/privacy';

  Future<void> _openLink(
    BuildContext context,
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    final opened = await launchUrl(uri, mode: mode);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Student Activities',
      applicationVersion: version,
      applicationLegalese: '© 2026 Abhi',
      applicationIcon: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Image.asset('assets/logo.webp', width: 52, height: 52),
      ),
    );
  }

  void _showAppDetails(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Student Activities',
      applicationVersion: version,
      applicationLegalese: '© 2026 Abhi',
      applicationIcon: Image.asset('assets/logo.webp', width: 48, height: 48),
      children: const [
        SizedBox(height: 12),
        Text('A native student community companion for IIT Madras BS.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUix = AppPreferences.instance.visualStyle == AppVisualStyle.uix;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        actions: [
          IconButton(
            tooltip: 'App details',
            onPressed: () => _showAppDetails(context),
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(isUix ? 12 : 16, 8, isUix ? 12 : 16, 32),
        children: [
          _AboutHero(version: version, isUix: isUix),
          const SizedBox(height: 28),
          _SectionHeading(
            eyebrow: 'THE PROJECT',
            title: 'A closer view of campus life.',
            isUix: isUix,
          ),
          const SizedBox(height: 10),
          Text(
            'Student Activities brings the people, places, conversations and opportunities of the IIT Madras BS community into one calm, native experience.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          _SignalStrip(isUix: isUix),
          const SizedBox(height: 28),
          _SectionHeading(
            eyebrow: 'THE PEOPLE BEHIND IT',
            title: 'A student-led SEC WebOps project, open to everyone.',
            isUix: isUix,
          ),
          const SizedBox(height: 12),
          _DeveloperPanel(
            isUix: isUix,
            onGithub: () => _openLink(context, Uri.parse(developerGithubUrl)),
          ),
          const SizedBox(height: 28),
          _SectionHeading(
            eyebrow: 'APP INFORMATION',
            title: 'Open and transparent.',
            isUix: isUix,
          ),
          const SizedBox(height: 12),
          _InfoActions(
            isUix: isUix,
            onLicenses: () => _showLicenses(context),
            onGithub: () => _openLink(context, Uri.parse(projectUrl)),
            onPrivacy: () => _openLink(
              context,
              Uri.parse(privacyUrl),
              mode: LaunchMode.inAppWebView,
            ),
          ),
          const SizedBox(height: 26),
          Center(
            child: Text(
              'Student Activities  ·  v$version  ·  © 2026 SEC WebOps',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.outline,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.version, required this.isUix});

  final String version;
  final bool isUix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(isUix ? 28 : 18);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: radius,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: SizedBox(
            height: 238,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SignalPatternPainter(
                      color: scheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'student-activities-logo',
                        child: Image.asset(
                          'assets/logo.webp',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.school_rounded,
                            size: 72,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student\nActivities',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 0.98,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'IIT Madras BS community',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  isUix ? 12 : 8,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  'VERSION $version',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.isUix,
  });

  final String eyebrow;
  final String title;
  final bool isUix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: isUix ? 1.4 : 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SignalStrip extends StatelessWidget {
  const _SignalStrip({required this.isUix});

  final bool isUix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(isUix ? 18 : 12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.hub_outlined, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Community first. Always moving forward.',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperPanel extends StatelessWidget {
  const _DeveloperPanel({required this.isUix, required this.onGithub});

  final bool isUix;
  final VoidCallback onGithub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(isUix ? 24 : 14);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
              ),
              alignment: Alignment.center,
              child: Text(
                'A',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abhi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SEC WebOps  ·  Sole developer',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Open GitHub profile',
              onPressed: onGithub,
              icon: const Icon(Icons.code_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoActions extends StatelessWidget {
  const _InfoActions({
    required this.isUix,
    required this.onLicenses,
    required this.onGithub,
    required this.onPrivacy,
  });

  final bool isUix;
  final VoidCallback onLicenses;
  final VoidCallback onGithub;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(isUix ? 24 : 14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _InfoAction(
            icon: Icons.auto_stories_outlined,
            title: 'Open source licenses',
            subtitle: 'Flutter and the packages that power this app',
            onTap: onLicenses,
          ),
          _InfoAction(
            icon: Icons.code_rounded,
            title: 'Project source',
            subtitle: 'View the work behind Student Activities',
            onTap: onGithub,
          ),
          _InfoAction(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy policy',
            subtitle: 'How the app handles your information',
            onTap: onPrivacy,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _InfoAction extends StatelessWidget {
  const _InfoAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: scheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 54,
            endIndent: 16,
            color: scheme.outlineVariant,
          ),
      ],
    );
  }
}

class _SignalPatternPainter extends CustomPainter {
  const _SignalPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = ui.Path()
      ..moveTo(size.width * 0.54, size.height * 0.18)
      ..lineTo(size.width * 0.74, size.height * 0.18)
      ..lineTo(size.width * 0.84, size.height * 0.34)
      ..lineTo(size.width * 0.98, size.height * 0.34);
    canvas.drawPath(path, paint);

    final secondPath = ui.Path()
      ..moveTo(size.width * 0.68, size.height * 0.98)
      ..lineTo(size.width * 0.68, size.height * 0.72)
      ..lineTo(size.width * 0.82, size.height * 0.58)
      ..lineTo(size.width, size.height * 0.58);
    canvas.drawPath(secondPath, paint);
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.34),
      3.5,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SignalPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
