import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/features/boarding_pass/data/parsers/ocr_parser_service.dart';

/// Text as ML Kit returns it from photos/screenshots of real ticket layouts:
/// labels and values in varying orders, city names beside codes, values on
/// the line below their label.
void main() {
  late OcrParserService parser;
  final today = DateTime(2026, 9, 29);

  setUpAll(() {
    LocalAirportRegistry.instance.loadFromJsonString('''
    [
      {"iata": "MNL", "name": "Ninoy Aquino", "city": "Manila", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "large"},
      {"iata": "CEB", "name": "Mactan-Cebu", "city": "Cebu", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "large"},
      {"iata": "BKK", "name": "Suvarnabhumi", "city": "Bangkok", "countryCode": "TH", "timezone": "Asia/Bangkok", "airportType": "large"},
      {"iata": "SIN", "name": "Changi", "city": "Singapore", "countryCode": "SG", "timezone": "Asia/Singapore", "airportType": "large"},
      {"iata": "SFO", "name": "San Francisco", "city": "San Francisco", "countryCode": "US", "timezone": "America/Los_Angeles", "airportType": "large"},
      {"iata": "MAR", "name": "La Chinita", "city": "Maracaibo", "countryCode": "VE", "timezone": "America/Caracas", "airportType": "medium"},
      {"iata": "BAG", "name": "Loakan", "city": "Baguio", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "small"}
    ]
    ''');
    parser = OcrParserService(validator: LocalAirportRegistry.instance);
  });

  test('printed pass: city names beside codes, date without year', () {
    const text = '''
PHILIPPINE AIRLINES
BOARDING PASS
NAME SMITH/JOHN MR
FLIGHT PR 123   DATE 15OCT
FROM MANILA MNL
TO BANGKOK BKK
BOARDING TIME 05:50  GATE 112  SEAT 24A
''';
    final r = parser.parse(text, referenceDate: today)!;

    expect(r.flightNumber, 'PR123');
    expect(r.originIata, 'MNL');
    expect(r.destinationIata, 'BKK');
    expect(r.departureDateTime, DateTime(2026, 10, 15));
    expect(r.boardingDateTime, DateTime(2026, 10, 15, 5, 50));
    expect(r.gate, '112');
    expect(r.seat, '24A');
    expect(r.hasRequiredRoute, isTrue);
  });

  test('e-ticket screenshot: unlabelled flight, arrow route, 12h time', () {
    const text = '''
Cebu Pacific
5J 560
Manila (MNL) → Cebu (CEB)
Departure 15 Oct 2026 06:35 PM
Seat 12F
''';
    final r = parser.parse(text, referenceDate: today)!;

    expect(r.flightNumber, '5J560');
    expect(r.originIata, 'MNL');
    expect(r.destinationIata, 'CEB');
    expect(r.departureDateTime, DateTime(2026, 10, 15, 18, 35));
    expect(r.seat, '12F');
    // Time was read, so the form won't ask to confirm it.
    expect(r.confidence.departureTime, greaterThan(0));
  });

  test('column layout: every value on the line after its label', () {
    const text = '''
FLIGHT
SQ 32
FROM
SIN
TO
SFO
BOARDING TIME
08:45
DEPARTURE
09:30
DATE
01 OCT
GATE
B4
SEAT
42K
''';
    final r = parser.parse(text, referenceDate: today)!;

    expect(r.flightNumber, 'SQ32');
    expect(r.originIata, 'SIN');
    expect(r.destinationIata, 'SFO');
    expect(r.departureDateTime, DateTime(2026, 10, 1, 9, 30));
    expect(r.boardingDateTime, DateTime(2026, 10, 1, 8, 45));
    expect(r.gate, 'B4');
    expect(r.seat, '42K');
  });

  test('month and ticket words that are also IATA codes are not airports', () {
    // MAR (Maracaibo) and BAG (Baguio) are real codes.
    const text = '''
FLIGHT PR 2345
12 MAR 2027
BAG ALLOWANCE 20KG
MNL - CEB
''';
    final r = parser.parse(text, referenceDate: today)!;

    expect(r.originIata, 'MNL');
    expect(r.destinationIata, 'CEB');
    expect(r.departureDateTime, DateTime(2027, 3, 12));
  });

  test('gate and seat values are not taken as the flight number', () {
    const text = 'GATE A12  SEAT 12A\nMNL TO CEB\nFLIGHT 5J 991';
    final r = parser.parse(text, referenceDate: today)!;

    expect(r.flightNumber, '5J991');
    expect(r.gate, 'A12');
  });

  test('a year is never read as a time; dotted dates are not times', () {
    const text = 'DEPARTURE 15.10.2026\nFLIGHT PR 1\nMNL-CEB';
    final r = parser.parse(text, referenceDate: today)!;

    expect(r.confidence.departureTime, 0);
  });

  test('date without year rolls to next year once it has passed', () {
    final r = parser.parse(
      'FLIGHT PR 1 MNL-CEB DATE 05 JAN',
      referenceDate: DateTime(2026, 12, 20),
    )!;

    expect(r.departureDateTime, DateTime(2027, 1, 5));
  });

  test('text with no flight details yields no route', () {
    final r = parser.parse(
      'THANK YOU FOR SHOPPING\nTOTAL 450.00\nCASH',
      referenceDate: today,
    )!;

    expect(r.hasRequiredRoute, isFalse);
    expect(r.originIata, isEmpty);
  });
}
