import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/dev/dev_flags.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../shared/widgets/apple_sheet.dart';
import '../../../shared/widgets/document_date_picker.dart';
import '../../../shared/widgets/safe_base64_image.dart';
import '../../ids/application/id_list_provider.dart';
import '../../passport/application/passport_list_provider.dart';
import '../application/account_profile_provider.dart';
import '../application/auth_session_provider.dart';
import '../application/profile_avatar_shape_provider.dart';
import '../domain/account_profile.dart';
import 'widgets/membership_mesh.dart';

/// Signed-in account home: photo, identity, and optional personal details.
class ManageAccountScreen extends ConsumerWidget {
  const ManageAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final AuthSession session = ref.watch(authSessionProvider);
    final AccountProfile profile = ref.watch(accountProfileProvider);
    final ProfileAvatarShape shape = ref.watch(profileAvatarShapeProvider);

    final Color bg =
        isDark ? const Color(0xFF0A0A0D) : theme.scaffoldBackgroundColor;
    final Color ink =
        isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final Color muted =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280);
    final Color surface =
        isDark ? const Color(0xFF16161A) : theme.colorScheme.surface;
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.06);

    final String name = (session.displayName ?? '').trim().isEmpty
        ? 'Your account'
        : session.displayName!.trim();
    final String email = (session.email ?? '').trim();
    final String? photo = session.photoBase64;

    final List<Color> washes = walletWashColors(
      passports: ref.watch(passportListProvider),
      idDocs: ref.watch(idListProvider),
      scheme: CardFluidScheme.auto,
    );

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
                onPressed: () {
                  HapticService.select();
                  Navigator.of(context).pop();
                },
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: <Widget>[
                  Center(
                    child: Column(
                      children: <Widget>[
                        _AccountAvatar(
                          photoBase64: photo,
                          meshSeed: email.isNotEmpty
                              ? email
                              : name.toLowerCase(),
                          washes: washes,
                          shape: shape,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: ink,
                            height: 1.15,
                          ),
                        ),
                        if (email.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            email,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: muted,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'PERSONAL DETAILS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: muted,
                      ),
                    ),
                  ),
                  _DetailsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: <Widget>[
                      _DetailRow(
                        icon: Icons.cake_outlined,
                        iconColor: const Color(0xFFE07A2F),
                        label: 'Date of birth',
                        value: _formatDob(profile.dateOfBirth),
                        emptyHint: 'Add date of birth',
                        onTap: () => _editDateOfBirth(context, ref, profile),
                      ),
                      const _DetailDivider(),
                      _DetailRow(
                        icon: Icons.phone_outlined,
                        iconColor: const Color(0xFF2A9D6B),
                        label: 'Phone',
                        value: profile.phone.trim().isEmpty
                            ? null
                            : profile.phone.trim(),
                        emptyHint: 'Add phone number',
                        onTap: () => _editTextField(
                          context,
                          ref,
                          title: 'Phone',
                          initial: profile.phone,
                          keyboard: TextInputType.phone,
                          hint: 'Mobile or landline',
                          onSave: (String v) => ref
                              .read(accountProfileProvider.notifier)
                              .setPhone(v),
                        ),
                      ),
                      const _DetailDivider(),
                      _DetailRow(
                        icon: Icons.public_rounded,
                        iconColor: const Color(0xFF2F6FED),
                        label: 'Nationality',
                        value: profile.nationality.trim().isEmpty
                            ? null
                            : profile.nationality.trim().toUpperCase(),
                        emptyHint: 'Add nationality',
                        onTap: () => _editTextField(
                          context,
                          ref,
                          title: 'Nationality',
                          initial: profile.nationality,
                          keyboard: TextInputType.text,
                          hint: 'e.g. IND',
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 3,
                          onSave: (String v) => ref
                              .read(accountProfileProvider.notifier)
                              .setNationality(v),
                        ),
                      ),
                      const _DetailDivider(),
                      _DetailRow(
                        icon: Icons.location_city_outlined,
                        iconColor: const Color(0xFFAF52DE),
                        label: 'City',
                        value: profile.city.trim().isEmpty
                            ? null
                            : profile.city.trim(),
                        emptyHint: 'Add city',
                        onTap: () => _editTextField(
                          context,
                          ref,
                          title: 'City',
                          initial: profile.city,
                          keyboard: TextInputType.streetAddress,
                          hint: 'Where you live',
                          textCapitalization: TextCapitalization.words,
                          onSave: (String v) => ref
                              .read(accountProfileProvider.notifier)
                              .setCity(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'NOTES',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: muted,
                      ),
                    ),
                  ),
                  _DetailsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: <Widget>[
                      _DetailRow(
                        icon: Icons.notes_rounded,
                        iconColor: const Color(0xFF8E8E93),
                        label: 'Personal note',
                        value: profile.notes.trim().isEmpty
                            ? null
                            : profile.notes.trim(),
                        emptyHint: 'Optional note for yourself',
                        multiline: true,
                        onTap: () => _editTextField(
                          context,
                          ref,
                          title: 'Personal note',
                          initial: profile.notes,
                          keyboard: TextInputType.multiline,
                          hint: 'Anything you want to remember',
                          maxLines: 4,
                          onSave: (String v) => ref
                              .read(accountProfileProvider.notifier)
                              .setNotes(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'These details stay on this device. They are not used for '
                    'sign-in and are separate from your wallet documents.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.4,
                      color: muted.withValues(alpha: 0.85),
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

// ── Avatar ────────────────────────────────────────────────────────────────────

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.photoBase64,
    required this.meshSeed,
    required this.washes,
    required this.shape,
  });

  final String? photoBase64;
  final String meshSeed;
  final List<Color> washes;
  final ProfileAvatarShape shape;

  static const double _size = 108;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCircle = shape == ProfileAvatarShape.circle;
    final double radius = isCircle ? _size / 2 : 28;
    final BorderRadius clip = BorderRadius.circular(radius);

    final Color strokeOuter = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFFB8B8C0);
    final Color strokeInner = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.75);

    final String photo = (photoBase64 ?? '').trim();
    final List<Color> colors = avatarMeshColors(
      seed: meshSeed,
      washes: washes,
    );
    final double phase = meshPhaseForSeed(meshSeed);

    final Widget face = photo.isNotEmpty
        ? SafeBase64Image(
            base64: photo,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            placeholder: CustomPaint(
              painter: AvatarMeshPainter(colors: colors, phase: phase),
            ),
          )
        : CustomPaint(
            painter: AvatarMeshPainter(colors: colors, phase: phase),
          );

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: clip,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: colors.first.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: clip,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            face,
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: clip,
                border: Border.all(color: strokeOuter, width: 1.75),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(1.75),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    (radius - 1.75).clamp(0.0, radius),
                  ),
                  border: Border.all(color: strokeInner, width: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Details chrome ────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.surface,
    required this.borderColor,
    required this.isDark,
    required this.children,
  });

  final Color surface;
  final Color borderColor;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 54,
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.emptyHint,
    required this.onTap,
    this.value,
    this.multiline = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String emptyHint;
  final VoidCallback onTap;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.50);
    final bool hasValue = value != null && value!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.select();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: multiline && hasValue
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: muted,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? value! : emptyHint,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight:
                            hasValue ? FontWeight.w500 : FontWeight.w400,
                        letterSpacing: -0.2,
                        color: hasValue
                            ? ink
                            : muted.withValues(alpha: 0.85),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: muted.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Editors ───────────────────────────────────────────────────────────────────

