import 'package:flutter/material.dart';

import 'ticket_models.dart' show TicketStatus;

/// Where the booking originated — drives brand palette + layout.
enum MoviePassBrand {
  bookMyShow,
  district,
  universal,
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
}

/// Brand colors for wallet faces and detail chrome.
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

  /// BookMyShow — brand carnation pink/red (#F84464).
  static const MovieBrandPalette bookMyShow = MovieBrandPalette(
    top: Color(0xFFD22533),
    bottom: Color(0xFF9E121E),
    accent: Color(0xFFFFB3C1),
    onAccent: Colors.white,
    glow: Color(0xFFE22636),
  );

  /// District by Zomato — redesigned purple/violet gradient.
  static const MovieBrandPalette district = MovieBrandPalette(
    top: Color(0xFF492FBD),
    bottom: Color(0xFF7A3FF2),
    accent: Color(0xFFB5A3FF),
    onAccent: Colors.white,
    glow: Color(0xFF5F22D9),
  );

  /// Universal e-ticket — periwinkle from the reference mock.
  static const MovieBrandPalette universal = MovieBrandPalette(
    top: Color(0xFF7B8CFF),
    bottom: Color(0xFF5B6BE0),
    accent: Color(0xFFA5B4FF),
    onAccent: Colors.white,
    glow: Color(0xFF818CF8),
  );

  static const MovieBrandPalette expired = MovieBrandPalette(
    top: Color(0xFF3A3A3C),
    bottom: Color(0xFF1C1C1E),
    accent: Color(0xFF8E8E93),
    onAccent: Colors.white,
    glow: Color(0xFF636366),
  );

  static MovieBrandPalette forBrand(MoviePassBrand brand, {required bool active}) {
    if (!active) return expired;
    return switch (brand) {
      MoviePassBrand.bookMyShow => bookMyShow,
      MoviePassBrand.district => district,
      MoviePassBrand.universal => universal,
    };
  }
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
  }) : assert(seats.length >= 1 && seats.length <= 10);

  final String id;
  final MoviePassBrand brand;
  final String movieTitle;

  /// Genre / tagline line under the title (e.g. "Action · UA").
  final String movieSubtitle;
  final String cinemaName;
  final String cinemaAddress;
  final String screen;
  final String showDate;
  final String showTime;

  /// e.g. "IMAX 2D", "4DX", "Dolby Atmos".
  final String format;
  final String language;
  final List<MovieSeat> seats;
  final String bookingId;
  final String orderId;
  final TicketStatus status;
  final MoviePosterHint posterHint;
  final String certification;
  final String runtime;

  /// Check-in style label (VIP, QR Scan, etc.).
  final String gateType;

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

  String get posterUrl => switch (movieTitle) {
        'Dune: Part Two' => 'https://upload.wikimedia.org/wikipedia/en/7/72/Dune_Part_Two_poster.jpeg',
        'Kalki 2898 AD' => 'https://upload.wikimedia.org/wikipedia/en/c/c5/Kalki_2898_AD_poster.jpg',
        'Pushpa 2: The Rule' => 'https://upload.wikimedia.org/wikipedia/en/1/15/Pushpa_2_The_Rule_poster.jpg',
        _ => 'https://upload.wikimedia.org/wikipedia/en/0/0f/Spider-Man_No_Way_Home_poster.jpg',
      };

  String? get posterAsset => switch (movieTitle) {
        'Dune: Part Two' => 'assets/passes/dune_poster.jpg',
        _ => null,
      };
}

/// Decorative poster gradient family (no external image assets).
enum MoviePosterHint {
  action,
  romance,
  thriller,
  comedy,
  sciFi,
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

// ── Mock catalogue ────────────────────────────────────────────────────────────

final List<MoviePass> mockMoviePasses = <MoviePass>[
  // BookMyShow — active
  MoviePass(
    id: 'movie_bms_1',
    brand: MoviePassBrand.bookMyShow,
    movieTitle: 'Dune: Part Two',
    movieSubtitle: 'Sci-Fi · UA 13+',
    cinemaName: 'PVR INOX Phoenix Mall',
    cinemaAddress: 'Phoenix Marketcity, Whitefield, Bengaluru',
    screen: 'Screen 5 · IMAX',
    showDate: 'Sat, 12 Apr 2025',
    showTime: '7:15 PM',
    format: 'IMAX 2D',
    language: 'English',
    seats: const <MovieSeat>[
      MovieSeat(row: 'H', number: '12'),
      MovieSeat(row: 'H', number: '13'),
    ],
    bookingId: 'BMS-8F2K9P1Q',
    orderId: 'ORD99763JS',
    status: TicketStatus.active,
    posterHint: MoviePosterHint.sciFi,
    certification: 'UA 13+',
    runtime: '2h 46m',
    gateType: 'QR Scan',
  ),

  // District — active
  MoviePass(
    id: 'movie_dist_1',
    brand: MoviePassBrand.district,
    movieTitle: 'Pushpa 2: The Rule',
    movieSubtitle: 'Action · UA',
    cinemaName: 'Cinepolis Nexus Mall',
    cinemaAddress: 'Nexus Koramangala, Bengaluru',
    screen: 'Audi 3',
    showDate: 'Sun, 13 Apr 2025',
    showTime: '10:00 PM',
    format: 'Dolby Atmos',
    language: 'Telugu',
    seats: const <MovieSeat>[
      MovieSeat(row: 'F', number: '08'),
      MovieSeat(row: 'F', number: '09'),
      MovieSeat(row: 'F', number: '10'),
    ],
    bookingId: 'DST-4A71C2E9',
    orderId: 'DZM8821456',
    status: TicketStatus.active,
    posterHint: MoviePosterHint.action,
    certification: 'UA',
    runtime: '3h 20m',
    gateType: 'QR Scan',
  ),

  // Universal — active (reference-style e-ticket)
  MoviePass(
    id: 'movie_uni_1',
    brand: MoviePassBrand.universal,
    movieTitle: 'Spider-Man: Brand New Day',
    movieSubtitle: 'Action · UA',
    cinemaName: 'Miraj Cinemas Orion',
    cinemaAddress: 'Orion Mall, Rajajinagar, Bengaluru',
    screen: 'Screen 2',
    showDate: 'Fri, 18 Apr 2025',
    showTime: '6:30 PM',
    format: '2D',
    language: 'English',
    seats: const <MovieSeat>[
      MovieSeat(row: 'J', number: '05'),
      MovieSeat(row: 'J', number: '06'),
    ],
    bookingId: 'TKT-GBD99763',
    orderId: 'GBD99763JS',
    status: TicketStatus.active,
    posterHint: MoviePosterHint.action,
    certification: 'UA',
    runtime: '2h 15m',
    gateType: 'Standard',
  ),

  // BookMyShow — expired
  MoviePass(
    id: 'movie_bms_2',
    brand: MoviePassBrand.bookMyShow,
    movieTitle: 'Kalki 2898 AD',
    movieSubtitle: 'Sci-Fi · UA',
    cinemaName: 'INOX Garuda Mall',
    cinemaAddress: 'Magrath Road, Bengaluru',
    screen: 'Screen 1',
    showDate: 'Mon, 10 Feb 2025',
    showTime: '4:00 PM',
    format: '4DX',
    language: 'Hindi',
    seats: const <MovieSeat>[
      MovieSeat(row: 'D', number: '14'),
    ],
    bookingId: 'BMS-1A2B3C4D',
    orderId: 'ORD44120XZ',
    status: TicketStatus.expired,
    posterHint: MoviePosterHint.sciFi,
    certification: 'UA',
    runtime: '3h 01m',
  ),
];
