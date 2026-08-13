import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/train/train_pass_theme.dart';
import 'package:docket/features/tickets/presentation/train/train_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrainPass _pass({
  String fromCode = 'HYB',
  String fromName = 'Hyderabad',
  String toCode = 'BLR',
  String toName = 'Bengaluru',
}) {
  return TrainPass(
    id: 't',
    operator: 'IRCTC',
    trainNumber: '12932',
    trainName: 'Rajdhani Express',
    fromCode: fromCode,
    fromName: fromName,
    toCode: toCode,
    toName: toName,
    departTime: '07:10 AM',
    arriveTime: '02:40 PM',
    date: '16 Aug 2026',
    arrivalDate: '16 Aug 2026',
    duration: '7h 30m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'B2',
        seat: '32',
        berth: 'Lower',
      ),
    ],
    pnr: '1234567890',
    bookingId: 'B',
    status: TicketStatus.active,
  );
}

Future<void> _pumpFace(WidgetTester tester, TrainPass pass) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: TrainPassMetrics.width,
            height: TrainPassMetrics.height,
            child: TrainTicketFace(
              ticket: pass,
              density: TrainTicketDensity.glance,
              clock: () => DateTime(2026, 8, 13, 9),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('station header alignment', () {
    // RenderBaseline lays its child out loose and pins it flush left, so a
    // `width` + `textAlign: right` combination silently does nothing and the
    // destination column renders from the wrong edge. Nothing throws and no
    // overflow is reported — only a screenshot catches it, which is exactly
    // why it is pinned here.
    testWidgets('origin and destination hang off opposite content edges',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());

      final Rect card = tester.getRect(find.byType(TrainTicketFace));

      final Rect fromCode = tester.getRect(find.text('HYB'));
      final Rect toCode = tester.getRect(find.text('BLR'));
      final Rect fromName = tester.getRect(find.text('HYDERABAD'));
      final Rect toName = tester.getRect(find.text('BENGALURU'));

      const double inset = TrainPassMetrics.inset;

      expect(fromCode.left - card.left, moreOrLessEquals(inset, epsilon: 1));
      expect(card.right - toCode.right, moreOrLessEquals(inset, epsilon: 1));

      expect(fromName.left - card.left, moreOrLessEquals(inset, epsilon: 1));
      expect(card.right - toName.right, moreOrLessEquals(inset, epsilon: 1));
    });

    testWidgets('a long destination name still ends at the content edge',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass(toName: 'Chennai Central'));

      final Rect card = tester.getRect(find.byType(TrainTicketFace));
      final Rect toName = tester.getRect(find.text('CHENNAI CENTRAL'));

      expect(
        card.right - toName.right,
        moreOrLessEquals(TrainPassMetrics.inset, epsilon: 1),
      );
      expect(toName.left, greaterThan(card.left + TrainPassMetrics.inset));
    });
  });

  group('station connector', () {
    // The rule spans the whole content width and is masked back by an opaque
    // swatch behind each code, so the gap is produced at layout time. That is
    // deliberate: an earlier version measured the codes with a TextPainter in
    // build, which ran once — before google_fonts resolved Instrument Serif —
    // and left the rule sized for the fallback face permanently.

    testWidgets('spans the full content width', (WidgetTester tester) async {
      await _pumpFace(tester, _pass());

      final Rect card = tester.getRect(find.byType(TrainTicketFace));
      final Rect rule =
          tester.getRect(find.byKey(TrainTicketFace.connectorKey));

      expect(
        rule.left - card.left,
        moreOrLessEquals(TrainPassMetrics.inset, epsilon: 0.5),
      );
      expect(
        card.right - rule.right,
        moreOrLessEquals(TrainPassMetrics.inset, epsilon: 0.5),
      );
      expect(
        rule.center.dy - card.top,
        moreOrLessEquals(TrainPassMetrics.connectorY, epsilon: 0.5),
      );
    });

    testWidgets('each code carries a mask wider than its own lettering',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());

      final Rect fromCode = tester.getRect(find.text('HYB'));
      final Rect fromMask = tester.getRect(
        find.ancestor(
          of: find.text('HYB'),
          matching: find.byType(ColoredBox),
        ).first,
      );

      // The swatch overhangs the glyphs by the connector gap on the inner
      // side, which is what holds the dashes clear of the lettering.
      expect(
        fromMask.right - fromCode.right,
        moreOrLessEquals(TrainPassMetrics.codeConnectorGap, epsilon: 1),
      );
      // ...and covers the rule's row, or it would not mask anything.
      expect(fromMask.top, lessThan(fromCode.top + TrainPassMetrics.connectorY));
    });
  });
}
