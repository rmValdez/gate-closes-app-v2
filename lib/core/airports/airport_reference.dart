import 'package:equatable/equatable.dart';

/// Lightweight reference representation of an airport for offline validation.
class AirportReference extends Equatable {
  const AirportReference({
    required this.iata,
    required this.name,
    required this.city,
    required this.countryCode,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    required this.airportType,
  });

  factory AirportReference.fromJson(Map<String, dynamic> json) {
    return AirportReference(
      iata: (json['iata'] as String? ?? '').toUpperCase(),
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'UTC',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      airportType: json['airportType'] as String? ?? 'medium',
    );
  }

  final String iata;
  final String name;
  final String city;
  final String countryCode;
  final String timezone;
  final double latitude;
  final double longitude;
  final String airportType;

  Map<String, dynamic> toJson() {
    return {
      'iata': iata,
      'name': name,
      'city': city,
      'countryCode': countryCode,
      'timezone': timezone,
      'latitude': latitude,
      'longitude': longitude,
      'airportType': airportType,
    };
  }

  @override
  List<Object?> get props => [
        iata,
        name,
        city,
        countryCode,
        timezone,
        latitude,
        longitude,
        airportType,
      ];
}
