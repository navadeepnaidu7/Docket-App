import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/dashboard/presentation/widgets/add_menu.dart';
import 'package:docket/shared/widgets/morph_sheet.dart';
import 'package:docket/features/passport/presentation/widgets/passport_cover_art.dart';
import 'package:docket/features/tickets/presentation/add/add_pass_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual regression for the add menu. Rendered at a phone size, since the
/// layout is width-driven.
void main() {
  setUp(() async {
    // SVG parsing has to run for real or the cover art renders empty.
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await PassportCoverArt.warmUp();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('documents menu golden', (WidgetTester tester) async {
    await pumpAt(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () => showAddDocumentsMenu(
                context: context,
                onSelectPassportKind: (_) {},
                onSelectIdType: (_) {},
                passesStep: () => MorphStep(
                  id: 'passes',
                  title: 'Passes',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
                onSwitchToPasses: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_menu_documents.png'),
    );

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_menu_passport_kind.png'),
    );
  });

  testWidgets('passes menu golden', (WidgetTester tester) async {
    await pumpAt(
      tester,
      Scaffold(
        body: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) => Center(
            child: ElevatedButton(
              onPressed: () => showAddPassFlow(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_menu_passes.png'),
    );

    await tester.tap(find.text('Trains'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_menu_train_method.png'),
    );
  });

  testWidgets('documents menu golden, dark', (WidgetTester tester) async {
    await pumpAt(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () => showAddDocumentsMenu(
                context: context,
                onSelectPassportKind: (_) {},
                onSelectIdType: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      brightness: Brightness.dark,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_menu_documents_dark.png'),
    );
  });
}
