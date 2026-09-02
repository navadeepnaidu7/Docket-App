import 'place.dart';

/// Turns a [PlaceQuery] into a [Place], or admits it cannot.
///
/// [lookup] is synchronous on purpose. It lets the whole journey index be a
/// pure fold inside a plain Riverpod `Provider` — the same shape
/// `spaceArchiveAnalyticsProvider` already uses — instead of dragging `async`
/// through indexing, clustering and every consumer of both. An implementation
/// that needs I/O does it once in [ensureReady] and then answers from memory.
abstract interface class PlaceResolver {
  /// Looks up an already-loaded place. Returning null is a normal outcome.
  Place? lookup(PlaceQuery query);

  /// Loads whatever backs [lookup]. Safe to call more than once.
  Future<void> ensureReady();
}

/// Resolves nothing.
///
/// This is what the app renders with while the bundled table is still loading,
/// and it is why Journey needs no spinner: the globe draws immediately with
/// zero placed memories and every pass listed as unplaced, then rebuilds once
/// the real resolver arrives. An empty globe for one frame beats a spinner.
final class EmptyPlaceResolver implements PlaceResolver {
  const EmptyPlaceResolver();

  @override
  Place? lookup(PlaceQuery query) => null;

  @override
  Future<void> ensureReady() async {}
}
