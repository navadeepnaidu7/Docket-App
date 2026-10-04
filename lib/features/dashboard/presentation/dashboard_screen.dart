import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/storage/secure_document_store.dart';
import '../../../core/motion/smooth_curves.dart';
import '../../../core/motion/studio_page_route.dart';

import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../ids/application/attachment_open_service.dart';
import '../../ids/application/attachment_providers.dart';
import '../../ids/presentation/attachments/id_attachment_sheet.dart';
import '../../ids/presentation/id_entry_screen.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../passport/presentation/passport_prompt_screen.dart';
import '../../tickets/application/pass_ingest_controller.dart';
import '../../tickets/application/pass_share_service.dart';
import '../../tickets/presentation/add/add_pass_flow.dart';
import '../../tickets/presentation/history/passes_archive_screen.dart';
import '../../tickets/presentation/tickets_tab.dart';

import '../../../core/wallet/wallet_backdrop_tilt.dart';
import '../../../core/wallet/wallet_filter.dart';
import '../../../core/wallet/wallet_items.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../application/auth_session_provider.dart';
import '../application/search_button_provider.dart';
import '../application/wallet_filter_provider.dart';
import '../application/trash_provider.dart';
import '../application/wallet_order_provider.dart';
import '../application/wallet_loading_provider.dart';

