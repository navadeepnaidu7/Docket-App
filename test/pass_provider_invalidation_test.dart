import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/features/dashboard/application/auth_session_provider.dart';
import 'package:docket/features/tickets/application/api_providers.dart';
import 'package:docket/features/tickets/application/pass_list_provider.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_repository.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingRepository implements PassRepository {
  int fetches = 0;
  @override
  Future<List<WalletPassItem>> fetchPasses({TicketStatus? status}) async {
    fetches++;
    return const [];
  }

  @override
  Future<WalletPassItem?> fetchPassById(String id) async => null;
  @override
  Future<void> deletePass(String id) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('visual settings preserve the API client and pass repository', () async {
    final container = ProviderContainer(
      overrides: [
        devFlagsProvider.overrideWith(
          (ref) => DevFlagsNotifier.fixed(
            const DevFlags(
              useMockPasses: false,
              apiBaseUrl: 'https://api.test',
            ),
          ),
        ),
        authSessionProvider.overrideWithValue(
          const AuthSession(isSignedIn: true, id: 'user1'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final client = container.read(docketApiClientProvider);
    final repo = container.read(passRepositoryProvider);

    await container
        .read(devFlagsProvider.notifier)
        .setCardFluidScheme(CardFluidScheme.emerald);
    expect(container.read(docketApiClientProvider), same(client));
    expect(container.read(passRepositoryProvider), same(repo));

    await container
        .read(devFlagsProvider.notifier)
        .setApiBaseUrl('https://new.test');
    expect(container.read(docketApiClientProvider), isNot(same(client)));
    expect(container.read(passRepositoryProvider), isNot(same(repo)));
  });

  test('visual settings do not refetch an already loaded pass list', () async {
    final repo = _CountingRepository();
    final container = ProviderContainer(
      overrides: [
        devFlagsProvider.overrideWith(
          (ref) => DevFlagsNotifier.fixed(
            const DevFlags(useMockPasses: true, apiBaseUrl: ''),
          ),
        ),
        passRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await container.read(passListProvider.future);
    expect(repo.fetches, 1);

    await container
        .read(devFlagsProvider.notifier)
        .setCardFluidScheme(CardFluidScheme.neonAurora);
    await container.read(passListProvider.future);
    expect(repo.fetches, 1);
    expect(container.read(passListProvider).isLoading, isFalse);
  });
}
