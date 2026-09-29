import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/boarding_pass_coordinator.dart';

/// Replays every captured ticket in test/fixtures/tickets/ (see the README
/// there) through the parser it originally went through, checks each field
/// against the user-confirmed ground truth, and prints per-field accuracy.
///
/// This is the STEP 21 accuracy measurement: add real tickets, watch the
/// numbers, fix the parser against actual failures.
void main() {
  final fixtures = Directory('test/fixtures/tickets')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  late BoardingPassCoordinator coordinator;

  // field -> [correct, checked]
  final tally = <String, List<int>>{};
  var complete = 0;

  setUpAll(() {
    // The real bundled registry, so fixtures see the same codes as the app.
    LocalAirportRegistry.instance.loadFromJsonString(
      File('assets/data/airports.json').readAsStringSync(),
    );
    coordinator =
        BoardingPassCoordinator(validator: LocalAirportRegistry.instance);
  });

  tearDownAll(() {
    if (fixtures.isEmpty) return;
    final buffer = StringBuffer()
      ..writeln()
      ..writeln('Real-ticket accuracy (${fixtures.length} fixtures)')
      ..writeln(
        '  complete route (flight + both airports): '
        '$complete/${fixtures.length}',
      );
    for (final entry in tally.entries) {
      final [correct, checked] = entry.value;
      final pct = checked == 0 ? 0 : (100 * correct / checked).round();
      buffer.writeln(
        '  ${entry.key.padRight(14)} $correct/$checked  ($pct%)',
      );
    }
    // The report is the point of this suite; surface it in test output.
    // ignore: avoid_print
    print(buffer);
  });

  for (final file in fixtures) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final name = file.uri.pathSegments.last;
    final knownFailure = json['knownFailure'] == true;

    test(
      name,
      () {
        final parsed = _replay(coordinator, json);
        if (parsed?.hasRequiredRoute ?? false) complete++;

        final actual = _fields(parsed);
        final expected = (json['expected'] as Map).cast<String, dynamic>();
        final mismatches = <String>[];
        for (final MapEntry(:key, :value) in expected.entries) {
          if (value == null) continue; // not printed on the ticket
          final ok = actual[key] == value;
          final counts = tally.putIfAbsent(key, () => [0, 0]);
          counts[1]++;
          if (ok) {
            counts[0]++;
          } else {
            mismatches.add('$key: expected "$value", got "${actual[key]}"');
          }
        }
        // A known failure still runs (so it's tallied) but never fails CI.
        if (!knownFailure) {
          expect(mismatches, isEmpty, reason: '${json['notes'] ?? ''}');
        }
      },
    );
  }
}

ParsedFlight? _replay(
  BoardingPassCoordinator coordinator,
  Map<String, dynamic> json,
) {
  final input = json['input'] as String;
  final today = DateTime.parse(json['capturedOn'] as String);
  switch (json['source']) {
    case 'liveBarcode':
    case 'photoBarcode':
      return coordinator.parseBarcode(input, referenceDate: today);
    case 'photoText':
      return coordinator.parseText(input, referenceDate: today);
    case 'pastedText':
      return coordinator.parseRaw(input, referenceDate: today);
    default:
      throw ArgumentError('Unknown fixture source: ${json['source']}');
  }
}

Map<String, String?> _fields(ParsedFlight? f) {
  if (f == null) return const {};
  final d = f.departureDateTime;
  String two(int n) => n.toString().padLeft(2, '0');
  return {
    'flightNumber': f.flightNumber.isEmpty ? null : f.flightNumber,
    'origin': f.originIata.isEmpty ? null : f.originIata,
    'destination': f.destinationIata.isEmpty ? null : f.destinationIata,
    'departureDate':
        d == null ? null : '${d.year}-${two(d.month)}-${two(d.day)}',
    'departureTime': d != null && f.confidence.departureTime > 0
        ? '${two(d.hour)}:${two(d.minute)}'
        : null,
    'seat': f.seat,
    'gate': f.gate,
  };
}
