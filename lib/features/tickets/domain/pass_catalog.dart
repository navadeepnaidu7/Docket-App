import 'movie_pass_models.dart';
import 'ticket_models.dart';

/// Unified pass entry for the Passes tab (train + movie).
sealed class WalletPassItem {
  const WalletPassItem();

  String get id;
  TicketStatus get status;
  PassKind get kind;

  Map<String, dynamic> toJson();
}

final class TrainPassItem extends WalletPassItem {
  const TrainPassItem(this.ticket);
  final TrainPass ticket;

  @override
  String get id => ticket.id;

  @override
  TicketStatus get status => ticket.status;

  @override
  PassKind get kind => PassKind.train;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.toJson(),
        'train': ticket.toJson(),
      };

  factory TrainPassItem.fromJson(Map<String, dynamic> json) {
    final Object? nested = json['train'] ?? json;
    final Map<String, dynamic> map = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;
    return TrainPassItem(TrainPass.fromJson(map));
  }
}

final class MoviePassItem extends WalletPassItem {
  const MoviePassItem(this.pass);
  final MoviePass pass;

  @override
  String get id => pass.id;

  @override
  TicketStatus get status => pass.status;

  @override
  PassKind get kind => PassKind.movie;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.toJson(),
        'movie': pass.toJson(),
      };

  factory MoviePassItem.fromJson(Map<String, dynamic> json) {
    final Object? nested = json['movie'] ?? json;
    final Map<String, dynamic> map = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;
    return MoviePassItem(MoviePass.fromJson(map));
  }
}

/// Parses a single list item: `{ "kind": "train"|"movie", ... }`.
WalletPassItem walletPassItemFromJson(Map<String, dynamic> json) {
  final PassKind kind = PassKind.fromJson(json['kind']);
  return switch (kind) {
    PassKind.train => TrainPassItem.fromJson(json),
    PassKind.movie => MoviePassItem.fromJson(json),
  };
}

/// List envelope matching `GET /v1/passes`.
class PassListResponse {
  const PassListResponse({
    required this.items,
    this.updatedAt,
  });

  final List<WalletPassItem> items;
  final String? updatedAt;

  factory PassListResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        json['items'] is List ? json['items'] as List : const [];
    final List<WalletPassItem> items = <WalletPassItem>[];
    for (final dynamic e in raw) {
      if (e is! Map) continue;
      try {
        items.add(walletPassItemFromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
        // Skip malformed items so one bad pass doesn't break the wallet.
      }
    }
    return PassListResponse(
      items: items,
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items.map((WalletPassItem i) => i.toJson()).toList(),
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}

/// Active first (movies then trains), then expired — demo ordering.
List<WalletPassItem> buildWalletPassCatalog({
  required List<TrainPass> trains,
  required List<MoviePass> movies,
}) {
  final List<WalletPassItem> active = <WalletPassItem>[
    ...movies
        .where((MoviePass m) => m.status == TicketStatus.active)
        .map(MoviePassItem.new),
    ...trains
        .where((TrainPass t) => t.status == TicketStatus.active)
        .map(TrainPassItem.new),
  ];
  final List<WalletPassItem> expired = <WalletPassItem>[
    ...movies
        .where((MoviePass m) => m.status == TicketStatus.expired)
        .map(MoviePassItem.new),
    ...trains
        .where((TrainPass t) => t.status == TicketStatus.expired)
        .map(TrainPassItem.new),
  ];
  return <WalletPassItem>[...active, ...expired];
}
