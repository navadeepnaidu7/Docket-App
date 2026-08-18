import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/tickets/presentation/pass_typography.dart';

const Color _ink = Color(0xFF101010);

/// The pass detail screens. Their chrome must come from [PassType] — the card
/// faces are deliberately excluded, see the note on [PassType].
const List<String> _detailScreens = <String>[
  'lib/features/tickets/presentation/ticket_detail_screen.dart',
  'lib/features/tickets/presentation/movie_pass_detail_screen.dart',
  'lib/features/tickets/presentation/bus/bus_pass_detail_screen.dart',
];

void main() {
  // PassType resolves through google_fonts, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PassType scale', () {
    test('every role lands on one of five sizes', () {
      final List<TextStyle> roles = <TextStyle>[
        PassType.screenTitle(_ink),
        PassType.sectionTitle(_ink),
        PassType.itemTitle(_ink),
        PassType.label(_ink),
        PassType.value(_ink),
        PassType.caption(_ink),
        PassType.pill(_ink),
        PassType.micro(_ink),
      ];

      for (final TextStyle s in roles) {
        expect(
          s.fontSize,
          anyOf(16.0, 15.0, 13.0, 12.0, 11.0),
          reason: 'roles may only use the five documented steps',
        );
      }
    });

    // The train screen used to run to 21 while movie and bus topped out at 16,
    // so the same kind of thing rendered at a different size per pass type.
    test('nothing in the ramp is larger than the screen title', () {
      final double title = PassType.screenTitle(_ink).fontSize!;
      for (final TextStyle s in <TextStyle>[
        PassType.sectionTitle(_ink),
        PassType.itemTitle(_ink),
        PassType.label(_ink),
        PassType.value(_ink),
        PassType.caption(_ink),
        PassType.pill(_ink),
        PassType.micro(_ink),
      ]) {
        expect(s.fontSize, lessThanOrEqualTo(title));
      }
    });

    test('a label and its value are the same size, differing in weight', () {
      expect(PassType.label(_ink).fontSize, PassType.value(_ink).fontSize);
      expect(
        PassType.value(_ink).fontWeight!.value,
        greaterThan(PassType.label(_ink).fontWeight!.value),
      );
    });

    test('every role carries the colour it was handed', () {
      expect(PassType.screenTitle(_ink).color, _ink);
      expect(PassType.caption(_ink).color, _ink);
      expect(PassType.code(_ink).color, _ink);
    });

    // A document number is read character by character, so it keeps open
    // tracking. That is the one role allowed off the body ramp.
    test('the code role is tracked and is the only exception to the ramp', () {
      final TextStyle code = PassType.code(_ink);
      expect(code.letterSpacing, greaterThan(1.0));
      expect(code.fontSize, 17.0);
    });
  });

  group('pass detail screens use the scale', () {
    test('no screen sets a raw fontSize or calls GoogleFonts directly', () {
      final List<String> offenders = <String>[];

      for (final String path in _detailScreens) {
        final File file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path should exist');
        final String source = file.readAsStringSync();

        if (source.contains('fontSize:')) {
          offenders.add('$path sets a raw fontSize');
        }
        if (source.contains('GoogleFonts.')) {
          offenders.add('$path calls GoogleFonts directly');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Pass chrome must go through PassType so the three detail screens '
            'stay uniform:\n${offenders.join('\n')}',
      );
    });
  });
}
