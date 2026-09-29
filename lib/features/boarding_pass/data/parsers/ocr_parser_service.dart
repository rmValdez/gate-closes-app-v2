import 'dart:math' as math;

import 'package:gate_closes/core/airports/airport_code_validator.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';
import 'package:gate_closes/features/boarding_pass/domain/enums/boarding_pass_source.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/confidence_engine.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/flight_normalizer.dart';

/// Parses free text read off a ticket — photo OCR or pasted text.
///
/// Strategy per field: an explicit label wins ("FLIGHT PR 1847",
/// "FROM MNL"), then a layout pattern ("MNL → CEB"), then — for airports
/// only — the first valid IATA codes in reading order. Each fallback lowers
/// confidence so the confirmation form asks the user to review.
///
/// Times are device-local wall-clock time, matching the manual date picker:
/// printed times are local to the departure airport, where the user normally
/// is when adding the ticket.
class OcrParserService {
  const OcrParserService({required this.validator});
  final AirportCodeValidator validator;

  static const Map<String, int> _months = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  /// Three-letter words common on tickets that are *also* valid IATA codes
  /// (MAR, MAY, NOV, BAG, ...). Never treated as airports by the fallbacks.
  static const Set<String> _stopwords = {
    'THE', 'AND', 'FOR', 'YOU', 'ARE', 'NOT', 'ALL', 'ONE', 'TWO', 'VIA', //
    'PNR', 'ETC', 'PAX', 'SEQ', 'BAG', 'MRS', 'MSS', 'CHD', 'INF', 'ADT', //
    'DEP', 'ARR', 'ETD', 'ETA', 'STD', 'STA', 'GMT', 'UTC', 'WEB', 'APP', //
    'VIP', 'ECO', 'BUS', 'AIR', 'NON', 'REF', 'TKT', 'NUM', 'FLT', 'ROW', //
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', //
    'NOV', 'DEC', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN', //
  };

  /// Airline designator (2 chars, at least one letter) + 1–4 digits.
  static const String _flightCode =
      r'([A-Z]{2}|[A-Z]\d|\d[A-Z])\s?-?\s?(\d{1,4})';

  ParsedFlight? parse(String text, {DateTime? referenceDate}) {
    if (text.trim().isEmpty) return null;
    final upper = text.toUpperCase();
    final now = referenceDate ?? DateTime.now();

    final flightNumber = _extractFlightNumber(upper);
    final route = _extractRoute(upper);
    final date = _extractDate(upper, now);
    final departureTime = _extractTime(
      upper,
      r'(?:DEPART(?:URE|S)?(?:\s+TIME)?|DEP(?:\s+TIME)?|ETD|STD)',
    );
    final boardingTime = _extractTime(
      upper,
      r'(?:BOARDING(?:\s+TIME)?|BOARDS?|BRD)',
    );

    DateTime? at(({int hour, int minute})? t) => date == null || t == null
        ? null
        : DateTime(date.year, date.month, date.day, t.hour, t.minute);

    final seat = RegExp(r'\bSEAT\b\s*(?:NO\.?)?\s*[:\-]?\s*(\d{1,2}[A-K])\b')
        .firstMatch(upper)
        ?.group(1);
    final gate = RegExp(r'\bGATE\b\s*[:\-]?\s*([A-Z]?\d{1,3}[A-Z]?)\b')
        .firstMatch(upper)
        ?.group(1);
    final terminal = RegExp(r'\bTERMINAL\b\s*[:\-]?\s*([A-Z0-9]{1,2})\b')
        .firstMatch(upper)
        ?.group(1);

    final origin = route.origin;
    final destination = route.destination;
    final originRef = origin != null ? validator.resolveAirport(origin) : null;

    final confidence = ConfidenceEngine.calculate(
      hasValidFlightNumber: flightNumber != null,
      isOriginValidIata: origin != null,
      isDestValidIata: destination != null,
      hasValidDate: date != null,
      hasTime: date != null && departureTime != null,
      ocrProximityScore: route.proximityBonus,
    );

    return ParsedFlight(
      flightNumber: flightNumber ?? '',
      originIata: origin ?? '',
      destinationIata: destination ?? '',
      departureDateTime: at(departureTime) ??
          (date == null ? null : DateTime(date.year, date.month, date.day)),
      boardingDateTime: at(boardingTime),
      departureTimezone: originRef?.timezone ?? 'UTC',
      terminal: terminal,
      seat: seat,
      gate: gate,
      source: BoardingPassSource.ocr,
      confidence: confidence,
    );
  }

