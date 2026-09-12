import 'package:docket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:docket/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'header search, archive and settings fit a small large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var searches = 0;
      var archives = 0;
      var settings = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: DashboardHeader(
                    meshSeed: 'test',
                    washes: const [Colors.blue, Colors.green],
                    isMenuOpen: false,
                    currentMode: DashboardViewMode.manage,
                    onHomeTap: () {},
                    onAvatarTap: () => settings++,
                    headerTitleLink: LayerLink(),
                    onSearchTap: () => searches++,
                    showHistoryButton: true,
                    onHistoryTap: () => archives++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Search and browse wallet'));
      await tester.tap(find.byType(HistoryHeaderButton));
      await tester.tap(find.byType(ProfileMeshButton));
      expect([searches, archives, settings], [1, 1, 1]);
      expect(
        tester.getSize(find.byType(ProfileMeshButton)),
        const Size(48, 48),
      );
    },
  );
}
