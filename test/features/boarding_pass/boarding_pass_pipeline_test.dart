import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/features/boarding_pass/data/parsers/bcbp_parser_service.dart';
import 'package:gate_closes/features/boarding_pass/data/parsers/manual_flight_parser.dart';
import 'package:gate_closes/features/boarding_pass/data/parsers/ocr_parser_service.dart';
import 'package:gate_closes/features/boarding_pass/domain/enums/boarding_pass_source.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/confidence_engine.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/flight_normalizer.dart';

void main() {
  setUpAll(() {
    // Populate registry with test airport fixtures
    LocalAirportRegistry.instance.loadFromJsonString('''
    [
      {"iata": "MNL", "name": "Ninoy Aquino International Airport", "city": "Manila", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "large"},
      {"iata": "CEB", "name": "Mactan-Cebu International Airport", "city": "Cebu", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "large"},
      {"iata": "SIN", "name": "Singapore Changi Airport", "city": "Singapore", "countryCode": "SG", "timezone": "Asia/Singapore", "airportType": "large"},
      {"iata": "NRT", "name": "Narita International Airport", "city": "Tokyo", "countryCode": "JP", "timezone": "Asia/Tokyo", "airportType": "large"},
      {"iata": "SFO", "name": "San Francisco International Airport", "city": "San Francisco", "countryCode": "US", "timezone": "America/Los_Angeles", "airportType": "large"}
    ]
    ''');
  });

  group('FlightNormalizer Tests', () {
    test('normalizes flight numbers with hyphens and spaces', () {
      expect(
        FlightNormalizer.normalizeFlightNumber('pr-1847'),
        equals('PR1847'),
      );
      expect(
        FlightNormalizer.normalizeFlightNumber('ua 0892'),
        equals('UA892'),
      );
      expect(FlightNormalizer.normalizeFlightNumber('SQ32'), equals('SQ32'));
    });

    test('Julian date rollover calculates correct year across boundaries', () {
      // Reference date: Dec 30, 2026 (day 364)
      final refDec = DateTime(2026, 12, 30);
      // Julian day 3 is in early January of 2027
      final yearDec = FlightNormalizer.resolveJulianYear(3, refDec);
      expect(yearDec, equals(2027));

      // Reference date: Jan 2, 2027 (day 2)
      final refJan = DateTime(2027, 1, 2);
      // Julian day 364 is in late December of 2026
      final yearJan = FlightNormalizer.resolveJulianYear(364, refJan);
      expect(yearJan, equals(2026));

      // Normal mid-year flight (e.g. Day 180 on July 2026)
      final refJul = DateTime(2026, 7);
      final yearJul = FlightNormalizer.resolveJulianYear(180, refJul);
      expect(yearJul, equals(2026));
    });
  });

  group('BcbpParserService Tests', () {
    test('decodes valid IATA M1 standard boarding pass correctly', () {
      final parser =
          BcbpParserService(validator: LocalAirportRegistry.instance);
      // M1DOE/JOHN            EABC123 MNLCEBPR 1847 268Y018A0001 100
      const rawBcbp =
          'M1DOE/JOHN            EABC123 MNLCEBPR 1847 268Y018A0001 100';
      final result =
          parser.parse(rawBcbp, referenceDate: DateTime(2026, 9, 25));

      expect(result, isNotNull);
      expect(result!.originIata, equals('MNL'));
      expect(result.destinationIata, equals('CEB'));
      expect(result.flightNumber, equals('PR1847'));
      expect(result.seat, equals('018A'));
      expect(result.source, equals(BoardingPassSource.bcbp));
      expect(result.confidence.isHigh, isTrue);
      expect(result.confidence.overall, greaterThanOrEqualTo(0.95));
    });

    test('rejects malformed string cleanly', () {
      final parser =
          BcbpParserService(validator: LocalAirportRegistry.instance);
      expect(parser.parse('INVALID_BARCODE_DATA'), isNull);
    });

    test('rejects a string below the minimum 47-char BCBP field length', () {
      final parser =
          BcbpParserService(validator: LocalAirportRegistry.instance);
      expect(parser.parse('M1DOE/JOHN'), isNull);
    });

    // Ported from the legacy BcbpParser suite (bcbp_parser_test.dart, now
    // removed as dead code — see STEP 10d) to preserve edge-case coverage.
    // Note the behavior is NOT identical: the legacy parser rejected the
    // whole record (returned null) for an out-of-range Julian day. This
    // engine instead still returns a ParsedFlight with departureDateTime
    // left null (and a correspondingly lower confidence.departureDate score)
    // — a deliberate difference so an otherwise-decodable route/flight-number
    // isn't discarded over one bad field. Flagged as a documented behavior
    // change, not silently inherited.
    test(
        'leaves departureDateTime null for an out-of-range Julian day '
        'instead of rejecting the whole record', () {
      final parser =
          BcbpParserService(validator: LocalAirportRegistry.instance);
      const valid =
          'M1DOE/JOHN            EABC123 MNLCEBPR 1847 268Y018A0001 100';
      final invalidJulian = valid.replaceRange(44, 47, '999');

      final result =
          parser.parse(invalidJulian, referenceDate: DateTime(2026, 9, 25));

      expect(result, isNotNull);
      expect(result!.originIata, equals('MNL'));
      expect(result.destinationIata, equals('CEB'));
      expect(result.flightNumber, equals('PR1847'));
      expect(result.departureDateTime, isNull);
      expect(result.confidence.departureDate, equals(0.0));
    });

    test('parses BCBP with an empty/blank seat field as null seat', () {
      final parser =
          BcbpParserService(validator: LocalAirportRegistry.instance);
      const valid =
          'M1DOE/JOHN            EABC123 MNLCEBPR 1847 268Y018A0001 100';
      final blankSeat = valid.replaceRange(48, 52, '    ');

      final result =
          parser.parse(blankSeat, referenceDate: DateTime(2026, 9, 25));

      expect(result, isNotNull);
      expect(result!.seat, isNull);
      expect(result.originIata, equals('MNL'));
      expect(result.destinationIata, equals('CEB'));
    });
  });

  group('OcrParserService Tests', () {
    test(
        'extracts flight, route with layout keywords and calculates high '
        'confidence', () {
      final parser = OcrParserService(validator: LocalAirportRegistry.instance);
      const ocrText = '''
      BOARDING PASS
      FLIGHT: PR 1847
      FROM: MNL
      TO: CEB
      DATE: 2026-09-25
      SEAT: 18A
      GATE: 12
      ''';

      final result = parser.parse(ocrText);
      expect(result, isNotNull);
      expect(result!.flightNumber, equals('PR1847'));
      expect(result.originIata, equals('MNL'));
      expect(result.destinationIata, equals('CEB'));
      expect(result.seat, equals('18A'));
      expect(result.gate, equals('12'));
      expect(result.source, equals(BoardingPassSource.ocr));
      expect(result.confidence.overall, greaterThanOrEqualTo(0.85));
    });
  });

  group('ManualFlightParser Tests', () {
    test('generates valid ParsedFlight from manual fields', () {
      final parser =
          ManualFlightParser(validator: LocalAirportRegistry.instance);
      final result = parser.parse(
        flightNumber: 'sq-32',
        originIata: 'sin',
        destinationIata: 'sfo',
        departureDateTime: DateTime.utc(2026, 10, 1, 9, 30),
        gate: 'B4',
        seat: '42K',
      );

      expect(result.flightNumber, equals('SQ32'));
      expect(result.originIata, equals('SIN'));
      expect(result.destinationIata, equals('SFO'));
      expect(result.gate, equals('B4'));
      expect(result.seat, equals('42K'));
      expect(result.source, equals(BoardingPassSource.manual));
      expect(result.confidence.isHigh, isTrue);
    });
  });

  group('Confidence States and One-Way Route Tests', () {
    test('ParseConfidence flags high, medium, low states correctly', () {
      final high = ConfidenceEngine.calculate(
        hasValidFlightNumber: true,
        isOriginValidIata: true,
        isDestValidIata: true,
        hasValidDate: true,
        hasTime: false,
        isBcbpDecoded: true,
      );
      expect(high.isHigh, isTrue);

      final med = ConfidenceEngine.calculate(
        hasValidFlightNumber: true,
        isOriginValidIata: true,
        isDestValidIata: false,
        hasValidDate: true,
        hasTime: false,
      );
      expect(med.isMedium, isTrue);

      final low = ConfidenceEngine.calculate(
        hasValidFlightNumber: false,
        isOriginValidIata: false,
        isDestValidIata: false,
        hasValidDate: false,
        hasTime: false,
      );
      expect(low.isLow, isTrue);
    });
  });
}
