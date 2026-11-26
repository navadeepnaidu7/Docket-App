import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dev/dev_flags.dart';
import '../../../../core/dev/dev_flags_provider.dart';
import '../../../../core/dev/dummy_wallet_seed.dart';
import '../../../../core/dev/sky_preview.dart';
import '../../../../core/haptics/haptic_service.dart';
import '../../../tickets/application/pass_list_provider.dart';
import 'settings_rows.dart';

/// Debug / profile only — mock vs consumer data sources.
class DeveloperSettingsSection extends ConsumerWidget {
  const DeveloperSettingsSection({
    super.key,
    required this.surface,
    required this.borderColor,
    required this.isDark,
  });

  final Color surface;
  final Color borderColor;
  final bool isDark;

  Future<void> _editApiBaseUrl(BuildContext context, WidgetRef ref) async {
    final DevFlags flags = ref.read(devFlagsProvider);
    final TextEditingController controller = TextEditingController(
      text: flags.apiBaseUrl,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('API base URL'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://api.example.com',
              helperText: 'No trailing slash. Empty forces mock.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    HapticService.select();
    await ref.read(devFlagsProvider.notifier).setApiBaseUrl(result);
  }

  Future<void> _editDevAuthToken(BuildContext context, WidgetRef ref) async {
    final DevFlags flags = ref.read(devFlagsProvider);
    final TextEditingController controller = TextEditingController(
      text: flags.devAuthIdToken,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Dev auth token'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'dev-google-token',
              helperText: 'Sent as idToken to POST /v1/auth/google',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    HapticService.select();
    await ref.read(devFlagsProvider.notifier).setDevAuthIdToken(result);
  }

  Future<void> _selectFluidScheme(BuildContext context, WidgetRef ref) async {
    final DevFlags flags = ref.read(devFlagsProvider);
    final CardFluidScheme? selected = await showDialog<CardFluidScheme>(
      context: context,
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: const Text('Card Fluidic Gradient Scheme'),
          children: CardFluidScheme.values.map((CardFluidScheme scheme) {
            final bool isCurrent = scheme == flags.cardFluidScheme;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, scheme),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      isCurrent
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isCurrent ? const Color(0xFF5E5CE6) : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scheme.label,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
    if (selected != null) {
      HapticService.select();
      await ref.read(devFlagsProvider.notifier).setCardFluidScheme(selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DevFlags flags = ref.watch(devFlagsProvider);
    final String urlLabel = flags.apiBaseUrl.isEmpty
        ? 'Not set'
        : flags.apiBaseUrl;

    return SettingsSection(
      title: 'Developer',
      surface: surface,
      borderColor: borderColor,
      isDark: isDark,
      children: <Widget>[
        if (kDebugMode) ...[
          SettingsLinkRow(
            icon: Icons.auto_awesome_outlined,
            iconColor: const Color(0xFF5E5CE6),
            title: 'Weather glance preview',
            subtitle: ref.watch(weatherGlancePreviewProvider).label,
            onTap: () async {
              final preview = await showDialog<WeatherGlancePreview>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Weather glance preview'),
                  children: [
                    for (final preview in WeatherGlancePreview.values)
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, preview),
                        child: Text(preview.label),
                      ),
                  ],
                ),
              );
              if (preview != null && context.mounted) {
                ref.read(weatherGlancePreviewProvider.notifier).state = preview;
              }
            },
          ),
          const SettingsDivider(),
          SettingsLinkRow(
            icon: Icons.cloud_outlined,
            iconColor: const Color(0xFF2F6FED),
            title: 'Weather scene preview',
            subtitle: ref.watch(skyPreviewProvider).label,
            onTap: () async {
              final mode = await showDialog<SkyPreviewMode>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Weather scene preview'),
                  children: [
                    for (final mode in SkyPreviewMode.values)
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, mode),
                        child: Text(mode.label),
                      ),
                  ],
                ),
              );
              if (mode != null) {
                ref.read(skyPreviewProvider.notifier).state = mode;
              }
            },
          ),
          const SettingsDivider(),
        ],
        SettingsToggleRow(
          icon: Icons.science_rounded,
          iconColor: const Color(0xFFAF52DE),
          title: 'Use mock passes',
          subtitle: flags.isMockPassesActive
              ? 'Fixtures · demo train & movie cards'
              : 'Remote repository (consumer path)',
          value: flags.useMockPasses,
          onChanged: (bool v) async {
            HapticService.select();
            await ref.read(devFlagsProvider.notifier).setUseMockPasses(v);
          },
        ),
        const SettingsDivider(),
        SettingsToggleRow(
          icon: Icons.account_circle_rounded,
          iconColor: const Color(0xFF2F6FED),
          title: 'Mock signed in',
          subtitle: flags.mockSignedIn
              ? 'Card shows name · Account section on'
              : 'Card shows Google button · signed out',
          value: flags.mockSignedIn,
          onChanged: (bool v) async {
            HapticService.select();
            await ref.read(devFlagsProvider.notifier).setMockSignedIn(v);
          },
        ),
        const SettingsDivider(),
        SettingsLinkRow(
          icon: Icons.palette_rounded,
          iconColor: const Color(0xFF5E5CE6),
          title: 'Card fluid gradient scheme',
          subtitle: flags.cardFluidScheme.label,
          onTap: () => _selectFluidScheme(context, ref),
        ),
        const SettingsDivider(),
        SettingsLinkRow(
          icon: Icons.link_rounded,
          iconColor: const Color(0xFF2F6FED),
          title: 'API base URL',
          subtitle: urlLabel,
          onTap: () => _editApiBaseUrl(context, ref),
        ),
        const SettingsDivider(),
        SettingsLinkRow(
          icon: Icons.key_rounded,
          iconColor: const Color(0xFFAF52DE),
          title: 'Dev auth token',
          subtitle: flags.devAuthIdToken.isEmpty
              ? 'Not set · needed to add passes'
              : 'Set · used for /v1/auth/google',
          onTap: () => _editDevAuthToken(context, ref),
        ),
        const SettingsDivider(),
        SettingsLinkRow(
          icon: Icons.refresh_rounded,
          iconColor: const Color(0xFF30D158),
          title: 'Reload passes',
          onTap: () {
            HapticService.select();
            ref.read(passListProvider.notifier).refresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refreshing passes…'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const SettingsDivider(),
        SettingsLinkRow(
          icon: Icons.badge_outlined,
          iconColor: const Color(0xFF0A84FF),
          title: 'Load dummy IDs',
          subtitle: '5 passports + 5 Aadhaar/PAN variants',
          onTap: () {
            HapticService.select();
            final int added = DummyWalletSeed.load(ref);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  added == 0
                      ? 'Dummy cards already loaded'
                      : 'Loaded $added dummy cards',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        const SettingsDivider(),
        SettingsLinkRow(
          icon: Icons.playlist_remove_rounded,
          iconColor: const Color(0xFFFF453A),
          title: 'Remove dummy IDs',
          subtitle: 'Only cards whose id starts with dummy-',
          onTap: () {
            HapticService.select();
            final int removed = DummyWalletSeed.remove(ref);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  removed == 0
                      ? 'No dummy cards to remove'
                      : 'Removed $removed dummy cards',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        const SettingsDivider(),
        SettingsLinkRow(
          icon: Icons.restart_alt_rounded,
          iconColor: const Color(0xFF8E8E93),
          title: 'Reset dev flags',
          subtitle: 'Compile-time defaults',
          onTap: () async {
            HapticService.select();
            await ref
                .read(devFlagsProvider.notifier)
                .resetToCompileTimeDefaults();
          },
        ),
      ],
    );
  }
}
