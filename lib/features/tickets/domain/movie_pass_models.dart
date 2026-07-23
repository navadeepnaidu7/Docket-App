import 'package:flutter/material.dart';

import 'pass_status.dart';

export 'pass_status.dart' show TicketStatus;

/// Where the booking originated — drives brand palette + layout.
///
/// Wire: `"bookMyShow"` | `"district"` | `"universal"`.
enum MoviePassBrand {
  bookMyShow,
  district,
  universal;

  static MoviePassBrand fromJson(Object? raw) {
    final String s = raw?.toString() ?? '';
    final String n = s.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    return switch (n) {
      'bookmyshow' || 'bms' => MoviePassBrand.bookMyShow,
      'district' || 'districtbyzomato' => MoviePassBrand.district,
      _ => MoviePassBrand.universal,
    };
  }

  String toJson() => name;
}

/// Gate entry code shown on the e-ticket (one per booking).
///
/// Wire: `"qr"` | `"barcode"`.
enum MovieTicketCodeType {
  qr,
  barcode;

  static MovieTicketCodeType fromJson(Object? raw) {
    final String s = raw?.toString().toLowerCase() ?? '';
    return s.contains('bar')
        ? MovieTicketCodeType.barcode
        : MovieTicketCodeType.qr;
  }

  String toJson() => name;
}

/// One seat on a movie booking.
class MovieSeat {
  const MovieSeat({
    required this.row,
    required this.number,
  });

  final String row;
  final String number;

  String get label => '$row$number';

  factory MovieSeat.fromJson(Map<String, dynamic> json) {
    return MovieSeat(
      row: json['row']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'row': row,
        'number': number,
      };
}

/// Brand colors for wallet faces and detail chrome (UI-only, not API).
class MovieBrandPalette {
  const MovieBrandPalette({
    required this.top,
    required this.bottom,
    required this.accent,
    required this.onAccent,
    required this.glow,
  });

  final Color top;
  final Color bottom;
  final Color accent;
  final Color onAccent;
  final Color glow;

  static const MovieBrandPalette bookMyShow = MovieBrandPalette(
    top: Color(0xFFD22533),
    bottom: Color(0xFF9E121E),
    accent: Color(0xFFFFB3C1),
    onAccent: Colors.white,
    glow: Color(0xFFE22636),
  );

  static const MovieBrandPalette district = MovieBrandPalette(
    top: Color(0xFF6B42F6),
    bottom: Color(0xFF7A3FF8),
    accent: Color(0xFFB5A3FF),
    onAccent: Colors.white,
    glow: Color(0xFF5F22D9),
  );

  static const MovieBrandPalette universal = MovieBrandPalette(
    top: Color(0xFF2C2C2E),
    bottom: Color(0xFF151517),
    accent: Color(0xFF8E8E93),
    onAccent: Colors.white,
    glow: Color(0xFF2C2C2E),
  );

  static const MovieBrandPalette expired = MovieBrandPalette(
    top: Color(0xFF3A3A3C),
    bottom: Color(0xFF1C1C1E),
    accent: Color(0xFF8E8E93),
    onAccent: Colors.white,
    glow: Color(0xFF636366),
  );

  static MovieBrandPalette forBrand(
    MoviePassBrand brand, {
    required bool active,
  }) {
    if (!active) return expired;
    return switch (brand) {
      MoviePassBrand.bookMyShow => bookMyShow,
      MoviePassBrand.district => district,
      MoviePassBrand.universal => universal,
    };
  }
}

/// Decorative poster gradient family (UI fallback, not required from API).
enum MoviePosterHint {
  action,
  romance,
  thriller,
  comedy,
  sciFi;

  static MoviePosterHint fromJson(Object? raw) {
    final String s = raw?.toString().toLowerCase() ?? '';
    return switch (s) {
      'romance' => MoviePosterHint.romance,
      'thriller' => MoviePosterHint.thriller,
      'comedy' => MoviePosterHint.comedy,
      'scifi' || 'sci_fi' || 'sci-fi' => MoviePosterHint.sciFi,
      _ => MoviePosterHint.action,
    };
  }

