/// Corrections for the characters OCR swaps inside printed numbers.
///
/// Only a word that is already mostly digits is touched, so a name such as
/// "SOBHA" never turns into "50BHA".
library;

const Map<String, String> _asDigit = <String, String>{
  'O': '0',
  'o': '0',
  'D': '0',
  'Q': '0',
  'I': '1',
  'l': '1',
  'i': '1',
  '|': '1',
  '!': '1',
  'Z': '2',
  'z': '2',
  'S': '5',
  's': '5',
  'B': '8',
  'G': '6',
  'b': '6',
  'T': '7',
  'q': '9',
  'g': '9',
};

const Map<String, String> _asLetter = <String, String>{
  '0': 'O',
  '1': 'I',
  '2': 'Z',
  '5': 'S',
  '8': 'B',
  '6': 'G',
  '7': 'T',
  '4': 'A',
};

/// The character as a digit, or null when OCR has no reason to confuse them.
String? digitFor(String char) {
  if (char.length != 1) return null;
  final int code = char.codeUnitAt(0);
  if (code >= 48 && code <= 57) return char;
  return _asDigit[char];
}

/// The character as an upper-case letter, or null when it cannot be one.
String? letterFor(String char) {
  if (char.length != 1) return null;
  final String upper = char.toUpperCase();
  final int code = upper.codeUnitAt(0);
  if (code >= 65 && code <= 90) return upper;
  return _asLetter[char];
}

final RegExp _word = RegExp(r'\S+');

/// Rewrites confusable letters as digits inside number-shaped words.
///
/// A word qualifies when at least half of its letters-or-digits are digits
/// and every other character is a confusable letter or a `/`, `-` or `.`
/// separator. "4l11" becomes "4111" and "O9/28" becomes "09/28".
String fixDigitWords(String text) {
  return text.replaceAllMapped(_word, (Match match) {
    final String word = match.group(0)!;
    var digits = 0;
    var confusable = 0;
    for (var i = 0; i < word.length; i++) {
      final String c = word[i];
      final int code = c.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        digits++;
      } else if (_asDigit.containsKey(c)) {
        confusable++;
      } else if (c != '/' && c != '-' && c != '.') {
        return word;
      }
    }
    if (confusable == 0 || digits < 2 || digits < confusable) return word;
    final StringBuffer out = StringBuffer();
    for (var i = 0; i < word.length; i++) {
      out.write(_asDigit[word[i]] ?? word[i]);
    }
    return out.toString();
  });
}

/// The digit runs of [text] in reading order, after [fixDigitWords].
List<String> digitRuns(String text) {
  return RegExp(r'\d+')
      .allMatches(fixDigitWords(text))
      .map((Match match) => match.group(0)!)
      .toList();
}
