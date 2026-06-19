import 'dart:math' as math;
import 'dart:ui';


import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/bounce_tap.dart';
import '../../../shared/widgets/apple_sheet.dart';
import '../../../shared/widgets/roll_page_stack.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../ids/presentation/add_id_sheet.dart';
import '../../ids/presentation/id_entry_screen.dart';
import '../../ids/presentation/wallet_id_card.dart';
import '../../passport/application/passport_draft_controller.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../passport/presentation/passport_entry_screen.dart';
import '../../tickets/presentation/tickets_tab.dart';
import '../../tickets/presentation/wallet_ticket_card.dart';
import 'wallet_passport_card.dart';
import '../application/trash_provider.dart';
import '../application/wallet_order_provider.dart';
import '../application/nav_labels_provider.dart';

enum DashboardViewMode {
  home,
  manage,
  trash,
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;
  late final TabController _tabCtrl;
  late final ValueNotifier<double> _docPage;
  late final AnimationController _easterEggCtrl;
  final ValueNotifier<double> _easterEggOffset = ValueNotifier(0.0);
  final ValueNotifier<bool> _showHomeMenu = ValueNotifier(false);
  final ValueNotifier<DashboardViewMode> _viewMode = ValueNotifier(DashboardViewMode.home);
  double _dragOffset = 0.0;
  bool _isDragging = false;

  final LayerLink _headerTitleLink = LayerLink();
  DashboardViewMode _openedMode = DashboardViewMode.home;

  void _onMenuToggle() {
    if (_showHomeMenu.value) {
      setState(() {
        _openedMode = _viewMode.value;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _showHomeMenu.addListener(_onMenuToggle);
    _docPage = ValueNotifier(0.0);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.0, 1.0, curve: Curves.easeOutQuint),
          ),
        );
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
    _easterEggCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _easterEggCtrl.addListener(() {
      if (!_isDragging) {
        _easterEggOffset.value = _easterEggCtrl.value * 246.0;
        _dragOffset = _easterEggOffset.value;
      }
    });
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _showHomeMenu.removeListener(_onMenuToggle);
    _entryCtrl.dispose();
    _tabCtrl.dispose();
    _docPage.dispose();
    _easterEggCtrl.dispose();
    _easterEggOffset.dispose();
    _showHomeMenu.dispose();
    _viewMode.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _isDragging = true;
    final double delta = details.primaryDelta ?? 0;
    // Scale delta down to 0.65 to make dragging stiffer and more controlled
    _dragOffset += delta * 0.65;
    
    final double panelHeight = 246.0;
    double effective = _dragOffset;
    if (_dragOffset > panelHeight) {
      final double overshoot = _dragOffset - panelHeight;
      // Stiffer rubber banding factor of 0.12 past the panel height
      effective = panelHeight + (overshoot * 0.12);
    } else if (_dragOffset < 0) {
      effective = 0;
    }
    _easterEggOffset.value = effective;
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    final double panelHeight = 246.0;
    final double currentOffset = _easterEggOffset.value;
    
    if (currentOffset > 110.0) {
      final double startProgress = (currentOffset / panelHeight).clamp(0.0, 1.0);
      _easterEggCtrl.value = startProgress;
      _easterEggCtrl.animateTo(1.0, curve: Curves.easeOutBack);
    } else {
      final double startProgress = (currentOffset / panelHeight).clamp(0.0, 1.0);
      _easterEggCtrl.value = startProgress;
      _easterEggCtrl.animateTo(0.0, curve: Curves.easeOut);
    }
  }

