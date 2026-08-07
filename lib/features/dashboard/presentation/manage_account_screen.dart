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

/// Signed-in account: photo, name/email, optional personal details.
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
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
    final Color surface =
        isDark ? const Color(0xFF16161A) : Colors.white;
    final Color hairline =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    final String name = (session.displayName ?? '').trim().isEmpty
        ? 'Your account'
        : session.displayName!.trim();
    final String email = (session.email ?? '').trim();

    final List<Color> washes = walletWashColors(
      passports: ref.watch(passportListProvider),
      idDocs: ref.watch(idListProvider),
      scheme: CardFluidScheme.auto,
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Minimal top bar
            SizedBox(
              height: 44,
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: ink,
                    ),
                    tooltip: 'Back',
                    onPressed: () {
                      HapticService.select();
                      Navigator.of(context).pop();
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance back button
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: <Widget>[
                  // Identity
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 28),
                    child: Column(
                      children: <Widget>[
                        _AccountAvatar(
                          photoBase64: session.photoBase64,
                          meshSeed: email.isNotEmpty
                              ? email
                              : name.toLowerCase(),
                          washes: washes,
                          shape: shape,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            color: ink,
                            height: 1.15,
                          ),
                        ),
                        if (email.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
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

                  // Single clean group — label left, value right
                  _Group(
                    surface: surface,
                    hairline: hairline,
                    isDark: isDark,
                    children: <Widget>[
                      _Field(
                        label: 'Birthday',
                        value: _formatDob(profile.dateOfBirth),
                        hairline: hairline,
                        showDivider: true,
                        onTap: () => _editDateOfBirth(context, ref, profile),
                      ),
                      _Field(
                        label: 'Phone',
                        value: _orNull(profile.phone),
                        hairline: hairline,
                        showDivider: true,
                        onTap: () => _editText(
                          context,
                          ref,
                          title: 'Phone',
                          initial: profile.phone,
                          keyboard: TextInputType.phone,
                          onSave: (String v) => ref
                              .read(accountProfileProvider.notifier)
                              .setPhone(v),
                        ),
                      ),
                      _Field(
                        label: 'Nationality',
                        value: _orNull(profile.nationality)?.toUpperCase(),
                        hairline: hairline,
                        showDivider: true,
                        onTap: () => _editText(
                          context,
                          ref,
                          title: 'Nationality',
                          initial: profile.nationality,
                          keyboard: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 3,
                          onSave: (String v) => ref
                              .read(accountProfileProvider.notifier)
                              .setNationality(v),
                        ),
                      ),
                      _Field(
                        label: 'City',
                        value: _orNull(profile.city),
                        hairline: hairline,
                        showDivider: false,
                        onTap: () => _editText(
                          context,
                          ref,
                          title: 'City',
                          initial: profile.city,
                          keyboard: TextInputType.streetAddress,
                          textCapitalization: TextCapitalization.words,
                          onSave: (String v) => ref
                              .read(accountProfileProvider.notifier)
                              .setCity(v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Optional. Stored only on this device.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: muted,
                      ),
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

String? _orNull(String raw) {
  final String s = raw.trim();
  return s.isEmpty ? null : s;
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

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCircle = shape == ProfileAvatarShape.circle;
    final double radius = isCircle ? _size / 2 : 24;
    final BorderRadius clip = BorderRadius.circular(radius);

    final Color stroke = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFFC7C7CC);

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
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                border: Border.all(color: stroke, width: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form group ────────────────────────────────────────────────────────────────

class _Group extends StatelessWidget {
  const _Group({
    required this.surface,
    required this.hairline,
    required this.isDark,
    required this.children,
  });

  final Color surface;
  final Color hairline;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hairline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// iOS Settings–style row: label left, value right. No icon plates.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.hairline,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final String? value;
  final Color hairline;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink =
        isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final Color placeholder = const Color(0xFF8E8E93);
    final bool filled = value != null && value!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticService.select();
              onTap();
            },
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                        color: ink,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        filled ? value! : 'Not set',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                          color: filled ? ink : placeholder.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: placeholder.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 16,
            color: hairline,
          ),
      ],
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
  try {
    await showDocumentDatePicker(
      context: context,
      controller: controller,
      kind: DocumentDateKind.dateOfBirth,
      title: 'Birthday',
      onChanged: () {},
    );
    if (!context.mounted) return;
    final String next = controller.text.trim();
    if (next.isEmpty) return;
    HapticService.success();
    try {
      await ref.read(accountProfileProvider.notifier).setDateOfBirth(next);
    } catch (_) {
      HapticService.error();
    }
  } finally {
    // Date sheet may still listen during the pop animation — dispose next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }
}

Future<void> _editText(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String initial,
  required TextInputType keyboard,
  required Future<void> Function(String) onSave,
  TextCapitalization textCapitalization = TextCapitalization.none,
  int? maxLength,
  int maxLines = 1,
}) async {
  // Controller lives inside [_AccountTextEditSheet] so it is only disposed
  // after the TextField unmounts (not while the sheet is still animating out).
  final String? result = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return _AccountTextEditSheet(
        title: title,
        initial: initial,
        keyboard: keyboard,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        maxLines: maxLines,
      );
    },
  );

  if (result == null || !context.mounted) return;
  HapticService.success();
  try {
    await onSave(result);
  } catch (_) {
    HapticService.error();
  }
}

/// Owns its [TextEditingController] for the duration of the modal route.
class _AccountTextEditSheet extends StatefulWidget {
  const _AccountTextEditSheet({
    required this.title,
    required this.initial,
    required this.keyboard,
    required this.textCapitalization,
    this.maxLength,
    this.maxLines = 1,
  });

  final String title;
  final String initial;
  final TextInputType keyboard;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final int maxLines;

  @override
  State<_AccountTextEditSheet> createState() => _AccountTextEditSheetState();
}

class _AccountTextEditSheetState extends State<_AccountTextEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink =
        isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AppleSheet(
        title: widget.title,
        showDragHandle: true,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: widget.keyboard,
                textCapitalization: widget.textCapitalization,
                textInputAction: widget.maxLines > 1
                    ? TextInputAction.newline
                    : TextInputAction.done,
                maxLength: widget.maxLength,
                maxLines: widget.maxLines,
                minLines: widget.maxLines > 1 ? 3 : 1,
                onSubmitted: widget.maxLines > 1
                    ? null
                    : (String v) => Navigator.of(context).pop(v),
                inputFormatters: widget.maxLength == 3
                    ? <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z]'),
                        ),
                        LengthLimitingTextInputFormatter(3),
                      ]
                    : null,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                  color: ink,
                ),
                decoration: InputDecoration(
                  hintText: widget.title,
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF8E8E93),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  if (widget.initial.trim().isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: ink.withValues(alpha: 0.55)),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
