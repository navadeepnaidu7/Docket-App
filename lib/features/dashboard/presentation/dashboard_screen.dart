import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';

import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../ids/presentation/add_id_sheet.dart';
import '../../ids/presentation/id_entry_screen.dart';
import '../../passport/application/passport_draft_controller.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../passport/presentation/passport_entry_screen.dart';
import '../../tickets/presentation/tickets_tab.dart';
import '../../tickets/presentation/wallet_ticket_card.dart';
import '../../../core/wallet/wallet_backdrop_tilt.dart';
import '../../../core/wallet/wallet_filter.dart';
import '../../../core/wallet/wallet_items.dart';
import '../application/wallet_filter_provider.dart';
import '../application/trash_provider.dart';
import '../application/wallet_order_provider.dart';

// Modular widgets imports
import 'widgets/add_fab.dart';
import 'widgets/add_item_sheet.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/easter_egg_constants.dart';
import 'widgets/easter_egg_drawer.dart';
import 'widgets/easter_egg_sheet_motion.dart';
import 'widgets/ids_tab.dart';
import 'widgets/manage_cards_view.dart';
import 'widgets/pill_tab_bar.dart';
import 'settings_screen.dart';
import 'widgets/trash_view.dart';
import 'widgets/view_picker.dart';
import 'widgets/wallet_backdrop.dart';

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
  late final WalletBackdropTilt _backdropTilt;
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
    _backdropTilt = WalletBackdropTilt();
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
      duration: kEasterEggSnapDuration,
    );
    _easterEggCtrl.addListener(() {
      if (!_isDragging) {
        _easterEggOffset.value = _easterEggCtrl.value * kEasterEggPanelHeight;
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
    _backdropTilt.dispose();
    _easterEggCtrl.dispose();
    _easterEggOffset.dispose();
    _showHomeMenu.dispose();
    _viewMode.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _isDragging = true;
    final double delta = details.primaryDelta ?? 0;
    _dragOffset += delta * kEasterEggDragDamping;

    final double panelHeight = kEasterEggPanelHeight;
    double effective = _dragOffset;
    if (_dragOffset > panelHeight) {
      final double overshoot = _dragOffset - panelHeight;
      effective = panelHeight + (overshoot * kEasterEggDrawerOvershootFactor);
    } else if (_dragOffset < 0) {
      effective = 0;
    }
    _easterEggOffset.value = effective;
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    final double panelHeight = kEasterEggPanelHeight;
    final double currentOffset = _easterEggOffset.value;
    final double velocityY = details.velocity.pixelsPerSecond.dy;
    final bool open = EasterEggSheetMotion.shouldSnapOpen(
      offsetY: currentOffset,
      velocityY: velocityY,
    );

    final double startProgress =
        (currentOffset / panelHeight).clamp(0.0, 1.0);
    _easterEggCtrl.stop();
    _easterEggCtrl.value = startProgress;
    _easterEggCtrl.animateTo(
      open ? 1.0 : 0.0,
      curve: open ? Curves.easeOutQuint : Curves.easeOutCubic,
    );

    if (open && startProgress < 0.9) {
      HapticService.select();
    } else if (!open && startProgress > 0.1) {
      HapticService.tap();
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
    HapticService.confirm();
    if (_tabCtrl.index == 0) {
      // Docs tab — choose Passport or ID
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddItemSheet(
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
        builder: (_) => const TicketsComingSoonSheet(),
      );
    }
  }

  void _showPassportTypeSheet() {
    HapticService.confirm();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PassportTypeSheet(
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

  bool _ordersEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _openSettings() {
    HapticService.confirm();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }


  void _showDeleteDialog(PassportProfile profile) {
    HapticService.destructive();
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
    HapticService.destructive();
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

    final activeIds = activeWalletItemIds(passports: passports, idDocs: idDocs);
    final reconciledOrder = reconcileWalletOrder(order: order, activeIds: activeIds);
    if (reconciledOrder.length != order.length ||
        !_ordersEqual(reconciledOrder, order)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(walletOrderProvider.notifier).saveOrder(reconciledOrder);
      });
    }

    final List<Object> items = sortWalletItems(
      passports: passports,
      idDocs: idDocs,
      order: reconciledOrder,
    );

    final bool filterEnabled = ref.watch(walletFilterEnabledProvider);
    WalletFilterCategory filterCategory =
        ref.watch(walletFilterCategoryProvider);
    final List<WalletFilterCategory> filterOptions =
        walletFilterOptionsFor(items);
    if (filterEnabled &&
        !filterOptions.contains(filterCategory)) {
      filterCategory = WalletFilterCategory.all;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(walletFilterCategoryProvider.notifier).resetToAll();
      });
    }

    final List<Object> displayItems = filterEnabled
        ? filterWalletItems(items: items, category: filterCategory)
        : items;

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
                final EasterEggSheetMotion motion =
                    EasterEggSheetMotion.lerpFromOffset(offsetY);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Easter Egg Drawer (positioned in background with parallax)
                    Positioned(
                      top: motion.drawerTop,
                      left: 0,
                      right: 0,
                      height: kEasterEggPanelHeight + 150.0,
                      child: drawerWidget!,
                    ),
                    // 2. Main Sliding Sheet (translated down, rounded at top)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, motion.sheetOffsetY),
                        child: Transform.scale(
                          scale: motion.sheetScale,
                          alignment: Alignment.topCenter,
                          child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(motion.topRadius),
                            ),
                            boxShadow: motion.shadowOpacity > 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: motion.shadowOpacity),
                                      blurRadius: 16,
                                      offset: const Offset(0, -6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 8,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: motion.pullPillOpacity,
                                    child: Center(
                                      child: Container(
                                        width: 36,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                                  .withValues(alpha: 0.28)
                                              : Colors.black
                                                  .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(99),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Background: gradient orbs on Home, flat surface elsewhere
                              ValueListenableBuilder<DashboardViewMode>(
                                valueListenable: _viewMode,
                                builder: (context, mode, _) {
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: mode == DashboardViewMode.home
                                        ? RepaintBoundary(
                                            key: const ValueKey('gradient_backdrop'),
                                            child: WalletBackdrop(
                                              tabIndex: _tabCtrl.index,
                                              items: displayItems,
                                              pageNotifier: _docPage,
                                              tiltNotifier: _backdropTilt,
                                            ),
                                          )
                                        : ColoredBox(
                                            key: ValueKey('flat_backdrop_${mode.name}'),
                                            color: Theme.of(context).scaffoldBackgroundColor,
                                          ),
                                  );
                                },
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
                                                    return DashboardHeader(
                                                      name: currentName,
                                                      isMenuOpen: isMenuOpen,
                                                      currentMode: currentMode,
                                                      onHomeTap: () {
                                                        _showHomeMenu.value = !_showHomeMenu.value;
                                                      },
                                                      onAvatarTap: _openSettings,
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
                                                    IdsTab(
                                                      items: displayItems,
                                                      allItems: items,
                                                      onDeletePassport: _showDeleteDialog,
                                                      onDeleteId: _showDeleteIdDialog,
                                                      pageNotifier: _docPage,
                                                      backdropTilt: _backdropTilt,
                                                    ),
                                                    const TicketsTab(),
                                                  ],
                                                );
                                                break;
                                              case DashboardViewMode.manage:
                                                viewChild = ManageCardsView(
                                                  key: const ValueKey('manage_view'),
                                                  items: items,
                                                );
                                                break;
                                              case DashboardViewMode.trash:
                                                viewChild = const TrashView(
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
                              // Custom expanded view picker
                              ValueListenableBuilder<bool>(
                                valueListenable: _showHomeMenu,
                                builder: (context, show, child) {
                                  return ValueListenableBuilder<DashboardViewMode>(
                                    valueListenable: _viewMode,
                                    builder: (context, currentMode, _) {
                                      return ViewPickerExpanded(
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
                    ),
                  ],
                );
              },
              child: EasterEggDrawer(
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
            ValueListenableBuilder<double>(
              valueListenable: _easterEggOffset,
              builder: (context, offsetY, pillChild) {
                final EasterEggSheetMotion motion =
                    EasterEggSheetMotion.lerpFromOffset(offsetY);
                return ValueListenableBuilder<DashboardViewMode>(
                  valueListenable: _viewMode,
                  builder: (context, mode, child) {
                    final bool isHome = mode == DashboardViewMode.home;
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      bottom: isHome ? 0 : -100,
                      left: 0,
                      right: 0,
                      child: Transform.translate(
                        offset: Offset(0, motion.pillBarOffsetY),
                        child: Opacity(
                          opacity: motion.pillBarOpacity,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: pillChild,
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
                    PillTabBar(controller: _tabCtrl),
                    const SizedBox(width: 10),
                    AddFab(onTap: _showAddSheet),
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
