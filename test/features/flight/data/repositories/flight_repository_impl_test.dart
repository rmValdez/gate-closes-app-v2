// Locks in the wire-level contract for idempotencyKey (STEP 10b): the client
// generates one key per submission attempt (see BoardingPassScannerSheet)
// and this repository must forward it verbatim on the create path so the
// server's (userId, idempotencyKey) idempotency check can actually work.
// Without this, a client-side regression that stops sending the key would
// only surface as silent duplicate tickets in production — nothing else in
// the suite would catch it.
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/flight/data/repositories/flight_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApi;
  late FlightRepositoryImpl repository;

  setUp(() {
    mockApi = MockApiService();
    repository = FlightRepositoryImpl(mockApi);
  });

  group('FlightRepositoryImpl.createFlightTicket', () {
    final departure = DateTime.utc(2026, 9, 25, 6, 35);

    test('forwards idempotencyKey in the POST payload when provided', () async {
      when(
        () => mockApi.postWith(
          any(),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => {'message': 'Flight ticket created.'},
      );

      await repository.createFlightTicket(
        flightNumber: 'PR1847',
        fromAirport: 'MNL',
        toAirport: 'CEB',
        departureDateTime: departure,
        idempotencyKey: '01K9X8QK7ZC1N3F7T8Q9R2W4YB',
      );

      final captured = verify(
        () => mockApi.postWith(
          ApiEndpoints.flightTicket,
          body: captureAny(named: 'body'),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured;
      final payload = captured.first as Map<String, dynamic>;

      expect(payload['idempotencyKey'], equals('01K9X8QK7ZC1N3F7T8Q9R2W4YB'));
      // Also sent as the header so the transport may retry it safely.
      expect(captured.last, equals('01K9X8QK7ZC1N3F7T8Q9R2W4YB'));
    });

    test('omits idempotencyKey entirely when not provided', () async {
      when(
        () => mockApi.postWith(
          any(),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => {'message': 'Flight ticket created.'},
      );

      await repository.createFlightTicket(
        flightNumber: 'PR1847',
        fromAirport: 'MNL',
        toAirport: 'CEB',
        departureDateTime: departure,
      );

      final captured = verify(
        () => mockApi.postWith(
          ApiEndpoints.flightTicket,
          body: captureAny(named: 'body'),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured;
      final payload = captured.first as Map<String, dynamic>;

      expect(payload.containsKey('idempotencyKey'), isFalse);
      expect(captured.last, isNull);
    });
  });

  group('FlightRepositoryImpl.updateFlightTicket', () {
    // STEP 10c / B-6 regression: editing an existing ticket used to silently
    // drop gate/seat/terminal/boardingDateTime because updateFlightTicket
    // had no params for them at all — the PUT body simply never contained
    // the fields, and the backend's Joi schema stripped them even when it
    // did (stripUnknown: true with no entry for them). Both sides are fixed
    // together; this test guards the client half of that contract.
    test('forwards gate/seat/terminal/boardingDateTime in the PUT payload',
        () async {
      when(() => mockApi.put(any(), any())).thenAnswer(
        (_) async => {'message': 'Ticket updated successfully'},
      );

      final boarding = DateTime.utc(2026, 9, 25, 6);

      await repository.updateFlightTicket(
        gate: '12',
        seat: '18A',
        terminal: '3',
        boardingDateTime: boarding,
      );

      final captured = verify(
        () => mockApi.put(ApiEndpoints.flightTicket, captureAny()),
      ).captured;
      final payload = captured.single as Map<String, dynamic>;

      expect(payload['gate'], equals('12'));
      expect(payload['seat'], equals('18A'));
      expect(payload['terminal'], equals('3'));
      expect(payload['boardingDateTime'], equals(boarding.toIso8601String()));
    });

    test('omits gate/seat/terminal/boardingDateTime when not provided',
        () async {
      when(() => mockApi.put(any(), any())).thenAnswer(
        (_) async => {'message': 'Ticket updated successfully'},
      );

      await repository.updateFlightTicket(flightNumber: 'PR1847');

      final captured = verify(
        () => mockApi.put(ApiEndpoints.flightTicket, captureAny()),
      ).captured;
      final payload = captured.single as Map<String, dynamic>;

      expect(payload.containsKey('gate'), isFalse);
      expect(payload.containsKey('seat'), isFalse);
      expect(payload.containsKey('terminal'), isFalse);
      expect(payload.containsKey('boardingDateTime'), isFalse);
    });
  });
}
