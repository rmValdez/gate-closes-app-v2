import 'package:equatable/equatable.dart';

/// Granular confidence score (0.0 to 1.0) per field extracted from a boarding
/// pass.
class ParseConfidence extends Equatable {
  const ParseConfidence({
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.departureTime,
    required this.overall,
  });

  /// Creates a confidence where all fields are zero.
  factory ParseConfidence.zero() {
    return const ParseConfidence(
      flightNumber: 0,
      origin: 0,
      destination: 0,
      departureDate: 0,
      departureTime: 0,
      overall: 0,
    );
  }

  final double flightNumber;
  final double origin;
  final double destination;
  final double departureDate;
  final double departureTime;
  final double overall;

  /// Whether the overall confidence qualifies as high (1-tap confirmation).
  bool get isHigh => overall >= 0.85;

  /// Whether the confidence qualifies as medium (review suggested).
  bool get isMedium => overall >= 0.50 && overall < 0.85;

  /// Whether the confidence is low (manual review / correction needed).
  bool get isLow => overall < 0.50;

  @override
  List<Object?> get props => [
        flightNumber,
        origin,
        destination,
        departureDate,
        departureTime,
        overall,
      ];
}
