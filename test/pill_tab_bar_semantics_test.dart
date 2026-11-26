import 'package:docket/features/dashboard/presentation/widgets/pill_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tabs announce their name and which one is selected', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final controller = TabController(length: 2, vsync: tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: PillTabBar(controller: controller)),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('IDs')),
      matchesSemantics(
        label: 'IDs',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Passes')),
      matchesSemantics(
        label: 'Passes',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Passes'));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    semantics.dispose();
  });
}
