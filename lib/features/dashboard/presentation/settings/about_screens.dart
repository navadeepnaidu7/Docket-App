import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'settings_rows.dart';

/// App version label — the part of `pubspec.yaml` `version:` before the `+`.
///
/// Duplicated rather than read at runtime because nothing here depends on
/// `package_info_plus`. `test/app_version_test.dart` fails if this drifts from
/// the pubspec, which is the only thing keeping the two honest.
const String kAppVersion = '0.1.0-alpha';

/// Credits shown under Settings → About (edit freely).
const String kDeveloperDisplayName = 'Navadeep Naidu';
const String kDeveloperEmail = 'hello@docket.app';
const String kDeveloperGithubUrl = 'https://github.com/navadeepnaidu7';
const String kDeveloperWebsiteUrl = 'https://navadeepnaidu.com';
const String kDeveloperBlogUrl = 'https://blog.navadeepnaidu.com';
const String kDeveloperXUrl = 'https://x.com/navadeep_naidu7';

Future<void> showWeatherCredits(BuildContext context) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Weather credits'),
        message: const Text(
          'Weather data by Open-Meteo, shared under CC BY 4.0. '
          'Docket rounds temperatures and illustrates weather conditions.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              openDeveloperLink(context, 'https://open-meteo.com/');
            },
            child: const Text('Open-Meteo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              openDeveloperLink(
                context,
                'https://creativecommons.org/licenses/by/4.0/',
              );
            },
            child: const Text('CC BY 4.0 licence'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Done'),
        ),
      ),
    );

Future<void> mailToDeveloper(BuildContext context) async {
  HapticService.tap();
  final Uri uri = Uri(
    scheme: 'mailto',
    path: kDeveloperEmail,
    queryParameters: <String, String>{'subject': 'Docket feedback'},
  );

  try {
    final bool launched = await launchUrl(uri);
    if (launched || !context.mounted) return;
  } catch (_) {
    // Fall through to clipboard fallback.
  }

  if (!context.mounted) return;
  await Clipboard.setData(const ClipboardData(text: kDeveloperEmail));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Email copied — no mail app available'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> openDeveloperLink(BuildContext context, String url) async {
  HapticService.tap();
  final Uri uri = Uri.parse(url);
  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !context.mounted) return;
  } catch (_) {
    // Fall through to clipboard fallback.
  }

  if (!context.mounted) return;
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Link copied — couldn’t open the browser'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class AboutDocketScreen extends StatelessWidget {
  const AboutDocketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);
    final Color surface = isDark
        ? const Color(0xFF16161A)
        : theme.colorScheme.surface;
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.06);
    final Color bg = isDark
        ? const Color(0xFF0A0A0D)
        : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'Docket',
                    style: AppFonts.ui(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $kAppVersion',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 20),
                  SettingsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'A local-first wallet for passports, IDs, and passes.\n\n'
                      'Built with Flutter and Riverpod.\n\n'
                      'ID card icon by haritselarif on the Noun Project (CC BY 3.0).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '© 2026 Docket',
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);
    final Color surface = isDark
        ? const Color(0xFF16161A)
        : theme.colorScheme.surface;
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.06);
    final Color bg = isDark
        ? const Color(0xFF0A0A0D)
        : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  Text(
                    'Developer',
                    style: AppFonts.ui(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kDeveloperDisplayName,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 20),
                  SettingsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Hi — I\'m $kDeveloperDisplayName, the developer behind Docket.\n\n'
                      'Docket is a personal project focused on a polished, '
                      'local-first digital wallet experience for documents and '
                      'passes. Feedback and ideas are always welcome.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: <Widget>[
                      SettingsLinkRow(
                        icon: Icons.language_rounded,
                        iconColor: const Color(0xFF2F6FED),
                        title: 'Website',
                        subtitle: 'navadeepnaidu.com',
                        onTap: () =>
                            openDeveloperLink(context, kDeveloperWebsiteUrl),
                      ),
                      const SettingsDivider(),
                      SettingsLinkRow(
                        icon: Icons.article_outlined,
                        iconColor: const Color(0xFFE07A2F),
                        title: 'Blog',
                        subtitle: 'blog.navadeepnaidu.com',
                        onTap: () =>
                            openDeveloperLink(context, kDeveloperBlogUrl),
                      ),
                      const SettingsDivider(),
                      SettingsLinkRow(
                        icon: Icons.code_rounded,
                        iconColor: const Color(0xFF6E7681),
                        title: 'GitHub',
                        subtitle: 'github.com/navadeepnaidu7',
                        onTap: () =>
                            openDeveloperLink(context, kDeveloperGithubUrl),
                      ),
                      const SettingsDivider(),
                      SettingsLinkRow(
                        icon: Icons.alternate_email_rounded,
                        iconColor: const Color(0xFF1DA1F2),
                        title: 'X',
                        subtitle: '@navadeep_naidu7',
                        onTap: () => openDeveloperLink(context, kDeveloperXUrl),
                      ),
                      const SettingsDivider(),
                      SettingsLinkRow(
                        icon: Icons.mail_outline_rounded,
                        iconColor: const Color(0xFF8E8E93),
                        title: 'Mail to developer',
                        subtitle: kDeveloperEmail,
                        onTap: () => mailToDeveloper(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
