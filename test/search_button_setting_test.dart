import 'package:docket/features/dashboard/application/search_button_provider.dart';
import 'package:docket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:docket/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget header({VoidCallback? onSearchTap}) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: DashboardHeader(
          meshSeed: 'test',
          washes: const [Colors.blue, Colors.green],
          isMenuOpen: false,
          currentMode: DashboardViewMode.home,
          onHomeTap: () {},
          onAvatarTap: () {},
          headerTitleLink: LayerLink(),
          onSearchTap: onSearchTap,
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the search button is off until it is added from settings', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(searchButtonEnabledProvider), isFalse);

    await container.read(searchButtonEnabledProvider.notifier).toggle();
    expect(container.read(searchButtonEnabledProvider), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('show_search_button'),
      isTrue,
    );
  });

  test('a stored preference survives a restart', () async {
    SharedPreferences.setMockInitialValues({'show_search_button': true});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(searchButtonEnabledProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(searchButtonEnabledProvider), isTrue);
  });

  testWidgets('the header only draws search when the setting is on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(header());
    await tester.pump();
    expect(find.byTooltip('Search and browse wallet'), findsNothing);

    var searches = 0;
    await tester.pumpWidget(header(onSearchTap: () => searches++));
    await tester.pump();
    await tester.tap(find.byTooltip('Search and browse wallet'));
    expect(searches, 1);
  });
}