  String toJson() => name;
}

extension MoviePosterHintColors on MoviePosterHint {
  List<Color> get gradient => switch (this) {
        MoviePosterHint.action => const <Color>[
            Color(0xFF1E3A5F),
            Color(0xFF0F172A),
            Color(0xFF7C2D12),
          ],
        MoviePosterHint.romance => const <Color>[
            Color(0xFF4C1D95),
            Color(0xFF831843),
            Color(0xFFBE185D),
          ],
        MoviePosterHint.thriller => const <Color>[
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF334155),
          ],
        MoviePosterHint.comedy => const <Color>[
            Color(0xFFB45309),
            Color(0xFFD97706),
            Color(0xFFF59E0B),
          ],
        MoviePosterHint.sciFi => const <Color>[
            Color(0xFF0E7490),
            Color(0xFF1E3A8A),
            Color(0xFF312E81),
          ],
      };
}

class MoviePass {
  const MoviePass({
    required this.id,
    required this.brand,
    required this.movieTitle,
    required this.movieSubtitle,
    required this.cinemaName,
    required this.cinemaAddress,
    required this.screen,
    required this.showDate,
    required this.showTime,
    required this.format,
    required this.language,
    required this.seats,
    required this.bookingId,
    required this.orderId,
    required this.status,
    this.posterHint = MoviePosterHint.action,
    this.certification = 'UA',
    this.runtime = '2h 28m',
    this.gateType = 'QR Scan',
    this.sourcePlatform,
    this.codeType = MovieTicketCodeType.qr,
    this.codePayload,
    this.posterUrl,
    this.posterAsset,
    this.showAt,
  }) : assert(seats.length >= 1 && seats.length <= 10);

  final String id;
  final MoviePassBrand brand;
  final String movieTitle;
  final String movieSubtitle;
  final String cinemaName;
  final String cinemaAddress;
  final String screen;
  final String showDate;
  final String showTime;
  final String format;
  final String language;
  final List<MovieSeat> seats;
  final String bookingId;
  final String orderId;
  final TicketStatus status;
  final MoviePosterHint posterHint;
  final String certification;
  final String runtime;
  final String gateType;
  final String? sourcePlatform;
  final MovieTicketCodeType codeType;

  /// Raw payload for a real QR/barcode library (optional until backend ships it).
  final String? codePayload;

  /// Network poster URL from API (preferred).
  final String? posterUrl;

  /// Local asset path for demo fixtures only (not from API).
  final String? posterAsset;

  /// Preferred machine-readable show time (ISO-8601).
  final String? showAt;

  String get brandLabel => switch (brand) {
        MoviePassBrand.bookMyShow => 'BookMyShow',
        MoviePassBrand.district => 'District',
        MoviePassBrand.universal => 'Ticket',
      };

  String get brandMicro => switch (brand) {
        MoviePassBrand.bookMyShow => 'bookmyshow',
        MoviePassBrand.district => 'district',
        MoviePassBrand.universal => 'E-Ticket',
      };

  int get seatCount => seats.length;

  String get seatSummary {
    if (seats.length == 1) return seats.first.label;
    if (seats.length <= 3) {
      return seats.map((MovieSeat s) => s.label).join(', ');
    }
    return '${seats.take(2).map((s) => s.label).join(', ')} +${seats.length - 2}';
  }

  String get seatListLabel => seats.map((MovieSeat s) => s.label).join(', ');

  MovieBrandPalette palette({required bool forceActive}) {
    final bool active = forceActive || status == TicketStatus.active;
    return MovieBrandPalette.forBrand(brand, active: active);
  }

