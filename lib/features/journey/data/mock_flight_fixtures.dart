import '../domain/flight_itinerary.dart';

/// Demo flights, so the world level has something true to its own design.
///
/// Flights are not a pass kind yet (see [FlightItinerary]), and every real pass
/// the wallet holds is inside India — so without these the world view would be
/// a globe with one country lit and no arcs on it, which is not the feature
/// anyone agreed to build. These make the level judgeable now and cost nothing
/// later: when a real flight pass lands, `buildJourneyIndex` stops compiling,
/// gains one case, and this list returns empty.
///
/// Every airport code here resolves through the bundled place table to a city,
/// not to a terminal. At the zoom levels Journey supports, the difference is
/// under a pixel.
final List<FlightItinerary> mockFlightItineraries = <FlightItinerary>[
  FlightItinerary(
    id: 'mock_f1',
    airline: 'Emirates',
    flightNumber: 'EK 565',
    fromIata: 'BLR',
    toIata: 'DXB',
    fromCity: 'Bengaluru',
    toCity: 'Dubai',
    departAt: DateTime(2025, 11, 14, 4, 30),
    arriveAt: DateTime(2025, 11, 14, 7, 10),
  ),
  FlightItinerary(
    id: 'mock_f2',
    airline: 'Emirates',
    flightNumber: 'EK 007',
    fromIata: 'DXB',
    toIata: 'LHR',
    fromCity: 'Dubai',
    toCity: 'London',
    departAt: DateTime(2025, 11, 14, 9, 40),
    arriveAt: DateTime(2025, 11, 14, 14, 5),
  ),
  FlightItinerary(
    id: 'mock_f3',
    airline: 'British Airways',
    flightNumber: 'BA 119',
    fromIata: 'LHR',
    toIata: 'DEL',
    fromCity: 'London',
    toCity: 'New Delhi',
    departAt: DateTime(2025, 11, 28, 13, 20),
    arriveAt: DateTime(2025, 11, 29, 2, 15),
  ),
  FlightItinerary(
    id: 'mock_f4',
    airline: 'Singapore Airlines',
    flightNumber: 'SQ 509',
    fromIata: 'HYD',
    toIata: 'SIN',
    fromCity: 'Hyderabad',
    toCity: 'Singapore',
    departAt: DateTime(2025, 6, 2, 23, 55),
    arriveAt: DateTime(2025, 6, 3, 7, 20),
  ),
  FlightItinerary(
    id: 'mock_f5',
    airline: 'Thai Airways',
    flightNumber: 'TG 326',
    fromIata: 'SIN',
    toIata: 'BKK',
    fromCity: 'Singapore',
    toCity: 'Bangkok',
    departAt: DateTime(2025, 6, 9, 8, 15),
    arriveAt: DateTime(2025, 6, 9, 9, 40),
  ),
  FlightItinerary(
    id: 'mock_f6',
    airline: 'IndiGo',
    flightNumber: '6E 1512',
    fromIata: 'BKK',
    toIata: 'BLR',
    fromCity: 'Bangkok',
    toCity: 'Bengaluru',
    departAt: DateTime(2025, 6, 16, 11, 5),
    arriveAt: DateTime(2025, 6, 16, 13, 30),
  ),
];
