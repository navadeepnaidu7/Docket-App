import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/features/tickets/application/pass_list_provider.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/data/mock_pass_repository.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_ingest.dart';
import 'package:docket/features/tickets/domain/pass_repository.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/pass_remove_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingRepo implements PassRepository {
  _ThrowingRepo(this.items, this.error);

  final List<WalletPassItem> items;
  final Object error;

  @override
  Future<List<WalletPassItem>> fetchPasses({TicketStatus? status}) async {
    return List<WalletPassItem>.from(items);
  }

  @override
  Future<WalletPassItem?> fetchPassById(String id) async {
    for (final WalletPassItem p in items) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> deletePass(String id) async {
    throw error;
  }
}

List<Override> _overrides(PassRepository repo) {
  return <Override>[
    devFlagsProvider.overrideWith(
      (Ref ref) => DevFlagsNotifier.fixed(
        const DevFlags(useMockPasses: true, apiBaseUrl: ''),
      ),
    ),
    passRepositoryProvider.overrideWithValue(repo),
  ];
}

void main() {
  late List<WalletPassItem> seed;

  setUp(() {
    seed = <WalletPassItem>[
      TrainPassItem(mockTrainPasses.first),
      TrainPassItem(mockTrainPasses.last),
    ];
  });

  group('PassListNotifier.removePass', () {
    test('drops the id from the loaded list', () async {
      final String removedId = seed.first.id;
      final String keptId = seed.last.id;
      final MockPassRepository repo = MockPassRepository(
        artificialDelay: Duration.zero,
        seed: List<WalletPassItem>.from(seed),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: _overrides(repo),
      );
      addTearDown(container.dispose);

      final List<WalletPassItem> loaded =
          await container.read(passListProvider.future);
      expect(loaded.length, 2);

      await container.read(passListProvider.notifier).removePass(removedId);

      final List<WalletPassItem> after =
          container.read(passListProvider).requireValue;
      expect(after.map((WalletPassItem p) => p.id), <String>[keptId]);
      expect(await repo.fetchPassById(removedId), isNull);
    });

    test('puts the list back when the repository throws', () async {
      final Object error = const PassIngestException(
        PassIngestCode.failed,
        'offline',
      );
      final _ThrowingRepo repo = _ThrowingRepo(seed, error);
      final ProviderContainer container = ProviderContainer(
        overrides: _overrides(repo),
      );
      addTearDown(container.dispose);

      await container.read(passListProvider.future);

      await expectLater(
        container.read(passListProvider.notifier).removePass(seed.first.id),
        throwsA(same(error)),
      );

      final List<WalletPassItem> after =
          container.read(passListProvider).requireValue;
      expect(after.map((WalletPassItem p) => p.id).toList(),
          seed.map((WalletPassItem p) => p.id).toList());
    });
  });

  group('confirmAndRemovePass', () {
    testWidgets('Remove deletes the pass; Cancel leaves it', (
      WidgetTester tester,
    ) async {
      final String removedId = seed.first.id;
      final MockPassRepository repo = MockPassRepository(
        artificialDelay: Duration.zero,
        seed: List<WalletPassItem>.from(seed),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(repo),
          child: Consumer(
            builder: (BuildContext _, WidgetRef ref, Widget? child) {
              return MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (BuildContext context) {
                      return TextButton(
                        onPressed: () => confirmAndRemovePass(
                          context,
                          ref,
                          seed.first,
                        ),
                        child: const Text('go'),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this pass?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repo.fetchPassById(removedId), isNotNull);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      // The success snackbar holds for seconds; don't wait it out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(await repo.fetchPassById(removedId), isNull);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a failed delete shows an error and keeps the pass', (
      WidgetTester tester,
    ) async {
      final _ThrowingRepo repo = _ThrowingRepo(
        seed,
        const PassIngestException(PassIngestCode.needsAuth, 'Sign in first.'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(repo),
          child: Consumer(
            builder: (BuildContext _, WidgetRef ref, Widget? child) {
              return MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (BuildContext context) {
                      return TextButton(
                        onPressed: () => confirmAndRemovePass(
                          context,
                          ref,
                          seed.first,
                        ),
                        child: const Text('go'),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Could not remove pass'), findsOneWidget);
      expect(find.text('Sign in first.'), findsOneWidget);
    });
  });
}