  /// Resolved poster for UI: explicit URL, else legacy title fallback.
  String get resolvedPosterUrl {
    if (posterUrl != null && posterUrl!.isNotEmpty) return posterUrl!;
    return switch (movieTitle) {
      'Dune: Part Two' =>
        'https://upload.wikimedia.org/wikipedia/en/7/72/Dune_Part_Two_poster.jpeg',
      'Kalki 2898 AD' =>
        'https://upload.wikimedia.org/wikipedia/en/c/c5/Kalki_2898_AD_poster.jpg',
      'Pushpa 2: The Rule' =>
        'https://upload.wikimedia.org/wikipedia/en/1/15/Pushpa_2_The_Rule_poster.jpg',
      _ =>
        'https://upload.wikimedia.org/wikipedia/en/0/0f/Spider-Man_No_Way_Home_poster.jpg',
    };
  }

  /// Resolved local asset when present (demo fixtures).
  String? get resolvedPosterAsset {
    if (posterAsset != null) return posterAsset;
    return switch (movieTitle) {
      'Dune: Part Two' => 'assets/passes/dune_poster.jpg',
      'Spider-Man: Brand New Day' => 'assets/passes/spiderman_poster.jpg',
      'The Odyssey' => 'assets/passes/odyssey_poster.jpg',
      _ => null,
    };
  }

  factory MoviePass.fromJson(Map<String, dynamic> json) {
    final List<dynamic> seatsRaw =
        json['seats'] is List ? json['seats'] as List : const [];
    final List<MovieSeat> seats = seatsRaw
        .whereType<Map>()
        .map((Map m) => MovieSeat.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    if (seats.isEmpty) {
      seats.add(const MovieSeat(row: 'A', number: '1'));
    }

    return MoviePass(
      id: json['id']?.toString() ?? '',
      brand: MoviePassBrand.fromJson(json['brand']),
      movieTitle: json['movieTitle']?.toString() ?? '',
      movieSubtitle: json['movieSubtitle']?.toString() ?? '',
      cinemaName: json['cinemaName']?.toString() ?? '',
      cinemaAddress: json['cinemaAddress']?.toString() ?? '',
      screen: json['screen']?.toString() ?? '',
      showDate: json['showDate']?.toString() ?? '',
      showTime: json['showTime']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      seats: seats,
      bookingId: json['bookingId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      status: TicketStatus.fromJson(json['status']),
      posterHint: MoviePosterHint.fromJson(json['posterHint']),
      certification: json['certification']?.toString() ?? 'UA',
      runtime: json['runtime']?.toString() ?? '',
      gateType: json['gateType']?.toString() ?? 'QR Scan',
      sourcePlatform: json['sourcePlatform']?.toString(),
      codeType: MovieTicketCodeType.fromJson(json['codeType']),
      codePayload: json['codePayload']?.toString(),
      posterUrl: json['posterUrl']?.toString(),
      posterAsset: json['posterAsset']?.toString(),
      showAt: json['showAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'brand': brand.toJson(),
        'movieTitle': movieTitle,
        'movieSubtitle': movieSubtitle,
        'cinemaName': cinemaName,
        'cinemaAddress': cinemaAddress,
        'screen': screen,
        'showDate': showDate,
        'showTime': showTime,
        'format': format,
        'language': language,
        'seats': seats.map((MovieSeat s) => s.toJson()).toList(),
        'bookingId': bookingId,
        'orderId': orderId,
        'status': status.toJson(),
        'posterHint': posterHint.toJson(),
        'certification': certification,
        'runtime': runtime,
        'gateType': gateType,
        if (sourcePlatform != null) 'sourcePlatform': sourcePlatform,
        'codeType': codeType.toJson(),
        if (codePayload != null) 'codePayload': codePayload,
        if (posterUrl != null) 'posterUrl': posterUrl,
        if (posterAsset != null) 'posterAsset': posterAsset,
        if (showAt != null) 'showAt': showAt,
      };
}
