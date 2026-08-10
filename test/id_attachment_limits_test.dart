import 'package:docket/features/ids/domain/attachment_limits.dart';
import 'package:docket/features/ids/domain/id_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kindForExtension', () {
    test('handles standard lowercase image extensions', () {
      expect(kindForExtension('card.jpg'), equals(IdAttachmentKind.image));
      expect(kindForExtension('card.jpeg'), equals(IdAttachmentKind.image));
      expect(kindForExtension('photo.png'), equals(IdAttachmentKind.image));
      expect(kindForExtension('photo.heic'), equals(IdAttachmentKind.image));
      expect(kindForExtension('image.webp'), equals(IdAttachmentKind.image));
    });

    test('handles standard lowercase pdf extension', () {
      expect(kindForExtension('doc.pdf'), equals(IdAttachmentKind.pdf));
    });

    test('handles uppercase extensions', () {
      expect(kindForExtension('CARD.JPG'), equals(IdAttachmentKind.image));
      expect(kindForExtension('PHOTO.PNG'), equals(IdAttachmentKind.image));
      expect(kindForExtension('DOCUMENT.PDF'), equals(IdAttachmentKind.pdf));
      expect(kindForExtension('SCAN.HEIC'), equals(IdAttachmentKind.image));
    });

    test('returns null for unknown extensions', () {
      expect(kindForExtension('archive.zip'), isNull);
      expect(kindForExtension('document.txt'), isNull);
      expect(kindForExtension('data.json'), isNull);
    });

    test('returns null for filenames without a dot or ending with a dot', () {
      expect(kindForExtension('filename'), isNull);
      expect(kindForExtension('filename.'), isNull);
      expect(kindForExtension(''), isNull);
    });
  });

  group('rejectionFor', () {
    final sampleImage = IdAttachment(
      id: 'img1',
      kind: IdAttachmentKind.image,
      fileName: 'img1.enc',
      sizeBytes: 1000,
    );

    final samplePdf = IdAttachment(
      id: 'pdf1',
      kind: IdAttachmentKind.pdf,
      fileName: 'pdf1.enc',
      sizeBytes: 2000,
    );

    test('3 images accepted, the 4th rejected with limitReached', () {
      final List<IdAttachment> list = [];

      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1024,
        ),
        isNull,
      );

      list.add(sampleImage.copyWith(id: 'img1'));
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1024,
        ),
        isNull,
      );

      list.add(sampleImage.copyWith(id: 'img2'));
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1024,
        ),
        isNull,
      );

      list.add(sampleImage.copyWith(id: 'img3'));
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1024,
        ),
        equals(AttachRejection.limitReached),
      );
    });

    test('1 PDF accepted, the 2nd rejected with limitReached', () {
      final List<IdAttachment> list = [];

      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.pdf,
          sizeBytes: 2048,
        ),
        isNull,
      );

      list.add(samplePdf);
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.pdf,
          sizeBytes: 2048,
        ),
        equals(AttachRejection.limitReached),
      );
    });

    test('3 images AND 1 PDF coexist happily', () {
      final list = [
        sampleImage.copyWith(id: 'img1'),
        sampleImage.copyWith(id: 'img2'),
        sampleImage.copyWith(id: 'img3'),
        samplePdf.copyWith(id: 'pdf1'),
      ];

      expect(list.where((a) => a.kind == IdAttachmentKind.image).length, 3);
      expect(list.where((a) => a.kind == IdAttachmentKind.pdf).length, 1);

      // Adding 4th image is rejected
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1000,
        ),
        equals(AttachRejection.limitReached),
      );

      // Adding 2nd PDF is rejected
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.pdf,
          sizeBytes: 1000,
        ),
        equals(AttachRejection.limitReached),
      );
    });

    test('adding an image when 1 PDF exists is allowed, and vice versa', () {
      final pdfOnly = [samplePdf];
      expect(
        rejectionFor(
          existing: pdfOnly,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1000,
        ),
        isNull,
      );

      final imagesOnly = [
        sampleImage.copyWith(id: 'img1'),
        sampleImage.copyWith(id: 'img2'),
        sampleImage.copyWith(id: 'img3'),
      ];
      expect(
        rejectionFor(
          existing: imagesOnly,
          incoming: IdAttachmentKind.pdf,
          sizeBytes: 1000,
        ),
        isNull,
      );
    });

    test('interleaved add order does not change the outcome', () {
      final list = <IdAttachment>[];

      // Add image 1 -> allowed
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1000,
        ),
        isNull,
      );
      list.add(sampleImage.copyWith(id: 'i1'));

      // Add PDF 1 -> allowed
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.pdf,
          sizeBytes: 1000,
        ),
        isNull,
      );
      list.add(samplePdf.copyWith(id: 'p1'));

      // Add image 2 -> allowed
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1000,
        ),
        isNull,
      );
      list.add(sampleImage.copyWith(id: 'i2'));

      // Try PDF 2 -> rejected
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.pdf,
          sizeBytes: 1000,
        ),
        equals(AttachRejection.limitReached),
      );

      // Add image 3 -> allowed
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1000,
        ),
        isNull,
      );
      list.add(sampleImage.copyWith(id: 'i3'));

      // Try image 4 -> rejected
      expect(
        rejectionFor(
          existing: list,
          incoming: IdAttachmentKind.image,
          sizeBytes: 1000,
        ),
        equals(AttachRejection.limitReached),
      );
    });

    test('a file over 25 MB is rejected with tooLarge', () {
      const maxAllowedBytes = 25 * 1024 * 1024;
      const oversizedBytes = maxAllowedBytes + 1;

      expect(
        rejectionFor(
          existing: [],
          incoming: IdAttachmentKind.image,
          sizeBytes: maxAllowedBytes,
        ),
        isNull,
      );

      expect(
        rejectionFor(
          existing: [],
          incoming: IdAttachmentKind.image,
          sizeBytes: oversizedBytes,
        ),
        equals(AttachRejection.tooLarge),
      );

      expect(
        rejectionFor(
          existing: [],
          incoming: IdAttachmentKind.pdf,
          sizeBytes: oversizedBytes,
        ),
        equals(AttachRejection.tooLarge),
      );
    });
  });
}