String? _formatDob(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  if (s.contains('-') && s.length >= 10) {
    final List<String> p = s.split('-');
    if (p.length == 3) {
      const List<String> months = <String>[
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
      final int? m = int.tryParse(p[1]);
      final int? d = int.tryParse(p[2]);
      if (m != null && m >= 1 && m <= 12 && d != null) {
        return '$d ${months[m - 1]} ${p[0]}';
      }
    }
  }
  return s;
}

Future<void> _editDateOfBirth(
  BuildContext context,
  WidgetRef ref,
  AccountProfile profile,
) async {
  final TextEditingController controller = TextEditingController(
    text: profile.dateOfBirth,
  );
  await showDocumentDatePicker(
    context: context,
    controller: controller,
    kind: DocumentDateKind.dateOfBirth,
    title: 'Date of birth',
    onChanged: () {},
  );
  if (!context.mounted) {
    controller.dispose();
    return;
  }
  final String next = controller.text.trim();
  controller.dispose();
  if (next.isEmpty) return;
  HapticService.success();
  await ref.read(accountProfileProvider.notifier).setDateOfBirth(next);
}

Future<void> _editTextField(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String initial,
  required TextInputType keyboard,
  required String hint,
  required Future<void> Function(String) onSave,
  TextCapitalization textCapitalization = TextCapitalization.none,
  int maxLines = 1,
  int? maxLength,
}) async {
  final TextEditingController controller = TextEditingController(text: initial);
  final String? result = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AppleSheet(
          title: title,
          showDragHandle: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: keyboard,
                  textCapitalization: textCapitalization,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  inputFormatters: maxLength == 3
                      ? <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z]'),
                          ),
                          LengthLimitingTextInputFormatter(3),
                        ]
                      : null,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    counterText: '',
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    if (initial.trim().isNotEmpty)
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(''),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(controller.text),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  controller.dispose();
  if (result == null || !context.mounted) return;
  HapticService.success();
  await onSave(result);
}
