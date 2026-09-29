import 'package:gate_closes/core/airports/airport_reference.dart';

/// Normalizer for flight codes, carrier codes, and dates.
class FlightNormalizer {
  const FlightNormalizer._();

  /// Standardizes flight numbers: trims whitespace, removes hyphens, uppercase.
  /// E.g. "pr-1847" -> "PR1847", "UA 0892" -> "UA892".
  static String normalizeFlightNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-_]'), '').toUpperCase();
    final match = RegExp(r'^([A-Z]{2,3}|\d[A-Z]|[A-Z]\d)(0*)([1-9]\d*)$')
        .firstMatch(cleaned);
    if (match != null) {
      final carrier = match.group(1)!;
      final number = match.group(3)!;
      return '$carrier$number';
    }
    return cleaned;
  }

  /// Calculates a calendar year for a Julian Day of Year (1-366) using a
  /// sliding window of +/- 180 days relative to today.
  /// Prevents New Year boundary mismatches (e.g. ticket scanned Dec 30 for
  /// Jan 2).
  static int resolveJulianYear(int julianDay, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final todayJulian = now.difference(DateTime(now.year)).inDays + 1;
    final delta = julianDay - todayJulian;

    if (delta < -180) {
      // Julian day is much earlier in the year than today -> it's for next year
      return now.year + 1;
    } else if (delta > 180) {
      // Julian day is much later in the year -> ticket from previous year
      return now.year - 1;
    }
    return now.year;
  }

  /// Converts a Julian Day of Year to a concrete DateTime.
  static DateTime julianToDateTime(int julianDay, [DateTime? referenceDate]) {
    final year = resolveJulianYear(julianDay, referenceDate);
    return DateTime.utc(year).add(Duration(days: julianDay - 1));
  }

  /// Combines a date with HH:mm time string and optionally adjusts for
  /// airport timezone.
  static DateTime combineDateAndTime(
    DateTime date,
    String timeHHmm, {
    AirportReference? airport,
  }) {
    final cleanTime = timeHHmm.replaceAll(RegExp('[^0-9]'), '');
    var hour = 0;
    var minute = 0;
    if (cleanTime.length >= 4) {
      hour = int.tryParse(cleanTime.substring(0, 2)) ?? 0;
      minute = int.tryParse(cleanTime.substring(2, 4)) ?? 0;
    }

    return DateTime.utc(date.year, date.month, date.day, hour, minute);
  }
}