// Modular widgets imports
import 'widgets/add_fab.dart';
import '../../passport/presentation/widgets/passport_cover_art.dart';
import 'widgets/add_menu.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/easter_egg_constants.dart';
import '../../weather/presentation/local_weather_drawer.dart';
import 'widgets/travel_weather_glance.dart';
import 'widgets/easter_egg_sheet_motion.dart';
import 'widgets/ids_tab.dart';
import 'widgets/manage_cards_view.dart';
import 'widgets/membership_mesh.dart';
import 'widgets/pill_tab_bar.dart';
import 'settings_route.dart';
import 'wallet_search_screen.dart';
import 'widgets/trash_view.dart';
import 'widgets/view_picker.dart';
import 'widgets/wallet_backdrop.dart';
import 'widgets/weather_reveal_surface.dart';

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

  /// Wallet item id that Home should page to, set when a Manage row is tapped.
  ///
  /// Carried as an id rather than an index because the index Manage knows is
  /// into the unfiltered list, while [IdsTab] pages through the filtered one.
  /// [IdsTab] clears this once the jump lands.
  final ValueNotifier<String?> _revealItemId = ValueNotifier<String?>(null);

  double get _weatherPanelHeight =>
      weatherPanelHeight(MediaQuery.textScalerOf(context).scale(14) / 14);

  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _weatherWasOpen = false;

  final LayerLink _headerTitleLink = LayerLink();
  DashboardViewMode _openedMode = DashboardViewMode.home;

  /// Passes tab is heavy — prewarm after first paint; kept under [_HomeTabTransition].
  bool _passesTabMounted = false;
  Timer? _warmUpTimer;
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
    // Clears any decrypted copy left in the cache by an external PDF view that
    // was interrupted before the sheet could close.
    AttachmentOpenService.purge();
    // Same, for the PNG a share hands to another app. That file deliberately
    // outlives its share sheet -- the receiver may still be reading it -- so
    // app start is where its lifetime ends.
    PassShareService.purge();
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
    _easterEggCtrl = AnimationController.unbounded(
      vsync: this,
      duration: kEasterEggSnapDuration,
    );
    _easterEggCtrl.addListener(() {
      if (!_isDragging) {
        _easterEggOffset.value = (_easterEggCtrl.value * _weatherPanelHeight)
            .clamp(0.0, double.infinity);
        _dragOffset = _easterEggOffset.value;
      }
    });
    _entryCtrl.forward();

    // Let the opening animation finish before mounting a hidden tab or parsing
    // optional artwork. Idle scheduler tasks can starve under continuous
    // animation and spin the widget-test event loop. A cancellable timer also
    // makes closing the dashboard during startup safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _warmUpTimer = Timer(_entryCtrl.duration!, () {
        if (!mounted) return;
        _prewarmPassesTab();
        // Active documents get the keystore first. Trash and orphan scanning
        // are maintenance and must not compete with the initial wallet reads.
        unawaited(sweepAttachmentOrphans(ref));
        unawaited(_warmOptionalArtwork());
      });
    });
  }

  Future<void> _warmOptionalArtwork() async {
    try {
      await PassportCoverArt.warmUp();
      if (mounted) await TravelWeatherGlance.warmUp();
    } catch (_) {
      // A failed prefetch must not turn a successful launch into an async error.
      // The actual screen can retry loading the asset when it is opened.
    }
  }

  @override
  void dispose() {
    _warmUpTimer?.cancel();
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
    _revealItemId.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_isDragging) {
      _weatherWasOpen = _easterEggOffset.value >= _weatherPanelHeight * 0.75;
      _easterEggCtrl.stop();
      _dragOffset = EasterEggSheetMotion.rawOffsetForVisible(
        _easterEggOffset.value,
        panelHeight: _weatherPanelHeight,
      );
    }
    _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) _handleDragStart(DragStartDetails());
    final double delta = details.primaryDelta ?? 0;
    // Keep the sheet under the finger 1:1. Only the part beyond the resting
    // position is rubber-banded, which makes reversals feel immediate.
    _dragOffset += delta;
    if (_dragOffset < 0) _dragOffset = 0;

    _easterEggOffset.value = EasterEggSheetMotion.rubberBandOffset(
      _dragOffset,
      panelHeight: _weatherPanelHeight,
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    final double panelHeight = _weatherPanelHeight;
    final double currentOffset = _easterEggOffset.value;
    final double velocityY = EasterEggSheetMotion.releaseVelocity(
      rawOffset: _dragOffset,
      velocityY: details.velocity.pixelsPerSecond.dy,
      panelHeight: panelHeight,
    );
    final bool open = EasterEggSheetMotion.shouldSnapOpen(
      offsetY: currentOffset,
      velocityY: velocityY,
      panelHeight: _weatherPanelHeight,
      wasOpen: _weatherWasOpen,
    );

    final double startProgress = currentOffset / panelHeight;
    _easterEggCtrl.stop();
    _easterEggCtrl.value = startProgress;
    if (MediaQuery.disableAnimationsOf(context)) {
      _easterEggCtrl.value = open ? 1 : 0;
    } else {
      _easterEggCtrl.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 150, damping: 25),
          startProgress,
          open ? 1 : 0,
          // A rejected short tug returns directly; its flick must not create
          // a second, larger reveal before the spring closes.
          !open && !_weatherWasOpen && currentOffset < kEasterEggMinimumOpenPull
              ? velocityY.clamp(-1200.0, 0.0) / panelHeight
              : velocityY.clamp(-1600.0, 1600.0) / panelHeight,
        ),
      );
    }

    if (open && startProgress < 0.9) {
      HapticService.select();
    } else if (!open && startProgress > 0.1) {
      HapticService.tap();
    }
  }

  void _handleDragCancel() => _handleDragEnd(DragEndDetails());

  void _openPassportEntry(bool isEPassport) {
    // The kind is passed to the screen rather than set as a side effect on a
    // shared draft beforehand: the chip route only exists for an e-passport,
    // and the old screen ignored this answer and offered NFC either way.
    Navigator.of(context).push(
      studioPageRoute<void>(
        builder: (_) => PassportPromptScreen(
          kind: isEPassport ? PassportKind.ePassport : PassportKind.regular,
        ),
      ),
    );
  }

  void _openIdEntry(IdDocumentType type) {
    Navigator.of(
      context,
    ).push(studioPageRoute<void>(builder: (_) => IdEntryScreen(type: type)));
  }

  /// Both branches open one morphing sheet that carries its own sub-steps —
  /// the haptic fires inside [showMorphSheet].
  void _showAddSheet() {
    if (_tabCtrl.index == 0) {
      showAddDocumentsMenu(
        context: context,
        onSelectPassportKind: _openPassportEntry,
        onSelectIdType: _openIdEntry,
        passesStep: () => passesRootStep(context, ref),
        // Move the tab under the sheet as well, so dismissing leaves the user
        // looking at the section they just switched into.
        onSwitchToPasses: () => _tabCtrl.animateTo(1),
      );
    } else {
      showAddPassFlow(context, ref);
    }
  }

  bool _ordersEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _openSettings() {
    // Never leave the home-menu barrier open under a pushed route.
    if (_showHomeMenu.value) {
      _showHomeMenu.value = false;
    }
    openSettingsRoute(context);
  }

  void _openWalletSearch() {
    _showHomeMenu.value = false;
    Navigator.of(context).push(
      studioPageRoute<void>(
        builder: (_) => WalletSearchScreen(
          onRevealDocument: _revealWalletItem,
          onAdd: _showAddSheet,
        ),
      ),
    );
  }

  /// Pushed on this Navigator, not the root one: the dashboard mutes its own
  /// tickers via [ModalRoute.secondaryAnimation], so a local push pauses the
  /// backdrop and card animations while the archive covers them.
  void _openArchive(String meshSeed, List<Color> washes) {
    HapticService.select();
    if (_showHomeMenu.value) {
      _showHomeMenu.value = false;
    }
    Navigator.of(context).push(
      studioPageRoute<void>(
        builder: (_) => PassesArchiveScreen(meshSeed: meshSeed, washes: washes),
      ),
    );
  }

  /// The one place a wallet item is removed.
  ///
  /// Three stores have to agree or the carousel order silently drifts: the
  /// live list, the trash list, and the persisted order. `reconcileWalletOrder`
  /// repairs drift on the next load, but only if it is reached — an id left in
  /// the order sorts unknown entries to the end. Every surface that removes a
  /// document (Home long-press, Manage swipe) routes through here rather than
  /// repeating the sequence.
  void _removeWalletItem(Object item) {
    switch (item) {
      case PassportProfile profile:
        ref.read(passportListProvider.notifier).removePassport(profile.id);
        ref.read(trashProvider.notifier).moveToTrash(profile);
        ref
            .read(walletOrderProvider.notifier)
            .updateOrderOnItemRemoved(profile.id);
      case IdDocument doc:
        ref.read(idListProvider.notifier).removeDocument(doc.id);
        ref.read(trashProvider.notifier).moveToTrash(doc);
        ref.read(walletOrderProvider.notifier).updateOrderOnItemRemoved(doc.id);
    }
  }

  /// Manage row tapped: return to Home and page to that document's card.
  ///
  /// Clearing the filter first matters. Manage lists the *unfiltered* wallet,
  /// so the tapped card may not be in `displayItems` at all — without this the
  /// jump silently lands on a neighbour, which looks like it worked.
  void _revealWalletItem(Object item) {
    HapticService.select();
    if (ref.read(walletFilterEnabledProvider)) {
      ref.read(walletFilterCategoryProvider.notifier).resetToAll();
    }
    if (_tabCtrl.index != 0) {
      _tabCtrl.animateTo(0);
    }
    _revealItemId.value = walletItemId(item);
    _viewMode.value = DashboardViewMode.home;
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
              _removeWalletItem(profile);
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

  /// Long-pressing an ID opens the attachment tray above the remove sheet,
  /// so the dimmed space over the card is where document copies are managed.
  ///
  /// The removal itself runs through [_removeWalletItem], which keeps the
  /// trash list and the persisted wallet order in step.
  void _showDeleteIdDialog(IdDocument doc) {
    HapticService.destructive();
    showIdAttachmentSheet(
      context,
      document: doc,
      onRemove: () => _removeWalletItem(doc),
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
    final canReconcile =
        !ref.watch(walletLoadingProvider) &&
        ref.read(walletOrderProvider.notifier).isLoaded &&
        !SecureDocumentStore.isUnreadable('saved_passports') &&
        !SecureDocumentStore.isUnreadable('saved_id_documents') &&
        !SecureDocumentStore.isUnreadable('wallet_items_order');
    if (canReconcile && !_ordersEqual(reconciledOrder, order)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Loads can complete between build and this callback. Reconcile the
        // latest complete lists rather than persisting a stale partial wallet.
        if (ref.read(walletLoadingProvider)) return;
        final currentOrder = ref.read(walletOrderProvider);
        final next = reconcileWalletOrder(
          order: currentOrder,
          activeIds: activeWalletItemIds(
            passports: ref.read(passportListProvider),
            idDocs: ref.read(idListProvider),
          ),
        );
        if (!_ordersEqual(next, currentOrder)) {
          ref.read(walletOrderProvider.notifier).saveOrder(next);
        }
      });
    }

    final List<Object> items = sortWalletItems(
      passports: passports,
      idDocs: idDocs,
      order: reconciledOrder,
    );

    final bool filterEnabled = ref.watch(walletFilterEnabledProvider);
    // Watched here, not in the nested builders below: ref.watch is only valid
    // during this ConsumerState's own build.
    final bool searchButtonEnabled = ref.watch(searchButtonEnabledProvider);
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
    final PassIngestUiState passIngest = ref.watch(
      passIngestControllerProvider,
    );
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

    // Continuous backdrop / card animations keep burning GPU while Settings (or
    // any other route) covers the dashboard. Mute tickers while covered so the
    // pop transition does not double-paint two full animated trees — that was
    // hanging the UI after returning from Settings on mid-range Android.
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final Animation<double>? secondary = route?.secondaryAnimation;

    Widget scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: WeatherRevealSurface(
        offset: _easterEggOffset,
        panelHeight: _weatherPanelHeight,
        drawer: LocalWeatherDrawer(
          offset: _easterEggOffset,
          panelHeight: _weatherPanelHeight,
          onDragStart: _handleDragStart,
          onDragUpdate: _handleDragUpdate,
          onDragEnd: _handleDragEnd,
          onDragCancel: _handleDragCancel,
          passports: passports,
          idDocs: idDocs,
        ),
        child: Stack(
          children: [
            // Background: gradient orbs on Home, flat surface elsewhere
            ValueListenableBuilder<DashboardViewMode>(
              valueListenable: _viewMode,
              builder: (context, mode, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: strongEaseOut,
                  switchOutCurve: strongEaseOut,
                  child: mode == DashboardViewMode.home
                      ? RepaintBoundary(
                          key: const ValueKey('gradient_backdrop'),
                          child: ValueListenableBuilder<double>(
                            valueListenable: _easterEggOffset,
                            child: WalletBackdrop(
                              tabIndex: _tabCtrl.index,
                              items: displayItems,
                              pageNotifier: _docPage,
                              tiltNotifier: _backdropTilt,
                            ),
                            builder: (context, distance, backdrop) => TickerMode(
                              // Pause ambient paint without freezing card scrolling,
                              // button feedback or navigation controllers.
                              enabled: distance <= 0.5,
                              child: backdrop!,
                            ),
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
                        onVerticalDragStart: _handleDragStart,
                        onVerticalDragUpdate: _handleDragUpdate,
                        onVerticalDragEnd: _handleDragEnd,
                        onVerticalDragCancel: _handleDragCancel,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _showHomeMenu,
                            builder: (context, isMenuOpen, _) {
                              return ValueListenableBuilder<DashboardViewMode>(
                                valueListenable: _viewMode,
                                builder: (context, currentMode, _) {
                                  final bool onPasses = _tabCtrl.index == 1;
                                  final bool showHistory =
                                      currentMode == DashboardViewMode.home &&
                                      onPasses;
                                  return DashboardHeader(
                                    meshSeed: meshSeed,
                                    washes: meshWashes,
                                    isMenuOpen: isMenuOpen,
                                    currentMode: currentMode,
                                    onHomeTap: () {
                                      _showHomeMenu.value =
                                          !_showHomeMenu.value;
                                    },
                                    onAvatarTap: _openSettings,
                                    onSearchTap: searchButtonEnabled
                                        ? _openWalletSearch
                                        : null,
                                    headerTitleLink: _headerTitleLink,
                                    showHistoryButton: showHistory,
                                    onHistoryTap: showHistory
                                        ? () =>
                                              _openArchive(meshSeed, meshWashes)
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
                      ValueListenableBuilder<DashboardViewMode>(
                        valueListenable: _viewMode,
                        builder: (context, mode, _) {
                          Widget viewChild;
                          switch (mode) {
                            case DashboardViewMode.home:
                              viewChild = KeyedSubtree(
                                key: const ValueKey('home_view'),
                                child: _HomeTabTransition(
                                  controller: _tabCtrl,
                                  ids: IdsTab(
                                    items: displayItems,
                                    allItems: items,
                                    onDeletePassport: _showDeleteDialog,
                                    onDeleteId: _showDeleteIdDialog,
                                    onAdd: _showAddSheet,
                                    pageNotifier: _docPage,
                                    revealItemId: _revealItemId,
                                    backdropTilt: _backdropTilt,
                                  ),
                                  passes: _passesTabMounted
                                      ? TicketsTab(
                                          isActive: _tabCtrl.index == 1,
                                        )
                                      : const SizedBox.expand(),
                                ),
                              );
                              break;
                            case DashboardViewMode.manage:
                              viewChild = ManageCardsView(
                                key: const ValueKey('manage_view'),
                                items: items,
                                onRevealItem: _revealWalletItem,
                                onRemoveItem: _removeWalletItem,
                                onOpenTrash: () {
                                  _viewMode.value = DashboardViewMode.trash;
                                },
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
                              switchInCurve: strongEaseOut,
                              switchOutCurve: strongEaseOut,
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
                    child: Container(color: Colors.transparent),
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

            ValueListenableBuilder<DashboardViewMode>(
              valueListenable: _viewMode,
              builder: (context, mode, child) {
                final isHome = mode == DashboardViewMode.home;
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    offset: isHome ? Offset.zero : const Offset(0, 1),
                    child: IgnorePointer(ignoring: !isHome, child: child),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                  left: 20,
                  right: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PillTabBar(controller: _tabCtrl),
                    const SizedBox(width: 10),
                    AddFab(
                      onTap: _showAddSheet,
                      enabled: _tabCtrl.index == 0 || passIngest.isIdle,
                      semanticLabel: _tabCtrl.index == 1
                          ? 'Add pass'
                          : 'Add document',
                    ),
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
