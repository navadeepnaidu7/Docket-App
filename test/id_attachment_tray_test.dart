import 'dart:typed_data';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/ids/domain/id_attachment.dart';
import 'package:docket/features/ids/presentation/attachments/attachment_add_tile.dart';
import 'package:docket/features/ids/presentation/attachments/attachment_thumb_strip.dart';
import 'package:docket/features/ids/presentation/attachments/id_attachment_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake resolver returning valid 1x1 transparent PNG bytes synchronously.
Future<Uint8List> fakeResolver(IdAttachment a) async {
  return Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);
}

Widget buildTestApp(Widget child, {double height = 600}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 390,
          height: height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  final sampleImage1 = IdAttachment(
    id: 'img1',
    kind: IdAttachmentKind.image,
    fileName: 'img1.enc',
    sizeBytes: 1024,
  );

  final sampleImage2 = IdAttachment(
    id: 'img2',
    kind: IdAttachmentKind.image,
    fileName: 'img2.enc',
    sizeBytes: 2048,
  );

  final sampleImage3 = IdAttachment(
    id: 'img3',
    kind: IdAttachmentKind.image,
    fileName: 'img3.enc',
    sizeBytes: 4096,
  );

  final samplePdf = IdAttachment(
    id: 'pdf1',
    kind: IdAttachmentKind.pdf,
    fileName: 'pdf1.enc',
    sizeBytes: 8192,
  );

  testWidgets('Empty state: shows hero add tile; no counter, strip, or swipe hint', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        IdAttachmentTray(
          attachments: const [],
          resolveBytes: fakeResolver,
          onAdd: () {},
          onRemoveRequested: (_) {},
          canAddMore: true,
        ),
      ),
    );

    expect(find.text('You can add images or PDFs'), findsOneWidget);
    expect(find.byType(AttachmentAddTile), findsOneWidget);
    expect(find.textContaining('1 of'), findsNothing);
    expect(find.byType(AttachmentThumbStrip), findsNothing);
    expect(find.text('Swipe to see more'), findsNothing);
  });

  testWidgets('2 attachments: counter reads 1 of 2; tapping thumb updates counter to 2 of 2', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        IdAttachmentTray(
          attachments: [sampleImage1, sampleImage2],
          resolveBytes: fakeResolver,
          onAdd: () {},
          onRemoveRequested: (_) {},
          canAddMore: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Swipe to see more'), findsOneWidget);
    expect(find.byType(AttachmentThumbStrip), findsOneWidget);

    final thumbs = find.descendant(
      of: find.byType(AttachmentThumbStrip),
      matching: find.byType(GestureDetector),
    );
    expect(thumbs, findsNWidgets(3)); // 2 thumbs + 1 add tile

    await tester.tap(thumbs.at(1));
    await tester.pumpAndSettle();

    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets('At 3 images + 1 PDF: add tile is GONE from strip', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        IdAttachmentTray(
          attachments: [sampleImage1, sampleImage2, sampleImage3, samplePdf],
          resolveBytes: fakeResolver,
          onAdd: () {},
          onRemoveRequested: (_) {},
          canAddMore: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.byType(AttachmentAddTile), findsNothing);
  });

  testWidgets('Long-pressing a thumb fires onRemoveRequested with correct index', (tester) async {
    int? removedIndex;

    await tester.pumpWidget(
      buildTestApp(
        IdAttachmentTray(
          attachments: [sampleImage1, sampleImage2],
          resolveBytes: fakeResolver,
          onAdd: () {},
          onRemoveRequested: (idx) {
            removedIndex = idx;
          },
          canAddMore: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final thumbs = find.descendant(
      of: find.byType(AttachmentThumbStrip),
      matching: find.byType(GestureDetector),
    );

    await tester.longPress(thumbs.at(1));
    await tester.pumpAndSettle();

    expect(removedIndex, equals(1));
  });

  testWidgets('A PDF attachment renders the PDF placeholder', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        IdAttachmentTray(
          attachments: [samplePdf],
          resolveBytes: fakeResolver,
          onAdd: () {},
          onRemoveRequested: (_) {},
          canAddMore: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PDF'), findsWidgets);
    expect(find.byIcon(Icons.picture_as_pdf_rounded), findsWidgets);
  });
}
