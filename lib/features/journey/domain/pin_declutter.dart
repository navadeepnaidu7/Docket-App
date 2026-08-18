import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Nudges overlapping markers apart until each has breathing room.
///
/// Venues inside one city sit within a fraction of a degree, so at city level
/// half a dozen memories project onto nearly the same pixel and stack into an
/// unreadable pile. Two relaxation passes separate them enough to be tappable
/// while keeping each one visibly attached to where it happened.
///
/// Deterministic: the same input always gives the same output, so a settled
/// camera produces settled pins. Running this per frame is therefore safe, and
/// cheap — the marker count is tens, not thousands.
///
/// Returns a new list in the same order as [positions].
List<Offset> declutter(
  List<Offset> positions, {
  required double minSpacing,
  int iterations = 2,
}) {
  if (positions.length < 2) return List<Offset>.of(positions);

  final List<Offset> out = List<Offset>.of(positions);
  final double minSq = minSpacing * minSpacing;

  for (int pass = 0; pass < iterations; pass++) {
    for (int i = 0; i < out.length; i++) {
      for (int j = i + 1; j < out.length; j++) {
        final double dx = out[j].dx - out[i].dx;
        final double dy = out[j].dy - out[i].dy;
        final double distSq = dx * dx + dy * dy;
        if (distSq >= minSq) continue;

        // Exactly coincident points have no direction to separate along, so
        // fan them by index instead of leaving them stacked forever.
        if (distSq < 1e-6) {
          final double angle = (i * 2.399963) + j;
          final double half = minSpacing * 0.5;
          out[i] = out[i].translate(-math.cos(angle) * half, -math.sin(angle) * half);
          out[j] = out[j].translate(math.cos(angle) * half, math.sin(angle) * half);
          continue;
        }

        final double dist = math.sqrt(distSq);
        final double push = (minSpacing - dist) * 0.5;
        final double nx = dx / dist;
        final double ny = dy / dist;
        out[i] = out[i].translate(-nx * push, -ny * push);
        out[j] = out[j].translate(nx * push, ny * push);
      }
    }
  }
  return out;
}