  void _openPassportEntry(bool isEPassport) {
    ref.read(passportDraftProvider.notifier).reset();
    ref.read(passportDraftProvider.notifier).updateIsEPassport(isEPassport);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const PassportEntryScreen(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuint,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openIdEntry(IdDocumentType type) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => IdEntryScreen(type: type),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuint,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }


  void _showAddSheet() {
    HapticFeedback.mediumImpact();
    if (_tabCtrl.index == 0) {
      // Docs tab — choose Passport or ID
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AddItemSheet(
          onAddPassport: () {
            Navigator.of(context).pop();
            _showPassportTypeSheet();
          },
          onAddId: () {
            Navigator.of(context).pop();
            showModalBottomSheet<void>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddIdSheet(onSelectType: _openIdEntry),
            );
          },
        ),
      );
    } else {
      // Tickets tab — coming soon
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _TicketsComingSoonSheet(),
      );
    }
  }

  void _showPassportTypeSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PassportTypeSheet(
        onSelectEPassport: () {
          Navigator.of(context).pop();
          _openPassportEntry(true);
        },
        onSelectRegularPassport: () {
          Navigator.of(context).pop();
          _openPassportEntry(false);
        },
      ),
    );
  }

  void _showSettingsSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SettingsSheet(),
    );
  }


  void _showDeleteDialog(PassportProfile profile) {
    HapticFeedback.heavyImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Remove Passport?'),
        message: Text(
          'This will remove ${profile.name}\'s passport from your wallet.',
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(passportListProvider.notifier).removePassport(profile.id);
              ref.read(trashProvider.notifier).moveToTrash(profile);
              ref.read(walletOrderProvider.notifier).updateOrderOnItemRemoved(profile.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Remove'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showDeleteIdDialog(IdDocument doc) {
    HapticFeedback.heavyImpact();
    final String label = doc.holderName.isEmpty
        ? 'this card'
        : "${doc.holderName}'s";
    final String type = doc.type == IdDocumentType.pan
        ? 'PAN Card'
        : 'Aadhaar Card';
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Remove ID Card?'),
        message: Text('This will remove $label $type from your wallet.'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(idListProvider.notifier).removeDocument(doc.id);
              ref.read(trashProvider.notifier).moveToTrash(doc);
              ref.read(walletOrderProvider.notifier).updateOrderOnItemRemoved(doc.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Remove'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);
    final List<String> order = ref.watch(walletOrderProvider);

    // Self-healing sync of sorting order
    final activeIds = [...passports.map((p) => p.id), ...idDocs.map((d) => d.id)];
    final missingFromOrder = activeIds.where((id) => !order.contains(id)).toList();
    final noLongerActive = order.where((id) => !activeIds.contains(id)).toList();
    if (missingFromOrder.isNotEmpty || noLongerActive.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final newOrder = [...order];
        newOrder.removeWhere((id) => noLongerActive.contains(id));
        newOrder.insertAll(0, missingFromOrder);
        ref.read(walletOrderProvider.notifier).saveOrder(newOrder);
      });
    }

    // Combine and sort
    final List<Object> items = <Object>[...passports, ...idDocs];
    items.sort((a, b) {
      final String idA = a is PassportProfile ? a.id : (a as IdDocument).id;
      final String idB = b is PassportProfile ? b.id : (b as IdDocument).id;
      int idxA = order.indexOf(idA);
      int idxB = order.indexOf(idB);
      if (idxA == -1) idxA = 9999;
      if (idxB == -1) idxB = 9999;
      return idxA.compareTo(idxB);
    });

    final String currentName = passports.isNotEmpty ? passports.first.name : '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: Stack(
          children: <Widget>[
            ValueListenableBuilder<double>(
              valueListenable: _easterEggOffset,
              builder: (context, offsetY, drawerWidget) {
                final double panelHeight = 246.0;
                // Parallax background: offset starts at -30px when closed, reaches 0px when fully open.
                final double drawerTop = -30.0 + (30.0 * (offsetY / panelHeight).clamp(0.0, 1.0));

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Easter Egg Drawer (positioned in background with parallax)
                    Positioned(
                      top: drawerTop,
                      left: 0,
                      right: 0,
                      height: panelHeight + 150.0,
                      child: drawerWidget!,
                    ),
                    // 2. Main Sliding Sheet (translated down, rounded at top)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, offsetY),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: offsetY > 0
                                ? const BorderRadius.vertical(top: Radius.circular(44))
                                : BorderRadius.zero,
                            boxShadow: offsetY > 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 16,
                                      offset: const Offset(0, -6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              // Background mesh moving with the sheet
                              RepaintBoundary(
                                child: _WalletBackdrop(
                                  tabIndex: _tabCtrl.index,
                                  items: items,
                                  pageNotifier: _docPage,
                                ),
                              ),
                              // Content Column
                              SafeArea(
                                child: FadeTransition(
                                  opacity: _entryFade,
                                  child: SlideTransition(
                                    position: _entrySlide,
                                    child: Column(
                                      children: [
                                        // Header with Drag Interceptor
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onVerticalDragUpdate: _handleDragUpdate,
                                          onVerticalDragEnd: _handleDragEnd,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                            child: ValueListenableBuilder<bool>(
                                              valueListenable: _showHomeMenu,
                                              builder: (context, isMenuOpen, _) {
                                                return ValueListenableBuilder<DashboardViewMode>(
                                                  valueListenable: _viewMode,
                                                  builder: (context, currentMode, _) {
                                                    return _DashboardHeader(
                                                      name: currentName,
                                                      isMenuOpen: isMenuOpen,
                                                      currentMode: currentMode,
                                                      onHomeTap: () {
                                                        _showHomeMenu.value = !_showHomeMenu.value;
                                                      },
                                                      onAvatarTap: _showSettingsSheet,
                                                      headerTitleLink: _headerTitleLink,
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // Tab content
                                        ValueListenableBuilder<DashboardViewMode>(
                                          valueListenable: _viewMode,
                                          builder: (context, mode, _) {
                                            Widget viewChild;
                                            switch (mode) {
                                              case DashboardViewMode.home:
                                                viewChild = TabBarView(
                                                  key: const ValueKey('home_view'),
                                                  controller: _tabCtrl,
                                                  clipBehavior: Clip.none,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  children: [
                                                    _IdsTab(
                                                      passports: passports,
                                                      idDocs: idDocs,
                                                      onDeletePassport: _showDeleteDialog,
                                                      onDeleteId: _showDeleteIdDialog,
                                                      pageNotifier: _docPage,
                                                    ),
                                                    const TicketsTab(),
                                                  ],
                                                );
                                                break;
                                              case DashboardViewMode.manage:
                                                viewChild = _ManageCardsView(
                                                  key: const ValueKey('manage_view'),
                                                  items: items,
                                                );
                                                break;
                                              case DashboardViewMode.trash:
                                                viewChild = const _TrashView(
                                                  key: ValueKey('trash_view'),
                                                );
                                                break;
                                            }

                                            return Expanded(
                                              child: AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 350),
                                                switchInCurve: Curves.easeOutCubic,
                                                switchOutCurve: Curves.easeInCubic,
                                                transitionBuilder: (child, animation) {
                                                  return FadeTransition(
                                                    opacity: animation,
                                                    child: SlideTransition(
                                                      position: Tween<Offset>(
                                                        begin: const Offset(0, 0.04),
                                                        end: Offset.zero,
                                                      ).animate(animation),
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                                child: viewChild,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Tap Barrier to dismiss menu
                              ValueListenableBuilder<bool>(
                                valueListenable: _showHomeMenu,
                                builder: (context, show, child) {
                                  if (!show) return const SizedBox.shrink();
                                  return Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showHomeMenu.value = false,
                                      child: Container(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Custom iOS-style expanded view picker
                              ValueListenableBuilder<bool>(
                                valueListenable: _showHomeMenu,
                                builder: (context, show, child) {
                                  return ValueListenableBuilder<DashboardViewMode>(
                                    valueListenable: _viewMode,
                                    builder: (context, currentMode, _) {
                                      return _IosMenuPickerExpanded(
                                        link: _headerTitleLink,
                                        visible: show,
                                        currentMode: currentMode,
                                        openedMode: _openedMode,
                                        onSelectMode: (mode) {
                                          _viewMode.value = mode;
                                          Future.delayed(const Duration(milliseconds: 280), () {
                                            if (mounted) {
                                              _showHomeMenu.value = false;
                                            }
                                          });
                                        },
                                        onClose: () {
                                          _showHomeMenu.value = false;
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: _EasterEggDrawer(
                controller: _easterEggCtrl,
                dragOffsetNotifier: _easterEggOffset,
                onDragUpdate: _handleDragUpdate,
                onDragEnd: _handleDragEnd,
                passports: passports,
                idDocs: idDocs,
                tickets: mockTickets,
                onAddPassport: _showPassportTypeSheet,
                onAddId: _openIdEntry,
              ),
            ),

            // ── Bottom island bar ────────────────────────────────────────
            ValueListenableBuilder<DashboardViewMode>(
              valueListenable: _viewMode,
              builder: (context, mode, child) {
                final bool isHome = mode == DashboardViewMode.home;
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                  bottom: isHome ? 0 : -100,
                  left: 0,
                  right: 0,
                  child: child!,
                );
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 20,
                  right: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PillTabBar(controller: _tabCtrl),
                    const SizedBox(width: 10),
                    _AddFab(onTap: _showAddSheet),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ISLAND BAR ──────────────────────────────────────────────────────────────

class _IslandBar extends StatefulWidget {
  const _IslandBar({required this.controller, required this.onAdd});
  final TabController controller;
  final VoidCallback onAdd;

  @override
  State<_IslandBar> createState() => _IslandBarState();
}

class _IslandBarState extends State<_IslandBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.animation!.addListener(_onAnim);
  }

  @override
  void dispose() {
    widget.controller.animation!.removeListener(_onAnim);
    super.dispose();
  }

  void _onAnim() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final double t = (widget.controller.animation!.value).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Tab items ──────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    // Sliding active indicator
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(t * 2 - 1, 0),
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 7,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Tab labels with icons
                    Row(
                      children: [
                        _IslandTab(
                          icon: Icons.wallet_rounded,
                          label: 'IDs',
                          index: 0,
                          t: t,
                          controller: widget.controller,
                        ),
                        _IslandTab(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Passes',
                          index: 1,
                          t: t,
                          controller: widget.controller,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Divider ────────────────────────────────────────────
              Container(
                width: 0.5,
                height: 28,
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.10),
              ),

              // ── Add button ─────────────────────────────────────────
              _IslandAddButton(onTap: widget.onAdd),
            ],
          ),
        ),
      ),
    );
  }
}

class _IslandTab extends StatelessWidget {
  const _IslandTab({
    required this.icon,
    required this.label,
    required this.index,
    required this.t,
    required this.controller,
  });
  final IconData icon;
  final String label;
  final int index;
  final double t;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final bool active = index == 0 ? t < 0.5 : t >= 0.5;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          controller.animateTo(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? Colors.white : const Color(0xFF8E8E93),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? Colors.white : const Color(0xFF8E8E93),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslandAddButton extends StatefulWidget {
  const _IslandAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_IslandAddButton> createState() => _IslandAddButtonState();
}

class _IslandAddButtonState extends State<_IslandAddButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _rotCtrl;
  late final Animation<double> _rotAnim;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _rotAnim = CurvedAnimation(parent: _rotCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
        _rotCtrl.forward();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _rotCtrl.reverse();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _rotCtrl.reverse();
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.92 : 1.0,
        child: SizedBox(
          width: 64,
          height: 58,
          child: Center(
            child: RotationTransition(
              turns: Tween<double>(begin: 0, end: 0.125).animate(_rotAnim),
              child: const Icon(
                Icons.add_rounded,
                size: 26,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CUSTOM ID CARD VECTOR ICON ──────────────────────────────────────────────

class _CustomIdCardIcon extends StatelessWidget {
  const _CustomIdCardIcon({
    required this.color,
    required this.width,
    required this.height,
  });
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _CustomIdCardPainter(color: color),
      ),
    );
  }
}

class _CustomIdCardPainter extends CustomPainter {
  _CustomIdCardPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw card background (filled rounded rect) matching the given size
    final double cardW = w;
    final double cardH = h;
    final double cardX = 0;
    final double cardY = 0;

    // Use saveLayer to allow BlendMode.clear cutouts
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());

    final Paint cardPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final RRect cardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, cardW, cardH),
      Radius.circular(cardH * 0.20),
    );
    canvas.drawRRect(cardRRect, cardPaint);

    // 2. Setup clear paint for cutouts
    final Paint clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    // 3. Cutout the avatar circle on the left
    final double avatarRadius = cardH * 0.28;
    final double avatarCenterX = cardX + cardW * 0.28;
    final double avatarCenterY = cardY + cardH * 0.44;
    canvas.drawCircle(Offset(avatarCenterX, avatarCenterY), avatarRadius, clearPaint);

    // 4. Draw avatar silhouette inside the cutout circle (using original color)
    // Head: circle
    final double headRadius = avatarRadius * 0.38;
    final double headCenterX = avatarCenterX;
    final double headCenterY = avatarCenterY - avatarRadius * 0.2;
    canvas.drawCircle(Offset(headCenterX, headCenterY), headRadius, cardPaint);

    // Shoulders: bottom circle cutout
    final double shoulderRadius = avatarRadius * 0.75;
    final double shoulderCenterX = avatarCenterX;
    final double shoulderCenterY = avatarCenterY + avatarRadius * 1.05;
    canvas.drawCircle(Offset(shoulderCenterX, shoulderCenterY), shoulderRadius, cardPaint);

    // 5. Cutout lines
    final double lineThickness = cardH * 0.09;
    final double lineRadius = lineThickness / 2;

    // Line 1: top right short
    final RRect line1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cardX + cardW * 0.54,
        cardY + cardH * 0.26,
        cardW * 0.34,
        lineThickness,
      ),
      Radius.circular(lineRadius),
    );
    canvas.drawRRect(line1, clearPaint);

    // Line 2: middle right short
    final RRect line2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cardX + cardW * 0.54,
        cardY + cardH * 0.52,
        cardW * 0.34,
        lineThickness,
      ),
      Radius.circular(lineRadius),
    );
    canvas.drawRRect(line2, clearPaint);

    // Line 3: bottom long line
    final RRect line3 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cardX + cardW * 0.12,
        cardY + cardH * 0.78,
        cardW * 0.76,
        lineThickness,
      ),
      Radius.circular(lineRadius),
    );
    canvas.drawRRect(line3, clearPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CustomIdCardPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─── REDESIGNED PILL TAB BAR ──────────────────────────────────────────────────

class _PillTabBar extends ConsumerStatefulWidget {
  const _PillTabBar({required this.controller});
  final TabController controller;

  @override
  ConsumerState<_PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends ConsumerState<_PillTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.animation!.addListener(_onTabAnim);
  }

  @override
  void dispose() {
    widget.controller.animation!.removeListener(_onTabAnim);
    super.dispose();
  }

  void _onTabAnim() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final double t = (widget.controller.animation!.value).clamp(0.0, 1.0);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 250,
      height: 82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5)
            : Border.all(color: Colors.black.withValues(alpha: 0.06), width: 0.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          _ActiveTabHighlight(t: t),
          // Labels
          Row(
            children: [
              _TabLabel(
                label: 'IDs',
                iconBuilder: (context, color, selected, showLabels) {
                  final double w = showLabels
                      ? (selected ? 32.0 : 28.0)
                      : (selected ? 42.0 : 38.0);
                  final double h = showLabels
                      ? (selected ? 23.0 : 20.0)
                      : (selected ? 30.0 : 27.0);
                  return _CustomIdCardIcon(
                    color: color,
                    width: w,
                    height: h,
                  );
                },
                index: 0,
                controller: widget.controller,
                t: t,
              ),
              _TabLabel(
                label: 'Passes',
                iconBuilder: (context, color, selected, showLabels) {
                  final double s = showLabels
                      ? (selected ? 26.0 : 24.0)
                      : (selected ? 34.0 : 32.0);
                  return Icon(
                    selected ? Icons.airplane_ticket_rounded : Icons.airplane_ticket_outlined,
                    color: color,
                    size: s,
                  );
                },
                index: 1,
                controller: widget.controller,
                t: t,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveTabHighlight extends StatelessWidget {
  const _ActiveTabHighlight({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color pillColor = isDark
        ? const Color(0xFF242426)
        : const Color(0xFFEEF0FF);

    return Align(
      alignment: Alignment(t * 2 - 1, 0),
      child: FractionallySizedBox(
        widthFactor: 0.5,
        heightFactor: 1.0,
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Container(
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabLabel extends ConsumerStatefulWidget {
  const _TabLabel({
    required this.label,
    required this.iconBuilder,
    required this.index,
    required this.controller,
    required this.t,
  });
  final String label;
  final Widget Function(BuildContext context, Color color, bool selected, bool showLabels) iconBuilder;
  final int index;
  final TabController controller;
  final double t;

  @override
  ConsumerState<_TabLabel> createState() => _TabLabelState();
}

class _TabLabelState extends ConsumerState<_TabLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;
  bool _wasSelected = false;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.16,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 34,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.16,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 38,
      ),
    ]).animate(_bounce);
  }

  @override
  void didUpdateWidget(_TabLabel old) {
    super.didUpdateWidget(old);
    final selected = widget.index == 0 ? widget.t < 0.5 : widget.t >= 0.5;
    if (selected && !_wasSelected) {
      _bounce.forward(from: 0);
    }
    _wasSelected = selected;
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool selected = widget.index == 0 ? widget.t < 0.5 : widget.t >= 0.5;
    final bool showLabels = ref.watch(showNavLabelsProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color activeIconColor = isDark ? const Color(0xFFC0B3FF) : const Color(0xFF4C3AFF);
    final Color inactiveIconColor = const Color(0xFF8E8E93);
    final Color activeTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color inactiveTextColor = const Color(0xFF8E8E93);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.controller.animateTo(widget.index);
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _scale,
                builder: (context, child) {
                  final double scale = selected ? _scale.value : 1.0;
                  final Color iconColor = selected ? activeIconColor : inactiveIconColor;
                  return Transform.scale(
                    scale: scale,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: widget.iconBuilder(context, iconColor, selected, showLabels),
                    ),
                  );
                },
              ),
              // Conditional Label with animated opacity transition
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showLabels ? 1.0 : 0.0,
                curve: Curves.easeInOutCubic,
                child: showLabels
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: selected ? 12.5 : 11.5,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              letterSpacing: -0.1,
                              color: selected ? activeTextColor : inactiveTextColor,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── IDS TAB (passports + IDs combined) ──────────────────────────────────────

class _IdsTab extends StatefulWidget {
  const _IdsTab({
    required this.passports,
    required this.idDocs,
    required this.onDeletePassport,
    required this.onDeleteId,
    required this.pageNotifier,
  });

  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final void Function(PassportProfile) onDeletePassport;
  final void Function(IdDocument) onDeleteId;
  final ValueNotifier<double> pageNotifier;

  @override
  State<_IdsTab> createState() => _IdsTabState();
}

class _IdsTabState extends State<_IdsTab> {
  late final PageController _pageCtrl;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pageCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onScroll);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() => _page = _pageCtrl.page ?? 0);
    widget.pageNotifier.value = _page;
  }

  @override
  Widget build(BuildContext context) {
    final double fabClearance =
        MediaQuery.of(context).padding.bottom + 16 + 58 + 20;
    final items = <Object>[...widget.passports, ...widget.idDocs];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 0, 32, fabClearance),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _EmptyDocsPreview(),
              const SizedBox(height: 28),
              Text(
                'No Documents Yet',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to add a passport or ID card.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8E8E93) : const Color(0xFF64748B),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final double delta = (_page - index).clamp(-1.0, 1.0);
            return RollPageStack(
              delta: delta,
              padding: EdgeInsets.fromLTRB(20, 8, 28, fabClearance),
              child: item is PassportProfile
                  ? WalletPassportCard(
                      profile: item,
                      onLongPress: () => widget.onDeletePassport(item),
                    )
                  : WalletIdCard(
                      document: item as IdDocument,
                      onLongPress: () => widget.onDeleteId(item),
                    ),
            );
          },
        ),
        if (items.length > 1)
          Positioned(
            right: 12,
            top: 0,
            bottom: fabClearance,
            child: Center(
              child: _DotIndicator(count: items.length, page: _page),
            ),
          ),
      ],
    );
  }
}

class _EmptyDocsPreview extends StatefulWidget {
  const _EmptyDocsPreview();

  @override
  State<_EmptyDocsPreview> createState() => _EmptyDocsPreviewState();
}

class _EmptyDocsPreviewState extends State<_EmptyDocsPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final double shimmerX = lerpDouble(-130, 130, _shimmerCtrl.value)!;
        return SizedBox(
          width: 220,
          height: 164,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _GhostDocCard(
                offset: const Offset(-18, 14),
                rotation: -0.13,
                scale: 0.90,
                color: const Color(0xFF2A9D8F),
                shimmerX: shimmerX - 28,
                alpha: 0.48,
              ),
              _GhostDocCard(
                offset: const Offset(16, 4),
                rotation: 0.10,
                scale: 0.95,
                color: const Color(0xFF7C5CBF),
                shimmerX: shimmerX + 18,
                alpha: 0.56,
              ),
              _GhostDocCard(
                offset: Offset.zero,
                rotation: -0.02,
                scale: 1.0,
                color: const Color(0xFF4C7CFF),
                shimmerX: shimmerX,
                alpha: 0.70,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GhostDocCard extends StatelessWidget {
  const _GhostDocCard({
    required this.offset,
    required this.rotation,
    required this.scale,
    required this.color,
    required this.shimmerX,
    required this.alpha,
  });

  final Offset offset;
  final double rotation;
  final double scale;
  final Color color;
  final double shimmerX;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 168,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white.withValues(alpha: 0.52),
                border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.16 * alpha),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.16 * alpha),
                            Colors.white.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 20,
                    child: Container(
                      width: 42,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18 * alpha),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  for (int i = 0; i < 3; i++)
                    Positioned(
                      left: 18,
                      right: 22 + i * 18,
                      bottom: 22 + i * 15,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16 * alpha),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  Positioned(
                    left: shimmerX,
                    top: -26,
                    bottom: -26,
                    child: Transform.rotate(
                      angle: -0.45,
                      child: Container(
                        width: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.38 * alpha),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── EMPTY TICKETS STATE ──────────────────────────────────────────────────────



// ─── DOT INDICATOR ───────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.page});
  final int count;
  final double page;

  static const int _dotThreshold = 5;
  static const double _trackH = 48.0;

  @override
  Widget build(BuildContext context) {
    if (count <= _dotThreshold) {
      // Individual animated dots
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final double distance = (page - i).abs().clamp(0.0, 1.0);
          final double size = lerpDouble(10, 6, distance)!;
          final double opacity = lerpDouble(1.0, 0.25, distance)!;
          final Color dotColor = Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF1C1C1E);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      );
    }

    final double pillH = (_trackH / count).clamp(6.0, _trackH * 0.5);
    final double travel = _trackH - pillH;
    final double offset = (page / (count - 1)).clamp(0.0, 1.0) * travel;
    final Color trackColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1C1C1E);

    return SizedBox(
      width: 4,
      height: _trackH,
      child: Stack(
        children: [
          Container(
            width: 4,
            height: _trackH,
            decoration: BoxDecoration(
              color: trackColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: offset,
            child: Container(
              width: 4,
              height: pillH,
              decoration: BoxDecoration(
                color: trackColor.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BACKDROP ────────────────────────────────────────────────────────────────

class _WalletBackdrop extends StatefulWidget {
  const _WalletBackdrop({
    this.tabIndex = 0,
    required this.items,
    required this.pageNotifier,
  });

  final int tabIndex;
  final List<Object> items;
  final ValueNotifier<double> pageNotifier;

  @override
  State<_WalletBackdrop> createState() => _WalletBackdropState();
}

class _WalletBackdropState extends State<_WalletBackdrop>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _colorCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _colorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: widget.tabIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(_WalletBackdrop old) {
    super.didUpdateWidget(old);
    if (old.tabIndex != widget.tabIndex) {
      widget.tabIndex == 1
          ? _colorCtrl.animateTo(1.0, curve: Curves.easeOutCubic)
          : _colorCtrl.animateTo(0.0, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _colorCtrl, widget.pageNotifier]),
            builder: (context, _) {
              final bool isDark = Theme.of(context).brightness == Brightness.dark;
              return CustomPaint(
                painter: _AppleCardGradientPainter(
                  isDark: isDark,
                  progress: _ctrl.value,
                  colorT: _colorCtrl.value,
                  items: widget.items,
                  page: widget.pageNotifier.value,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppleCardGradientPainter extends CustomPainter {
  _AppleCardGradientPainter({
    required this.isDark,
    required this.progress,
    required this.colorT,
    required this.items,
    required this.page,
  });
  final bool isDark;
  final double progress;
  final double colorT; // 0 = Docs (cool), 1 = Tickets (warm)
  final List<Object> items;
  final double page;

  Color _getThemeColor(Object? item) {
    if (item is PassportProfile) return const Color(0xFF007AFF); // Apple Blue
    if (item is IdDocument) {
      if (item.type == IdDocumentType.pan) return const Color(0xFFE8A020); // Orange
      return const Color(0xFF34C759); // Green
    }
    return const Color(0xFF8E8E93); // Gray default
  }

  Color _getDocsColor() {
    if (items.isEmpty) return const Color(0xFF007AFF); // Default to Blue
    final int idx1 = page.floor().clamp(0, items.length - 1);
    final int idx2 = page.ceil().clamp(0, items.length - 1);
    final double t = page - page.floor();
    final Color c1 = _getThemeColor(items[idx1]);
    final Color c2 = _getThemeColor(items[idx2]);
    return Color.lerp(c1, c2, t) ?? c1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Base background
    final Color baseDocBg = isDark ? const Color(0xFF080E1A) : const Color(0xFFF2F2F7); // Apple standard light/dark gray
    final Color baseTicketBg = isDark ? const Color(0xFF140D0B) : const Color(0xFFFFF8E8);
    final Paint base = Paint()
      ..color = Color.lerp(baseDocBg, baseTicketBg, colorT)!;
    canvas.drawRect(Offset.zero & size, base);

    final Color docsColor = _getDocsColor();
    final Color ticketsColor = const Color(0xFFFF3B30); // Ticket Red
    final Color activeColor = Color.lerp(docsColor, ticketsColor, colorT)!;

    void drawOrb(Color c, double cx, double cy, double radius) {
      final Paint paint = Paint()
        ..color = c
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    // Convert activeColor to HSL for generating matching analogous/triadic colors
    final HSLColor hslActive = HSLColor.fromColor(activeColor);

    // Orb 1 - Primary
    final double t1 = progress * 2 * math.pi;
    drawOrb(
      activeColor.withValues(alpha: isDark ? 0.16 : 0.24),
      w * 0.5 + math.cos(t1) * w * 0.12,
      h * 0.45 + math.sin(t1) * h * 0.06,
      w * 0.6,
    );

    // Orb 2 - Analogous (Hue + 40)
    final double t2 = progress * 2 * math.pi + (math.pi * 0.66);
    final Color c2 = hslActive.withHue((hslActive.hue + 40) % 360).toColor();
    drawOrb(
      c2.withValues(alpha: isDark ? 0.12 : 0.18),
      w * 0.45 + math.cos(t2) * w * 0.15,
      h * 0.52 + math.sin(t2) * h * 0.08,
      w * 0.65,
    );

    // Orb 3 - Analogous (Hue - 40)
    final double t3 = progress * 2 * math.pi + (math.pi * 1.33);
    final Color c3 = hslActive.withHue((hslActive.hue - 40 + 360) % 360).toColor();
    drawOrb(
      c3.withValues(alpha: isDark ? 0.16 : 0.24),
      w * 0.55 + math.cos(t3) * w * 0.1,
      h * 0.4 + math.sin(t3) * h * 0.05,
      w * 0.6,
    );
  }

  @override
  bool shouldRepaint(covariant _AppleCardGradientPainter old) =>
      old.progress != progress ||
      old.colorT != colorT ||
      old.page != page ||
      old.items.length != items.length ||
      old.isDark != isDark;
}

// ─── HEADER WIDGETS ───────────────────────────────────────────────────────────

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.96 : 1.0,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.60),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 0.5,
                ),
              ),
              child: Icon(
                widget.icon,
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.80),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── DASHBOARD HEADER ────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.isMenuOpen,
    required this.currentMode,
    required this.onHomeTap,
    required this.onAvatarTap,
    required this.headerTitleLink,
  });

  final String name;
  final bool isMenuOpen;
  final DashboardViewMode currentMode;
  final VoidCallback onHomeTap;
  final VoidCallback onAvatarTap;
  final LayerLink headerTitleLink;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark
        ? const Color(0xFFE8EEFF)
        : const Color(0xFF0D1B2A);
    final Color muted = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : const Color(0xFF6B7280);

    final String titleText;
    switch (currentMode) {
      case DashboardViewMode.home:
        titleText = 'Home';
        break;
      case DashboardViewMode.manage:
        titleText = 'Manage';
        break;
      case DashboardViewMode.trash:
        titleText = 'Trash';
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BounceTap(
          onTap: isMenuOpen ? null : onHomeTap,
          child: CompositedTransformTarget(
            link: headerTitleLink,
            child: IgnorePointer(
              ignoring: isMenuOpen,
              child: Opacity(
                opacity: isMenuOpen ? 0.0 : 1.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      style: GoogleFonts.inter(
                        color: ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isMenuOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        size: 20,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        _AvatarButton(name: name, onTap: onAvatarTap),
      ],
    );
  }
}

// ─── NEXT TRIP CHIP ───────────────────────────────────────────────────────────

// ─── AVATAR BUTTON ────────────────────────────────────────────────────────────

class _AvatarButton extends StatefulWidget {
  const _AvatarButton({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  State<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<_AvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final String initial = widget.name.isNotEmpty
        ? widget.name.trim()[0].toUpperCase()
        : '?';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.96 : 1.0,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFF1C1C1E).withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF0F4FF)
                        : const Color(0xFF1C1C1E),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── FLOATING ADD BUTTON ──────────────────────────────────────────────────────

class _AddFab extends StatefulWidget {
  const _AddFab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _rotateCtrl;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotateAnim = CurvedAnimation(
      parent: _rotateCtrl,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
        _rotateCtrl.forward();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _rotateCtrl.reverse();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _rotateCtrl.reverse();
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.96 : 1.0,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF141416) : Colors.white,
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5)
                : Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: RotationTransition(
            turns: Tween<double>(
              begin: 0,
              end: 0.125,
            ).animate(_rotateAnim),
            child: Icon(
              Icons.add_rounded,
              size: 26,
              color: isDark ? const Color(0xFFC0B3FF) : const Color(0xFF4C3AFF),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ADD ITEM SHEET ───────────────────────────────────────────────────────────

class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({required this.onAddPassport, required this.onAddId});

  final VoidCallback onAddPassport;
  final VoidCallback onAddId;

  @override
  Widget build(BuildContext context) {
    return AppleSheet(
      title: 'Add Document',
      subtitle: "Choose what you'd like to add",
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AddOption(
            icon: Icons.book_rounded,
            iconColor: const Color(0xFF4C7CFF),
            title: 'Passport',
            subtitle: 'Indian passport or travel document',
            onTap: onAddPassport,
          ),
          const SizedBox(height: 12),
          _AddOption(
            icon: Icons.badge_rounded,
            iconColor: const Color(0xFF1C3252),
            title: 'ID Card',
            subtitle: 'PAN Card, Aadhaar or national ID',
            onTap: onAddId,
          ),
        ],
      ),
    );
  }
}

class _TicketsComingSoonSheet extends StatelessWidget {
  const _TicketsComingSoonSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppleSheet(
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF19D3C5).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: Color(0xFF19D3C5),
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tickets Coming Soon',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Flight, train, bus and event tickets\nwill be available in a future update.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassportTypeSheet extends StatelessWidget {
  const _PassportTypeSheet({
    required this.onSelectEPassport,
    required this.onSelectRegularPassport,
  });

  final VoidCallback onSelectEPassport;
  final VoidCallback onSelectRegularPassport;

  @override
  Widget build(BuildContext context) {
    return AppleSheet(
      title: 'Passport Type',
      subtitle: "Which kind of passport are you adding?",
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _AddOption(
            icon: Icons.nfc_rounded,
            iconColor: const Color(0xFF4C7CFF),
            title: 'E-Passport',
            subtitle: 'Biometric passport with an NFC chip',
            onTap: onSelectEPassport,
          ),
          const SizedBox(height: 12),
          _AddOption(
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF19D3C5),
            title: 'Regular Passport',
            subtitle: 'Standard passport without NFC',
            onTap: onSelectRegularPassport,
          ),
        ],
      ),
    );
  }
}

class _AddOption extends StatefulWidget {
  const _AddOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_AddOption> createState() => _AddOptionState();
}

class _AddOptionState extends State<_AddOption> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.74);

    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.92);

    final Color titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color subtitleColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B);

    return BounceTap(
      onTap: widget.onTap,
      scaleFactor: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: widget.iconColor.withValues(
                  alpha: 0.06,
                ),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          children: <Widget>[
            _AddOptionPreview(
              icon: widget.icon,
              color: widget.iconColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: widget.iconColor.withValues(alpha: 0.72),
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOptionPreview extends StatelessWidget {
  const _AddOptionPreview({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  bool get _isId =>
      icon == Icons.badge_rounded || icon == Icons.credit_card_rounded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color endColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.74);

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            endColor,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isId)
            Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 48,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : color.withValues(alpha: 0.18),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 7,
                      top: 8,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: color.withValues(alpha: 0.28),
                      ),
                    ),
                    Positioned(
                      left: 19,
                      right: 7,
                      top: 8,
                      child: _PreviewLine(color: color, alpha: 0.24),
                    ),
                    Positioned(
                      left: 7,
                      right: 12,
                      bottom: 8,
                      child: _PreviewLine(color: color, alpha: 0.18),
                    ),
                  ],
                ),
              ),
            )
          else
            Transform.rotate(
              angle: 0.08,
              child: Container(
                width: 38,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : color.withValues(alpha: 0.20),
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 10,
                      child: Container(
                        height: 13,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 10,
                      bottom: 14,
                      child: _PreviewLine(color: color, alpha: 0.22),
                    ),
                    Positioned(
                      left: 8,
                      right: 16,
                      bottom: 9,
                      child: _PreviewLine(color: color, alpha: 0.16),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.color, required this.alpha});

  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

// ─── SETTINGS SHEET ───────────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final sheetBg = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.98)
        : Colors.white.withValues(alpha: 0.98);
    final titleColor = isDark
        ? const Color(0xFFF0F4FF)
        : const Color(0xFF1C1C1E);
    final handleColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE5E5EA);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: BorderRadius.circular(36),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Wallet Settings',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SettingsRow(
                  icon: Icons.style_rounded,
                  iconColor: const Color(0xFF4C7CFF),
                  title: 'Manage Cards',
                  subtitle: 'Reorder, hide or remove cards',
                ),
                const SizedBox(height: 12),
                _SettingsRow(
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFF19D3C5),
                  title: 'Security & Privacy',
                  subtitle: 'Biometrics, PIN, data storage',
                ),
                const SizedBox(height: 12),
                // ── Dark mode toggle ──────────────────────────────────
                _DarkModeRow(
                  isDark: isDark,
                  onToggle: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).toggle();
                  },
                ),
                const SizedBox(height: 12),
                // ── Navigation labels toggle ─────────────────────────
                const _NavLabelsToggleRow(),
                const SizedBox(height: 12),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF8E8E93),
                  title: 'About SlickPort',
                  subtitle: 'Version, legal, open source',
                  onTap: () {
                    Navigator.of(context).pop(); // Dismiss Settings sheet
                    showModalBottomSheet<void>(
                      context: context,
                      useSafeArea: true,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const _AboutSlickPortSheet(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow({required this.isDark, required this.onToggle});
  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final rowBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF2F2F7);
    final titleColor = isDark
        ? const Color(0xFFF0F4FF)
        : const Color(0xFF1C1C1E);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF8E8E93);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: rowBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF6E40C9).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: const Color(0xFF6E40C9),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dark Mode',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDark
                        ? 'On — tap to switch to light'
                        : 'Off — tap to switch to dark',
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Animated toggle pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF6E40C9)
                    : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: isDark
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLabelsToggleRow extends ConsumerWidget {
  const _NavLabelsToggleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showLabels = ref.watch(showNavLabelsProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    
    final rowBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF2F2F7);
    final titleColor = isDark
        ? const Color(0xFFF0F4FF)
        : const Color(0xFF1C1C1E);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF8E8E93);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(showNavLabelsProvider.notifier).toggle();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: rowBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                CupertinoIcons.textformat_abc,
                color: Color(0xFF007AFF),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Navigation Labels',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    showLabels
                        ? 'On — tap to hide text labels'
                        : 'Off — tap to show text labels',
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Animated toggle pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: showLabels
                    ? const Color(0xFF007AFF)
                    : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: showLabels
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSlickPortSheet extends StatelessWidget {
  const _AboutSlickPortSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF0F4FF) : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8E8E93);

    return AppleSheet(
      title: 'About SlickPort',
      subtitle: 'Version 1.0.0',
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Attributions & Licenses',
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text: '• "id card" icon created by ',
                  ),
                  TextSpan(
                    text: 'haritselarif',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFC0B3FF) : const Color(0xFF4C3AFF),
                    ),
                  ),
                  const TextSpan(
                    text: ' from the ',
                  ),
                  TextSpan(
                    text: 'Noun Project',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFC0B3FF) : const Color(0xFF4C3AFF),
                    ),
                  ),
                  const TextSpan(
                    text: ' (licensed under CC BY 3.0).\n\n',
                  ),
                  const TextSpan(
                    text: '• Built with Flutter & Riverpod.\n',
                  ),
                  const TextSpan(
                    text: '• Beautiful Apple-style animations and widgets.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© 2026 SlickPort Project. All rights reserved.',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFF0F4FF)
                            : const Color(0xFF1C1C1E),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : const Color(0xFFC7C7CC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── EASTER EGG DRAWER & TAPE CARDS ──────────────────────────────────────────

class _EasterEggDrawer extends StatelessWidget {
  const _EasterEggDrawer({
    required this.controller,
    required this.dragOffsetNotifier,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.passports,
    required this.idDocs,
    required this.tickets,
    required this.onAddPassport,
    required this.onAddId,
  });

  final AnimationController controller;
  final ValueNotifier<double> dragOffsetNotifier;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final List<MockTicket> tickets;
  final VoidCallback onAddPassport;
  final void Function(IdDocumentType) onAddId;

  @override
  Widget build(BuildContext context) {
    final double panelHeight = 246.0;
    final String currentName = passports.isNotEmpty ? passports.first.name : '';
    final firstName = currentName.isEmpty ? 'Traveller' : currentName.split(' ').first;

    final int hour = DateTime.now().hour;
    final bool isNight = hour < 6 || hour > 18;
    final IconData weatherIcon = isNight ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded;
    final Color weatherIconColor = isNight ? const Color(0xFF8E9AA6) : const Color(0xFFFFD700);
    final String weatherCondition = isNight ? 'Clear Night • 18°C' : 'Bright Sunny Day • 24°C';
    final String weatherPhrase = isNight
        ? "It's a calm, clear night. A great time to review your travel plans."
        : "It's a bright, sunny day. Perfect day to step out and travel!";

    return GestureDetector(
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Container(
        width: double.infinity,
        height: panelHeight + 150.0,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081A36), Color(0xFF030811)], // Deep space midnight navy gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Container(
            height: panelHeight,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            child: ValueListenableBuilder<double>(
              valueListenable: dragOffsetNotifier,
              builder: (context, offsetY, _) {
                // Calculate progress t from 0.0 to 1.0 based on snap threshold (246px)
                final double t = (offsetY / panelHeight).clamp(0.0, 1.0);

                // 1. Greeting progress: reveals from t=0.1 to t=0.6
                final double tGreeting = ((t - 0.1) / 0.5).clamp(0.0, 1.0);
                final double opacityGreeting = tGreeting;
                final double yGreeting = (1.0 - tGreeting) * 12.0;

                // 2. Stats progress: reveals from t=0.25 to t=0.75
                final double tStats = ((t - 0.25) / 0.5).clamp(0.0, 1.0);
                final double opacityStats = tStats;
                final double yStats = (1.0 - tStats) * 12.0;

                // 3. Weather progress: reveals from t=0.4 to t=0.9
                final double tWeather = ((t - 0.4) / 0.5).clamp(0.0, 1.0);
                final double opacityWeather = tWeather;
                final double yWeather = (1.0 - tWeather) * 16.0;
                final double scaleWeather = 0.95 + (0.05 * tWeather);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Greeting
                    Opacity(
                      opacity: opacityGreeting,
                      child: Transform.translate(
                        offset: Offset(0, yGreeting),
                        child: Text(
                          'Hey, $firstName',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Natural language conversational stats
                    Opacity(
                      opacity: opacityStats,
                      child: Transform.translate(
                        offset: Offset(0, yStats),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'You have '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(Icons.wallet_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                ),
                              ),
                              TextSpan(
                                text: '${passports.length + idDocs.length} items',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const TextSpan(text: ' in your wallet,\n'),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(Icons.flight_takeoff_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                ),
                              ),
                              TextSpan(
                                text: '${tickets.where((t) => t.status == TicketStatus.active).length} active trips',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const TextSpan(text: ', and '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(Icons.offline_pin_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                ),
                              ),
                              const TextSpan(
                                text: 'all data offline.',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8DA2C4),
                            fontSize: 15,
                            height: 1.45,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Weather Section (replaces the card miniatures)
                    Opacity(
                      opacity: opacityWeather,
                      child: Transform.translate(
                        offset: Offset(0, yWeather),
                        child: Transform.scale(
                          scale: scaleWeather,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Glow Sun/Moon Icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: weatherIconColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    weatherIcon,
                                    color: weatherIconColor,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        weatherCondition,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        weatherPhrase,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF8DA2C4),
                                          fontSize: 13,
                                          height: 1.3,
                                          letterSpacing: -0.1,
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
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── IOS CONTEXT MENU ────────────────────────────────────────────────────────

class _IosMenuPickerExpanded extends StatefulWidget {
  const _IosMenuPickerExpanded({
    required this.link,
    required this.visible,
    required this.currentMode,
    required this.openedMode,
    required this.onSelectMode,
    required this.onClose,
  });

  final LayerLink link;
  final bool visible;
  final DashboardViewMode currentMode;
  final DashboardViewMode openedMode;
  final ValueChanged<DashboardViewMode> onSelectMode;
  final VoidCallback onClose;

  @override
  State<_IosMenuPickerExpanded> createState() => _IosMenuPickerExpandedState();
}

class _IosMenuPickerExpandedState extends State<_IosMenuPickerExpanded>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _shouldRender = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    if (widget.visible) {
      _shouldRender = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _IosMenuPickerExpanded oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        setState(() {
          _shouldRender = true;
        });
        _controller.forward();
      } else {
        _controller.reverse().then((_) {
          if (mounted && !widget.visible) {
            setState(() {
              _shouldRender = false;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldRender) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color menuBg = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.82);

    final Color textColor = isDark
        ? const Color(0xFFF0F4FF)
        : const Color(0xFF1C1C1E);

    // List of modes
    const modes = [
      DashboardViewMode.manage,
      DashboardViewMode.home,
      DashboardViewMode.trash,
    ];

    // Find current index
    final int selectedIndex = modes.indexOf(widget.currentMode);

    return CompositedTransformFollower(
      link: widget.link,
      showWhenUnlinked: false,
      offset: const Offset(-16.0, -14.0),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              alignment: Alignment.topLeft,
              child: child,
            ),
          );
        },
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            color: menuBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(
                children: [
                  // Sliding highlight pill background
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    top: 8.0 + selectedIndex * 56.0 + 2.0,
                    left: 8.0,
                    right: 8.0,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  // List items
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: modes.map((mode) {
                        final bool isActive = widget.currentMode == mode;
                        final String title;
                        switch (mode) {
                          case DashboardViewMode.home:
                            title = 'Home';
                            break;
                          case DashboardViewMode.manage:
                            title = 'Manage';
                            break;
                          case DashboardViewMode.trash:
                            title = 'Trash';
                            break;
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onSelectMode(mode);
                          },
                          child: Container(
                            height: 56,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: GoogleFonts.inter(
                                color: isActive
                                    ? textColor
                                    : textColor.withValues(alpha: 0.35),
                                fontSize: 28,
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                letterSpacing: -1.0,
                              ),
                              child: Text(title),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─── MANAGE CARDS VIEW ───────────────────────────────────────────────────────

class _ManageCardsView extends ConsumerWidget {
  const _ManageCardsView({
    super.key,
    required this.items,
  });

  final List<Object> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.creditcard,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No Cards in Wallet',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1C1C1E),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: ReorderableListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) {
          HapticFeedback.lightImpact();
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final List<String> currentIds = items.map((item) {
            return item is PassportProfile ? item.id : (item as IdDocument).id;
          }).toList();

          final String movedId = currentIds.removeAt(oldIndex);
          currentIds.insert(newIndex, movedId);
          ref.read(walletOrderProvider.notifier).saveOrder(currentIds);
        },
        itemBuilder: (context, index) {
          final item = items[index];
          final String id = item is PassportProfile ? item.id : (item as IdDocument).id;

          return _ManageCardTile(
            key: ValueKey(id),
            item: item,
            index: index,
          );
        },
      ),
    );
  }
}

class _ManageCardTile extends StatelessWidget {
  const _ManageCardTile({
    super.key,
    required this.item,
    required this.index,
  });

  final Object item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String title;
    final String subtitle;
    final IconData icon;
    final Color iconColor;

    if (item is PassportProfile) {
      final p = item as PassportProfile;
      title = p.name.isEmpty ? 'Passport' : "${p.name.split(' ').first}'s Passport";
      subtitle = p.passportNumber.isEmpty ? 'Passport' : p.passportNumber;
      icon = CupertinoIcons.book;
      iconColor = const Color(0xFF4C7CFF);
    } else {
      final d = item as IdDocument;
      title = d.holderName.isEmpty
          ? (d.type == IdDocumentType.pan ? 'PAN Card' : 'Aadhaar Card')
          : "${d.holderName.split(' ').first}'s ID";
      subtitle = d.documentNumber;
      icon = CupertinoIcons.creditcard;
      iconColor = const Color(0xFF19D3C5);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFF1C1C1E).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFF1C1C1E).withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8E8E93),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              CupertinoIcons.bars,
              color: isDark ? Colors.white30 : Colors.black26,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── TRASH VIEW ──────────────────────────────────────────────────────────────

class _TrashView extends ConsumerWidget {
  const _TrashView({super.key});

  void _showConfirmDeleteDialog(BuildContext context, WidgetRef ref, Object item) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text(
          'This card will be permanently deleted from your offline wallet and cannot be restored.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              ref.read(trashProvider.notifier).permanentlyDeleteItem(item);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trashState = ref.watch(trashProvider);
    final List<Object> items = [...trashState.passports, ...trashState.idDocs];

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.trash,
                size: 36,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Trash is Empty',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1C1C1E),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Items removed from your wallet are stored here until restored or deleted permanently.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8E8E93),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _TrashCardTile(
          item: item,
          onRestore: () {
            ref.read(trashProvider.notifier).restoreItem(item, ref);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  item is PassportProfile ? 'Passport restored to wallet' : 'ID Document restored to wallet',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onDelete: () => _showConfirmDeleteDialog(context, ref, item),
        );
      },
    );
  }
}

class _TrashCardTile extends StatelessWidget {
  const _TrashCardTile({
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });

  final Object item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String title;
    final String subtitle;
    final IconData icon;
    final Color iconColor;

    if (item is PassportProfile) {
      final p = item as PassportProfile;
      title = p.name.isEmpty ? 'Passport' : "${p.name.split(' ').first}'s Passport";
      subtitle = p.passportNumber.isEmpty ? 'Passport' : p.passportNumber;
      icon = CupertinoIcons.book;
      iconColor = const Color(0xFF4C7CFF);
    } else {
      final d = item as IdDocument;
      title = d.holderName.isEmpty
          ? (d.type == IdDocumentType.pan ? 'PAN Card' : 'Aadhaar Card')
          : "${d.holderName.split(' ').first}'s ID";
      subtitle = d.documentNumber;
      icon = CupertinoIcons.creditcard;
      iconColor = const Color(0xFF19D3C5);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFF1C1C1E).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFF1C1C1E).withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8E8E93),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BounceTap(
              onTap: onRestore,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C7CFF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_counterclockwise,
                  size: 18,
                  color: Color(0xFF4C7CFF),
                ),
              ),
            ),
            const SizedBox(width: 8),
            BounceTap(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF453A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: Color(0xFFFF453A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





