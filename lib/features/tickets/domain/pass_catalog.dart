import 'movie_pass_models.dart';
import 'ticket_models.dart';

/// Unified pass entry for the Passes tab (train + movie).
sealed class WalletPassItem {
  const WalletPassItem();

  String get id;
  TicketStatus get status;
}

final class TrainPassItem extends WalletPassItem {
  const TrainPassItem(this.ticket);
  final MockTicket ticket;

  @override
  String get id => ticket.id;

  @override
  TicketStatus get status => ticket.status;
}

final class MoviePassItem extends WalletPassItem {
  const MoviePassItem(this.pass);
  final MoviePass pass;

  @override
  String get id => pass.id;

  @override
  TicketStatus get status => pass.status;
}

/// Active first (movies interleaved with trains), then expired.
List<WalletPassItem> buildWalletPassCatalog() {
  final List<WalletPassItem> active = <WalletPassItem>[
    // Lead with movie brands so they're visible immediately
    ...mockMoviePasses
        .where((MoviePass m) => m.status == TicketStatus.active)
        .map(MoviePassItem.new),
    ...mockTickets
        .where((MockTicket t) => t.status == TicketStatus.active)
        .map(TrainPassItem.new),
  ];
  final List<WalletPassItem> expired = <WalletPassItem>[
    ...mockMoviePasses
        .where((MoviePass m) => m.status == TicketStatus.expired)
        .map(MoviePassItem.new),
    ...mockTickets
        .where((MockTicket t) => t.status == TicketStatus.expired)
        .map(TrainPassItem.new),
  ];
  return <WalletPassItem>[...active, ...expired];
}

final List<WalletPassItem> mockWalletPasses = buildWalletPassCatalog();