  bool _isAirport(String? code) =>
      code != null && !_stopwords.contains(code) && validator.isValidIata(code);

  ({String? origin, String? destination, double proximityBonus}) _extractRoute(
    String upper,
  ) {
    String? origin;
    String? destination;
    double bonus = 0;

    // 1. Labels: "FROM MNL", "FROM MANILA (MNL)", "DESTINATION:\nCEB".
    final from = _codeAfterLabel(
      upper,
      r'\b(?:FROM|ORIGIN|DEPART(?:ING|URE|S)?)\b',
    );
    if (from != null) {
      origin = from;
      bonus += 0.2;
    }
    final to = _codeAfterLabel(
      upper,
      r'\b(?:TO|DEST(?:INATION)?|ARRIV(?:ING|AL|ES)?)\b',
      exclude: origin,
    );
    if (to != null) {
      destination = to;
      bonus += 0.2;
    }

    // 2. Layout: "MNL → CEB", "MNL - CEB", "MNL TO CEB", "MNL > CEB".
    if (origin == null || destination == null) {
      final pairs = RegExp(
        r'\b([A-Z]{3})\s*(?:-|–|—|→|>|✈|\bTO\b)\s*([A-Z]{3})\b',
      ).allMatches(upper);
      for (final m in pairs) {
        final a = m.group(1);
        final b = m.group(2);
        if (_isAirport(a) && _isAirport(b) && a != b) {
          origin ??= a;
          destination ??= b;
          bonus += 0.15;
          break;
        }
      }
    }

    // 3. Last resort: first valid codes in reading order.
    if (origin == null || destination == null) {
      final candidates = <String>[];
      for (final m in RegExp(r'\b[A-Z]{3}\b').allMatches(upper)) {
        final token = m.group(0)!;
        if (_isAirport(token) &&
            token != origin &&
            token != destination &&
            !candidates.contains(token)) {
          candidates.add(token);
        }
      }
      if (origin == null && candidates.isNotEmpty) {
        origin = candidates.removeAt(0);
      }
      if (destination == null && candidates.isNotEmpty) {
        destination = candidates.first;
      }
    }

    return (origin: origin, destination: destination, proximityBonus: bonus);
  }

  String? _extractFlightNumber(String upper) {
    // 1. Labelled: "FLIGHT PR 1847", "FLT: 5J560", "FLIGHT NO. SQ 32".
    final labelled = RegExp(
      r'\b(?:FLIGHT|FLT)\b\s*(?:NO\.?|NUMBER|#)?\s*[:\-]?\s*'
      '$_flightCode'
      r'\b',
    ).firstMatch(upper);
    if (labelled != null) {
      return FlightNormalizer.normalizeFlightNumber(
        '${labelled.group(1)}${labelled.group(2)}',
      );
    }

    // 2. Unlabelled: first designator+number that isn't the value of another
    //    label (GATE A12, SEAT 12A, TERMINAL 3, ...).
    final otherLabel = RegExp(
      r'\b(?:GATE|SEAT|TERMINAL|ZONE|GROUP|SEQ|ROW|NO\.?)\s*[:\-]?$',
    );
    for (final m in RegExp(r'\b' '$_flightCode' r'\b').allMatches(upper)) {
      if (otherLabel.hasMatch(upper.substring(0, m.start).trimRight())) {
        continue;
      }
      return FlightNormalizer.normalizeFlightNumber(
        '${m.group(1)}${m.group(2)}',
      );
    }
    return null;
  }

