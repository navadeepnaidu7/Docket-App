import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_flags_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../ids/application/id_list_provider.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../tickets/application/pass_list_provider.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../../tickets/domain/pass_status.dart';
import '../../tickets/presentation/open_pass.dart';
import '../application/wallet_loading_provider.dart';
import '../domain/wallet_search.dart';
import 'widgets/wallet_row_tile.dart';

class WalletSearchScreen extends ConsumerWidget {
  const WalletSearchScreen({
    super.key,
    required this.onRevealDocument,
    required this.onAdd,
  });
  final ValueChanged<Object> onRevealDocument;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passes = ref.watch(passListProvider);
    final entries = <WalletSearchEntry>[
      ...ref.watch(passportListProvider).map(WalletSearchEntry.document),
      ...ref.watch(idListProvider).map(WalletSearchEntry.document),
      ...?passes.valueOrNull?.map(WalletSearchEntry.pass),
    ];
    return WalletSearchView(
      entries: entries,
      loadingDocuments: ref.watch(walletLoadingProvider),
      loadingPasses: passes.isLoading,
      passesError: passes.hasError,
      demoPasses: ref.watch(devFlagsProvider).isMockPassesActive,
      onRetry: () => ref.read(passListProvider.notifier).refresh(),
      onOpen: (entry) {
        if (entry.item case WalletPassItem pass) {
          openPass(context, pass);
        } else {
          Navigator.of(context).pop();
          onRevealDocument(entry.item);
        }
      },
      onAdd: () {
        Navigator.of(context).pop();
        onAdd();
      },
    );
  }
}

/// The compact wallet index also serves as the search results surface.
class WalletSearchView extends StatefulWidget {
  const WalletSearchView({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onAdd,
    required this.onRetry,
    this.loadingDocuments = false,
    this.loadingPasses = false,
    this.passesError = false,
    this.demoPasses = false,
  });
  final List<WalletSearchEntry> entries;
  final ValueChanged<WalletSearchEntry> onOpen;
  final VoidCallback onAdd;
  final VoidCallback onRetry;
  final bool loadingDocuments;
  final bool loadingPasses;
  final bool passesError;
  final bool demoPasses;

  @override
  State<WalletSearchView> createState() => _WalletSearchViewState();
}

class _WalletSearchViewState extends State<WalletSearchView> {
  final _query = TextEditingController();
  WalletSearchScope _scope = WalletSearchScope.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final results = searchWallet(widget.entries, _query.text, _scope);
    final filtering =
        _query.text.trim().isNotEmpty || _scope != WalletSearchScope.all;
    final showPasses = _scope != WalletSearchScope.documents;
    final loading =
        (showPasses && widget.loadingPasses) ||
        ((_scope == WalletSearchScope.all ||
                _scope == WalletSearchScope.documents) &&
            widget.loadingDocuments);
    return Scaffold(
      appBar: AppBar(title: const Text('Your wallet')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'Search your wallet',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_query.clear),
                        ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final scope in WalletSearchScope.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_scopeLabel(scope)),
                        selected: _scope == scope,
                        onSelected: (_) => setState(() => _scope = scope),
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: LinearProgressIndicator(),
                      ),
                    ),
                  if (showPasses && widget.demoPasses)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Text(
                          'Passes are samples for exploring Docket. Your documents are real.',
                        ),
                      ),
                    ),
                  if (showPasses && widget.passesError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            const Text('Passes couldn’t be loaded.'),
                            TextButton(
                              onPressed: widget.onRetry,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (results.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Text(
                          '${results.length} ${results.length == 1 ? 'item' : 'items'}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTokens.secondaryLabel(scheme),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverList.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) => _SearchRow(
                          entry: results[index],
                          onOpen: () => widget.onOpen(results[index]),
                        ),
                      ),
                    ),
                  ] else if (!loading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              filtering
                                  ? Icons.search_off_rounded
                                  : Icons.wallet_outlined,
                              size: 36,
                              color: AppTokens.secondaryLabel(scheme),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              filtering
                                  ? 'No matching items'
                                  : 'Your wallet starts here',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              filtering
                                  ? 'Try a name, route, title, or booking reference.'
                                  : 'Add a document or ticket to keep it close at hand.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            if (filtering)
                              TextButton(
                                onPressed: () => setState(() {
                                  _query.clear();
                                  _scope = WalletSearchScope.all;
                                }),
                                child: const Text('Show all items'),
                              )
                            else
                              FilledButton(
                                onPressed: widget.onAdd,
                                child: const Text('Add your first item'),
                              ),
                          ],
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

String _scopeLabel(WalletSearchScope scope) => switch (scope) {
  WalletSearchScope.all => 'All',
  WalletSearchScope.documents => 'Documents',
  WalletSearchScope.passes => 'Passes',
  WalletSearchScope.archive => 'Archive',
};

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.entry, required this.onOpen});
  final WalletSearchEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = entry.item;
    final isPass = item is WalletPassItem;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTokens.elevatedSurface(scheme),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTokens.hairline(scheme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isPass)
                      WalletMiniCard(palette: WalletRowMeta.of(item).palette)
                    else
                      SizedBox(
                        width: 34,
                        height: 28,
                        child: Icon(switch (item.kind) {
                          PassKind.train => Icons.train_outlined,
                          PassKind.movie => Icons.movie_outlined,
                          PassKind.bus => Icons.directions_bus_outlined,
                        }, color: scheme.onSurface),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.title, style: theme.textTheme.titleSmall),
                          if (entry.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              entry.subtitle,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          if (entry.scope == WalletSearchScope.archive) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Archived',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTokens.secondaryLabel(scheme),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
