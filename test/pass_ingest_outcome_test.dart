import 'package:docket/features/tickets/application/pass_ingest_controller.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_ingest.dart';
import 'package:docket/features/tickets/presentation/add/pass_ingest_outcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failure stays visible and exposes recovery after a long delay', (
    tester,
  ) async {
    var retries = 0;
    var replacements = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassIngestOutcome(
            state: const PassIngestFailed(
              request: FilePassIngestRequest(
                path: 'ticket.pdf',
                category: PassInputCategory.train,
              ),
              error: PassIngestException(
                PassIngestCode.failed,
                'Check your connection.',
              ),
            ),
            onRetry: () => retries++,
            onReplace: () => replacements++,
            onDismiss: () => dismissed++,
            onView: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Check your connection.'), findsOneWidget);
    expect(dismissed, 0);
    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Choose another file'));
    await tester.tap(find.text('Dismiss'));
    expect([retries, replacements, dismissed], [1, 1, 1]);
  });
  testWidgets('archived import explains missing code and opens the same pass', (
    tester,
  ) async {
    final item = MoviePassItem.fromJson({
      'id': 'archived',
      'movieTitle': 'Arrival',
      'status': 'expired',
    });
    WalletPassItem? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassIngestOutcome(
            state: PassIngestSucceeded(
              request: const PnrPassIngestRequest('1234567890'),
              item: item,
            ),
            onRetry: () {},
            onReplace: () {},
            onDismiss: () {},
            onView: (pass) => opened = pass,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Added to Archive'), findsOneWidget);
    expect(find.textContaining('No boarding code was found'), findsOneWidget);
    await tester.tap(find.text('View pass'));
    expect(opened, same(item));
  });
  testWidgets(
    'demo error contains no developer setup instructions or futile retry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassIngestOutcome(
              state: const PassIngestFailed(
                request: PnrPassIngestRequest('1234567890'),
                error: PassIngestException(
                  PassIngestCode.needsRemote,
                  'Set API URL under Developer',
                ),
              ),
              onRetry: () {},
              onReplace: () {},
              onDismiss: () {},
              onView: (_) {},
            ),
          ),
        ),
      );
      expect(find.textContaining('sample tickets'), findsOneWidget);
      expect(find.textContaining('API URL'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    },
  );
}
