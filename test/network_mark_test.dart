import 'package:docket/features/cards/domain/card_number.dart';
import 'package:docket/features/cards/domain/card_surface.dart';
import 'package:docket/features/cards/presentation/network_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final light in [false, true]) {
    testWidgets('Discover stays within its stamp in a loose row ($light)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                NetworkMark(
                  network: CardNetwork.discover,
                  surface: CardSurfaceStyle(
                    background: light ? Colors.white : Colors.black,
                    ink: light ? Colors.black : Colors.white,
                    light: light,
                  ),
                ),
                const Text('Card type'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stamp = tester.getRect(find.byType(NetworkMark));
      final label = tester.getRect(find.text('Card type'));
      expect(stamp.size, const Size(68, 18));
      expect(stamp.right, lessThanOrEqualTo(label.left));
      expect(tester.takeException(), isNull);
    });
  }
}
