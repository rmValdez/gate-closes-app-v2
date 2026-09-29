import 'dart:convert';

import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_image_reader.dart';

/// DEBUG-ONLY tooling for STEP 21 (real-ticket accuracy). Turns a real scan
/// into a redacted JSON fixture for `test/fixtures/tickets/`, which
/// `real_ticket_fixtures_test.dart` replays against the parsers.
///
/// Nothing here is reachable in release builds: the recorder is only created
/// under `kDebugMode` and the copy button is only built under `kDebugMode`.

/// How the raw input reached the parser. Stored in the fixture so the test
/// replays it through the same parser.
enum TicketCaptureSource { liveBarcode, photoBarcode, photoText, pastedText }

/// The raw input of the most recent extraction, before redaction.
class TicketCapture {
  const TicketCapture(this.source, this.raw, this.parsed);

  final TicketCaptureSource source;
  final String raw;

  /// What the parser produced (null if nothing usable).
  final ParsedFlight? parsed;
}

/// Wraps the real reader and remembers what it returned for the last image,
/// so the capture tool can record the raw barcode/OCR text.
class RecordingTicketImageReader implements TicketImageReader {
  RecordingTicketImageReader(this._inner);

  final TicketImageReader _inner;
  String? lastBarcode;
  String? lastText;
  String? _lastPath;

  void _startImage(String path) {
    if (path == _lastPath) return;
    _lastPath = path;
    lastBarcode = null;
    lastText = null;
  }

  @override
  Future<String?> readBarcode(String imagePath) async {
    _startImage(imagePath);
    return lastBarcode = await _inner.readBarcode(imagePath);
  }

  @override
  Future<String> readText(String imagePath) async {
    _startImage(imagePath);
    return lastText = await _inner.readText(imagePath);
  }
}

/// Best-effort removal of personal data from a captured ticket before it can
/// be saved as a fixture. Always review the output — OCR layouts vary.
class TicketFixtureRedactor {
  const TicketFixtureRedactor._();

  static const _labels =
      r'(?:NAME|PASSENGER|PAX|BOOKING(?:\s+REF(?:ERENCE)?)?|PNR|'
      r'CONFIRMATION(?:\s+(?:NO\.?|NUMBER|CODE))?|RECORD\s+LOCATOR|'
      r'E-?TICKET(?:\s+(?:NO\.?|NUMBER))?|TICKET\s+(?:NO\.?|NUMBER)|'
      r'FREQUENT\s+FLYER|FFP|MEMBER(?:SHIP)?(?:\s+(?:NO\.?|NUMBER))?|'
      'LOYALTY)';

  static String redact(String raw, TicketCaptureSource source) {
    switch (source) {
      case TicketCaptureSource.liveBarcode:
      case TicketCaptureSource.photoBarcode:
        return redactBcbp(raw);
      case TicketCaptureSource.pastedText:
        return raw.trimLeft().startsWith('M') && raw.trim().length >= 47
            ? redactBcbp(raw.trim())
            : redactText(raw);
      case TicketCaptureSource.photoText:
        return redactText(raw);
    }
  }

  /// Keeps only the first leg's mandatory 60 characters (drops the
  /// conditional section: ticket number, frequent-flyer number, ...) and
  /// blanks the name (2–21) and booking reference (23–29).
  static String redactBcbp(String raw) {
    if (raw.length < 30) return raw;
    final head = raw.length > 60 ? raw.substring(0, 60) : raw;
    return head.replaceRange(2, 22, 'REDACTED/PASSENGER  ').replaceRange(
          23,
          30,
          'XXXXXX ',
        );
  }

  /// Masks labelled values (NAME, PNR, TICKET NO, ...), SURNAME/GIVEN name
  /// patterns and 13-digit ticket numbers. A label alone on its line masks
  /// the next line too.
  static String redactText(String raw) {
    final lines = raw.split('\n');
    final labelAtEnd =
        RegExp('\\b$_labels\\s*[:#]?\\s*\$', caseSensitive: false);
    final labelWithValue =
        RegExp('(\\b$_labels\\b\\s*[:#]?\\s*)(.+)', caseSensitive: false);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (labelAtEnd.hasMatch(line.trimRight()) && i + 1 < lines.length) {
        lines[i + 1] = '[REDACTED]';
      }
      lines[i] = line.replaceAllMapped(
        labelWithValue,
        (m) => '${m.group(1)}[REDACTED]',
      );
    }
    return lines
        .join('\n')
        .replaceAll(
          RegExp(
            r"\b[A-Z][A-Z'\-]+/[A-Z][A-Z'\- ]*?(?:\s+(?:MR|MRS|MS|MISS|MSTR))?\b",
            caseSensitive: false,
          ),
          '[NAME]',
        )
        .replaceAll(RegExp(r'\b\d{3}[- ]?\d{10}\b'), '[TICKET]');
  }
}

/// Builds the pretty-printed fixture JSON. [expected] is the ground truth
/// the user confirmed in the form.
String buildTicketFixtureJson({
  required TicketCapture capture,
  required DateTime capturedOn,
  required Map<String, String?> expected,
}) {
  String? date(DateTime? d) => d?.toIso8601String().substring(0, 10);
  String? time(DateTime? d) => d == null
      ? null
      : '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
  final parsed = capture.parsed;

  return const JsonEncoder.withIndent('  ').convert({
    'source': capture.source.name,
    'capturedOn': date(capturedOn),
    'notes': '',
    'knownFailure': false,
    'input': TicketFixtureRedactor.redact(capture.raw, capture.source),
    'expected': expected,
    'parsedAtCapture': parsed == null
        ? null
        : {
            'flightNumber': parsed.flightNumber,
            'origin': parsed.originIata,
            'destination': parsed.destinationIata,
            'departureDate': date(parsed.departureDateTime),
            'departureTime': parsed.confidence.departureTime > 0
                ? time(parsed.departureDateTime)
                : null,
            'seat': parsed.seat,
            'gate': parsed.gate,
          },
  });
}
