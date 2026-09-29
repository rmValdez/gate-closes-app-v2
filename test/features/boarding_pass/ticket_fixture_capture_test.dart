import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/features/boarding_pass/data/parsers/bcbp_parser_service.dart';
import 'package:gate_closes/features/boarding_pass/presentation/debug/ticket_fixture_capture.dart';

void main() {
  // Mandatory 60 chars + conditional section; BCBP fields are fixed-width
  // with no separator between them.
  // ignore: missing_whitespace_between_adjacent_strings
  const bcbp = 'M1DOE/JOHN            EABC123 MNLCEBPR 1847 268Y018A0001 100'
      '>5180 B1A              2A07912345678900                           N';

  group('Core Invariant 5: no passenger identity in parsed results', () {
    setUpAll(() {
      LocalAirportRegistry.instance.loadFromJsonString('''
      [
        {"iata": "MNL", "name": "Ninoy Aquino", "city": "Manila", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "large"},
        {"iata": "CEB", "name": "Mactan-Cebu", "city": "Cebu", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "large"}
      ]
      ''');
    });

    test('BCBP parse carries no name, booking reference or raw payload', () {
      final result = BcbpParserService(validator: LocalAirportRegistry.instance)
          .parse(bcbp, referenceDate: DateTime(2026, 9, 25))!;

      final values = result.props.whereType<String>().join('|');
      expect(values, isNot(contains('DOE')));
      expect(values, isNot(contains('ABC123')));
      expect(result.flightNumber, 'PR1847');
    });
  });

  group('TicketFixtureRedactor', () {
    test('BCBP: blanks name + booking ref, drops the conditional section', () {
      final out = TicketFixtureRedactor.redactBcbp(bcbp);

      expect(out, isNot(contains('DOE')));
      expect(out, isNot(contains('ABC123')));
      expect(out, isNot(contains('0791234567890'))); // ticket number
      expect(out.length, 60);
      // Flight fields keep their positions, so the fixture still parses.
      expect(out.substring(30, 47), bcbp.substring(30, 47));
    });

    test('text: masks labelled values, names and ticket numbers', () {
      const raw = '''
NAME: SMITH/JOHN MR
BOOKING REF ABC123
E-TICKET 079 1234567890
PASSENGER
DELA CRUZ/MARIA MS
FLIGHT PR 123
FROM MNL TO CEB
FREQUENT FLYER PR 12345678''';

      final out = TicketFixtureRedactor.redactText(raw);

      for (final secret in [
        'SMITH',
        'JOHN',
        'ABC123',
        '1234567890',
        'MARIA',
        'CRUZ',
        '12345678',
      ]) {
        expect(out, isNot(contains(secret)), reason: secret);
      }
      // Flight details survive.
      expect(out, contains('FLIGHT PR 123'));
      expect(out, contains('FROM MNL TO CEB'));
    });
  });
}