  /// ISO ("2026-09-29") and day-month dates ("29 SEP", "29SEP26",
  /// "29 SEP 2026", "SEP 29, 2026"). A date right after a DATE label wins;
  /// otherwise the first one in reading order. A missing year resolves to the
  /// nearest upcoming occurrence.
  DateTime? _extractDate(String upper, DateTime now) {
    final months = _months.keys.join('|');
    final patterns = <(RegExp, DateTime? Function(Match))>[
      (
        RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b'),
        (m) => _date(
              int.parse(m.group(1)!),
              int.parse(m.group(2)!),
              int.parse(m.group(3)!),
            ),
      ),
      (
        RegExp(r'\b(\d{1,2})\s?(' '$months' r')[A-Z]*\.?,?\s?(\d{4}|\d{2})?\b'),
        (m) => _dayMonth(m.group(1)!, m.group(2)!, m.group(3), now),
      ),
      (
        RegExp(r'\b(' '$months' r')[A-Z]*\.?\s(\d{1,2})(?:,?\s(\d{4}))?\b'),
        (m) => _dayMonth(m.group(2)!, m.group(1)!, m.group(3), now),
      ),
    ];

    final label = RegExp(r'\bDATE\b').firstMatch(upper);
    DateTime? first;
    var firstAt = upper.length;
    for (final (pattern, toDate) in patterns) {
      for (final m in pattern.allMatches(upper)) {
        final value = toDate(m);
        if (value == null) continue;
        if (label != null &&
            m.start >= label.end &&
            m.start - label.end <= 12) {
          return value;
        }
        if (m.start < firstAt) {
          first = value;
          firstAt = m.start;
        }
      }
    }
    return first;
  }

  DateTime? _dayMonth(String day, String month, String? year, DateTime now) {
    final d = int.tryParse(day);
    final m = _months[month];
    if (d == null || m == null) return null;
    if (year != null) {
      final y = int.parse(year);
      return _date(y < 100 ? 2000 + y : y, m, d);
    }
    // No year: tickets are added before flying, so take the next occurrence,
    // allowing a month of grace for a flight that just happened.
    final thisYear = _date(now.year, m, d);
    if (thisYear == null) return null;
    return thisYear.isBefore(now.subtract(const Duration(days: 30)))
        ? _date(now.year + 1, m, d)
        : thisYear;
  }

  DateTime? _date(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    return date.month == m ? date : null; // rejects 31 SEP etc.
  }

  /// First valid airport code in the few words after a label — tolerates a
  /// city name in between ("FROM MANILA (MNL)") or the value on the next line.
  String? _codeAfterLabel(String upper, String label, {String? exclude}) {
    for (final m in RegExp(label).allMatches(upper)) {
      final window = upper.substring(m.end, math.min(upper.length, m.end + 30));
      for (final t in RegExp(r'\b[A-Z]{3}\b').allMatches(window)) {
        final code = t.group(0);
        if (code != exclude && _isAirport(code)) return code;
      }
    }
    return null;
  }

  /// Time after a label: "DEPARTURE 06:35", "BOARDING TIME\n0605",
  /// "DEPARTURE 15 OCT 2026 06:35 AM", "ETD 6.35PM".
  ///
  /// A time later on the label's line needs a separator (06:35, 6.35, 6H35)
  /// so a year like 2026 is never read as 20:26; a bare HHMM is accepted only
  /// directly after the label. Dotted dates (15.10.2026) are not times.
  ({int hour, int minute})? _extractTime(String upper, String labelPattern) {
    const meridiem = r'\s*(AM|PM)?\b';
    final separated = RegExp(
      r'\b'
      '$labelPattern'
      r'\b[^\n]{0,30}?(?:\n[^\n]{0,15}?)?'
      r'(?<![\d./])([01]?\d|2[0-3])[:.H]([0-5]\d)(?![.\/]\d)'
      '$meridiem',
    );
    final bare = RegExp(
      r'\b'
      '$labelPattern'
      r'\b[^0-9]{0,12}?\b([01]\d|2[0-3])([0-5]\d)\b'
      '$meridiem',
    );
    final m = separated.firstMatch(upper) ?? bare.firstMatch(upper);
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final suffix = m.group(3);
    if (suffix == 'PM' && hour < 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return (hour: hour, minute: minute);
  }
}
