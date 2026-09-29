import 'package:gate_closes/features/boarding_pass/domain/entities/parse_confidence.dart';

/// Multi-factor confidence calculation engine.
class ConfidenceEngine {
  const ConfidenceEngine._();

  /// Calculates granular and overall confidence scores based on field quality.
  static ParseConfidence calculate({
    required bool hasValidFlightNumber,
    required bool isOriginValidIata,
    required bool isDestValidIata,
    required bool hasValidDate,
    required bool hasTime,
    bool isBcbpDecoded = false,
    double ocrProximityScore = 0.0,
  }) {
    // Flight Number confidence
    final flightScore =
        hasValidFlightNumber ? (isBcbpDecoded ? 1.0 : 0.85) : 0.0;

    // Origin IATA confidence
    final originScore = isOriginValidIata
        ? (isBcbpDecoded
            ? 1.0
            : (0.8 + (ocrProximityScore.clamp(0.0, 1.0) * 0.2)))
        : 0.0;

    // Destination IATA confidence
    final destScore = isDestValidIata
        ? (isBcbpDecoded
            ? 1.0
            : (0.8 + (ocrProximityScore.clamp(0.0, 1.0) * 0.2)))
        : 0.0;

    // Departure Date confidence
    final dateScore = hasValidDate ? (isBcbpDecoded ? 1.0 : 0.85) : 0.0;

    // Departure Time confidence
    final timeScore = hasTime ? (isBcbpDecoded ? 0.95 : 0.75) : 0.0;

    // Overall weighted confidence (origin/dest/flight are weighted heaviest)
    final overall = isBcbpDecoded &&
            hasValidFlightNumber &&
            isOriginValidIata &&
            isDestValidIata &&
            hasValidDate
        ? 0.98
        : (hasValidFlightNumber &&
                isOriginValidIata &&
                isDestValidIata &&
                hasValidDate &&
                ocrProximityScore > 0.3)
            ? 0.88
            : (flightScore * 0.30 +
                originScore * 0.30 +
                destScore * 0.30 +
                dateScore * 0.05 +
                timeScore * 0.05);

    return ParseConfidence(
      flightNumber:
          double.parse(flightScore.clamp(0.0, 1.0).toStringAsFixed(2)),
      origin: double.parse(originScore.clamp(0.0, 1.0).toStringAsFixed(2)),
      destination: double.parse(destScore.clamp(0.0, 1.0).toStringAsFixed(2)),
      departureDate: double.parse(dateScore.clamp(0.0, 1.0).toStringAsFixed(2)),
      departureTime: double.parse(timeScore.clamp(0.0, 1.0).toStringAsFixed(2)),
      overall: double.parse(overall.clamp(0.0, 1.0).toStringAsFixed(2)),
    );
  }
}
