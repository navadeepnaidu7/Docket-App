/// Agreement across camera frames.
///
/// One frame of OCR is a guess. The same value read from several frames in a
/// row is very unlikely to be a misread, because the misreads move with focus,
/// glare and hand shake while the printed value does not.
class FieldVotes {
  final Map<String, double> _weights = <String, double>{};
  double _total = 0;

  /// Records one reading. Empty values are not votes.
  void add(String value, {double weight = 1}) {
    if (value.isEmpty || weight <= 0) return;
    _weights[value] = (_weights[value] ?? 0) + weight;
    _total += weight;
  }

  bool get isEmpty => _weights.isEmpty;

  /// The value with the most weight, or empty when nothing has been read.
  String get leader {
    String best = '';
    var bestWeight = 0.0;
    _weights.forEach((String value, double weight) {
      if (weight > bestWeight) {
        best = value;
        bestWeight = weight;
      }
    });
    return best;
  }

  double get leaderWeight => _weights[leader] ?? 0;

  /// The leader's share of every vote cast, from 0 to 1.
  double get share => _total == 0 ? 0 : leaderWeight / _total;

  /// True once the leader has [minWeight] behind it and at least [minShare]
  /// of the votes, so a value read twice against ten other readings does not
  /// count as settled.
  bool settled({double minWeight = 3, double minShare = 0.6}) =>
      leaderWeight >= minWeight && share >= minShare;

  void clear() {
    _weights.clear();
    _total = 0;
  }
}
