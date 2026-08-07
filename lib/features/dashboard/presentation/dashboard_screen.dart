import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';

import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../ids/presentation/add_id_sheet.dart';
import '../../ids/presentation/id_entry_screen.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../passport/presentation/passport_prompt_screen.dart';
import '../../tickets/presentation/tickets_tab.dart';

import '../../../core/wallet/wallet_backdrop_tilt.dart';
import '../../../core/wallet/wallet_filter.dart';
import '../../../core/wallet/wallet_items.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../application/auth_session_provider.dart';
import '../application/passes_history_provider.dart';
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
import 'widgets/membership_mesh.dart';
import 'widgets/pill_tab_bar.dart';
import 'settings_screen.dart';
import 'widgets/trash_view.dart';
import 'widgets/view_picker.dart';
import 'widgets/wallet_backdrop.dart';

enum DashboardViewMode { home, manage, trash }

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
  final ValueNotifier<DashboardViewMode> _viewMode = ValueNotifier(
    DashboardViewMode.home,
  );
  double _dragOffset = 0.0;
  bool _isDragging = false;

  final LayerLink _headerTitleLink = LayerLink();
  DashboardViewMode _openedMode = DashboardViewMode.home;

  /// Passes tab is heavy — prewarm after first paint; kept under [_HomeTabTransition].
  bool _passesTabMounted = false;
  int _lastTabIndex = 0;

  void _onMenuToggle() {
    if (_showHomeMenu.value) {
      setState(() {
        _openedMode = _viewMode.value;
      });
    }
  }

  void _onTabChanged() {
    // Content transition is driven by controller.animation (no rebuild needed).
    // Rebuild when the index flips so backdrop tint / prewarm stay in sync.
    final bool indexChanged = _tabCtrl.index != _lastTabIndex;
    if (_tabCtrl.index == 1 && !_passesTabMounted) {
      _passesTabMounted = true;
      _lastTabIndex = _tabCtrl.index;
      setState(() {});
      return;
    }
    if (indexChanged) {
      _lastTabIndex = _tabCtrl.index;
      setState(() {});
    }
  }

  void _prewarmPassesTab() {
    if (!mounted || _passesTabMounted) return;
    setState(() => _passesTabMounted = true);
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
    _tabCtrl.addListener(_onTabChanged);
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

    // After home paints, warm Passes when the scheduler is idle so the first
    // IDs → Passes switch is just an IndexedStack index flip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.scheduleTask(_prewarmPassesTab, Priority.idle);
    });
  }

  @override
  void dispose() {
    _showHomeMenu.removeListener(_onMenuToggle);
    _tabCtrl.removeListener(_onTabChanged);
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
    // Keep the sheet under the finger 1:1. Only the part beyond the resting
    // position is rubber-banded, which makes reversals feel immediate.
    _dragOffset += delta;
    if (_dragOffset < 0) _dragOffset = 0;

    final double panelHeight = kEasterEggPanelHeight;
    double effective = _dragOffset;
    if (_dragOffset > panelHeight) {
      final double overshoot = _dragOffset - panelHeight;
      effective =
          panelHeight +
          ((overshoot * kEasterEggDrawerOvershootFactor * panelHeight) /
              (panelHeight + kEasterEggDrawerOvershootFactor * overshoot));
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

    final double startProgress = (currentOffset / panelHeight).clamp(0.0, 1.0);
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
    // The kind is passed to the screen rather than set as a side effect on a
    // shared draft beforehand: the chip route only exists for an e-passport,
    // and the old screen ignored this answer and offered NFC either way.
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => PassportPromptScreen(
          kind: isEPassport ? PassportKind.ePassport : PassportKind.regular,
        ),
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
    // Never leave the home-menu barrier open under a pushed route.
    if (_showHomeMenu.value) {
      _showHomeMenu.value = false;
    }
    // Same modal transition as pass/ticket card detail (slide up / dismiss down).
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const SettingsScreen(),
      ),
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
              ref
                  .read(passportListProvider.notifier)
                  .removePassport(profile.id);
              ref.read(trashProvider.notifier).moveToTrash(profile);
              ref
                  .read(walletOrderProvider.notifier)
                  .updateOrderOnItemRemoved(profile.id);
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
              ref
                  .read(walletOrderProvider.notifier)
                  .updateOrderOnItemRemoved(doc.id);
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
    final reconciledOrder = reconcileWalletOrder(
      order: order,
      activeIds: activeIds,
    );
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
    WalletFilterCategory filterCategory = ref.watch(
      walletFilterCategoryProvider,
    );
    final List<WalletFilterCategory> filterOptions = walletFilterOptionsFor(
      items,
    );
    if (filterEnabled && !filterOptions.contains(filterCategory)) {
      filterCategory = WalletFilterCategory.all;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(walletFilterCategoryProvider.notifier).resetToAll();
      });
    }

    final List<Object> displayItems = filterEnabled
        ? filterWalletItems(items: items, category: filterCategory)
        : items;

    final AuthSession session = ref.watch(authSessionProvider);
    final String meshSeed = _profileMeshSeed(
      session: session,
      passports: passports,
      idDocs: idDocs,
    );
    final List<Color> meshWashes = walletWashColors(
      passports: passports,
      idDocs: idDocs,
      scheme: ref.watch(devFlagsProvider).cardFluidScheme,
    );
    final bool historySelected = ref.watch(passesHistoryFilterProvider);

    // Continuous backdrop / card animations keep burning GPU while Settings (or
    // any other route) covers the dashboard. Mute tickers while covered so the
    // pop transition does not double-paint two full animated trees — that was
    // hanging the UI after returning from Settings on mid-range Android.
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final Animation<double>? secondary = route?.secondaryAnimation;

    Widget scaffold = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: Stack(
          children: <Widget>[
            ValueListenableBuilder<double>(
              valueListenable: _easterEggOffset,
              builder: (context, offsetY, _) {
                final EasterEggSheetMotion motion =
                    EasterEggSheetMotion.lerpFromOffset(offsetY);
                final bool showEasterEgg =
                    offsetY > 0.5 || _easterEggCtrl.isAnimating;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Easter Egg Drawer — only mount when pulled open.
                    if (showEasterEgg)
                      Positioned(
                        top: motion.drawerTop,
                        left: 0,
                        right: 0,
                        height: kEasterEggPanelHeight + 150.0,
                        child: EasterEggDrawer(
                          controller: _easterEggCtrl,
                          dragOffsetNotifier: _easterEggOffset,
                          onDragUpdate: _handleDragUpdate,
                          onDragEnd: _handleDragEnd,
                          passports: passports,
                          idDocs: idDocs,
                          onAddPassport: _showPassportTypeSheet,
                          onAddId: _openIdEntry,
                        ),
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
                                        color: Colors.black.withValues(
                                          alpha: motion.shadowOpacity,
                                        ),
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
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white.withValues(
                                                    alpha: 0.28,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.16,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
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
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: mode == DashboardViewMode.home
                                          ? RepaintBoundary(
                                              key: const ValueKey(
                                                'gradient_backdrop',
                                              ),
                                              child: WalletBackdrop(
                                                tabIndex: _tabCtrl.index,
                                                items: displayItems,
                                                pageNotifier: _docPage,
                                                tiltNotifier: _backdropTilt,
                                              ),
                                            )
                                          : ColoredBox(
                                              key: ValueKey(
                                                'flat_backdrop_${mode.name}',
                                              ),
                                              color: Theme.of(
                                                context,
                                              ).scaffoldBackgroundColor,
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
                                            onVerticalDragUpdate:
                                                _handleDragUpdate,
                                            onVerticalDragEnd: _handleDragEnd,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    20,
                                                    20,
                                                    20,
                                                    0,
                                                  ),
                                              child: ValueListenableBuilder<bool>(
                                                valueListenable: _showHomeMenu,
                                                builder: (context, isMenuOpen, _) {
                                                  return ValueListenableBuilder<
                                                    DashboardViewMode
                                                  >(
                                                    valueListenable: _viewMode,
                                                    builder:
                                                        (
                                                          context,
                                                          currentMode,
                                                          _,
                                                        ) {
                                                          final bool onPasses =
                                                              _tabCtrl.index ==
                                                              1;
                                                          final bool showHistory =
                                                              currentMode ==
                                                                  DashboardViewMode
                                                                      .home &&
                                                              onPasses;
                                                          return DashboardHeader(
                                                            meshSeed: meshSeed,
                                                            washes: meshWashes,
                                                            isMenuOpen:
                                                                isMenuOpen,
                                                            currentMode:
                                                                currentMode,
                                                            onHomeTap: () {
                                                              _showHomeMenu
                                                                      .value =
                                                                  !_showHomeMenu
                                                                      .value;
                                                            },
                                                            onAvatarTap:
                                                                _openSettings,
                                                            headerTitleLink:
                                                                _headerTitleLink,
                                                            showHistoryButton:
                                                                showHistory,
                                                            historySelected:
                                                                historySelected,
                                                            onHistoryTap:
                                                                showHistory
                                                                ? () {
                                                                    ref
                                                                        .read(
                                                                          passesHistoryFilterProvider
                                                                              .notifier,
                                                                        )
                                                                        .state = !ref
                                                                        .read(
                                                                          passesHistoryFilterProvider,
                                                                        );
                                                                  }
                                                                : null,
                                                          );
                                                        },
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          // Tab content
                                          ValueListenableBuilder<
                                            DashboardViewMode
                                          >(
                                            valueListenable: _viewMode,
                                            builder: (context, mode, _) {
                                              Widget viewChild;
                                              switch (mode) {
                                                case DashboardViewMode.home:
                                                  viewChild = KeyedSubtree(
                                                    key: const ValueKey(
                                                      'home_view',
                                                    ),
                                                    child: _HomeTabTransition(
                                                      controller: _tabCtrl,
                                                      ids: IdsTab(
                                                        items: displayItems,
                                                        allItems: items,
                                                        onDeletePassport:
                                                            _showDeleteDialog,
                                                        onDeleteId:
                                                            _showDeleteIdDialog,
                                                        pageNotifier: _docPage,
                                                        backdropTilt:
                                                            _backdropTilt,
                                                      ),
                                                      passes: _passesTabMounted
                                                          ? const TicketsTab()
                                                          : const SizedBox.expand(),
                                                    ),
                                                  );
                                                  break;
                                                case DashboardViewMode.manage:
                                                  viewChild = ManageCardsView(
                                                    key: const ValueKey(
                                                      'manage_view',
                                                    ),
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
                                                  duration: const Duration(
                                                    milliseconds: 350,
                                                  ),
                                                  switchInCurve:
                                                      Curves.easeOutCubic,
                                                  switchOutCurve:
                                                      Curves.easeInCubic,
                                                  transitionBuilder:
                                                      (child, animation) {
                                                        return FadeTransition(
                                                          opacity: animation,
                                                          child: SlideTransition(
                                                            position:
                                                                Tween<Offset>(
                                                                  begin:
                                                                      const Offset(
                                                                        0,
                                                                        0.04,
                                                                      ),
                                                                  end: Offset
                                                                      .zero,
                                                                ).animate(
                                                                  animation,
                                                                ),
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
                                        onTap: () =>
                                            _showHomeMenu.value = false,
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
                                    return ValueListenableBuilder<
                                      DashboardViewMode
                                    >(
                                      valueListenable: _viewMode,
                                      builder: (context, currentMode, _) {
                                        return ViewPickerExpanded(
                                          link: _headerTitleLink,
                                          visible: show,
                                          currentMode: currentMode,
                                          openedMode: _openedMode,
                                          onSelectMode: (mode) {
                                            _viewMode.value = mode;
                                            Future.delayed(
                                              const Duration(milliseconds: 280),
                                              () {
                                                if (mounted) {
                                                  _showHomeMenu.value = false;
                                                }
                                              },
                                            );
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

    if (secondary == null) return scaffold;

    return AnimatedBuilder(
      animation: secondary,
      builder: (BuildContext context, Widget? child) {
        final bool covered =
            secondary.value > 0.0 || !(route?.isCurrent ?? true);
        return TickerMode(enabled: !covered, child: child!);
      },
      child: scaffold,
    );
  }
}

/// Stable seed for the top-bar mesh: prefer account identity, then wallet docs.
String _profileMeshSeed({
  required AuthSession session,
  required List<PassportProfile> passports,
  required List<IdDocument> idDocs,
}) {
  final String? email = session.email?.trim();
  if (email != null && email.isNotEmpty) return email.toLowerCase();
  final String? accountName = session.displayName?.trim();
  if (accountName != null && accountName.isNotEmpty) {
    return accountName.toLowerCase();
  }
  if (passports.isNotEmpty) {
    final PassportProfile p = passports.first;
    final String n = p.name.trim();
    if (n.isNotEmpty) return '${p.id}:$n';
    return p.id;
  }
  if (idDocs.isNotEmpty) {
    final IdDocument d = idDocs.first;
    final String n = d.holderName.trim();
    if (n.isNotEmpty) return '${d.id}:$n';
    return d.id;
  }
  return 'docket-guest';
}

/// Crossfade + soft lateral slide between IDs and Passes, locked to the
/// same [TabController] animation the nav pill uses.
class _HomeTabTransition extends StatelessWidget {
  const _HomeTabTransition({
    required this.controller,
    required this.ids,
    required this.passes,
  });

  final TabController controller;
  final Widget ids;
  final Widget passes;

  static const double _slidePx = 28;

  @override
  Widget build(BuildContext context) {
    final Animation<double> anim = controller.animation!;

    return AnimatedBuilder(
      animation: anim,
      builder: (BuildContext context, _) {
        final double t = anim.value.clamp(0.0, 1.0);
        // Ease the handoff so mid-transition feels softer than linear fade.
        final double fadeOut = Curves.easeOutCubic.transform(1.0 - t);
        final double fadeIn = Curves.easeOutCubic.transform(t);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // IDs — exit left + fade
            IgnorePointer(
              ignoring: t > 0.5,
              child: Opacity(
                opacity: fadeOut,
                child: Transform.translate(
                  offset: Offset(-_slidePx * t, 0),
                  child: ids,
                ),
              ),
            ),
            // Passes — enter from right + fade
            IgnorePointer(
              ignoring: t < 0.5,
              child: Opacity(
                opacity: fadeIn,
                child: Transform.translate(
                  offset: Offset(_slidePx * (1.0 - t), 0),
                  child: passes,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
