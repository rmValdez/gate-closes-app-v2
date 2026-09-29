import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';

abstract class AirportRepository {
  /// Evaluates whether the given quantized coordinates are inside or
  /// approaching an airport.
  Future<Either<Failure, AirportEntity?>> checkInsideAirport(
    LocationCoordinates coordinates,
  );

  /// Searches airports by query string.
  Future<Either<Failure, List<AirportEntity>>> searchAirports(String query);

  /// Finds airports within [radiusKm] of the given coordinates, sorted
  /// nearest-first. `distanceKm` on each result is computed client-side —
  /// the backend's `/airport/nearby` response doesn't include it.
  Future<Either<Failure, List<AirportEntity>>> findNearby(
    LocationCoordinates coordinates, {
    double radiusKm = 50,
  });

  /// Fetches the airport boundaries GeoJSON FeatureCollection (`GET /airport/geojson`).
  Future<Either<Failure, Map<String, dynamic>>> getAirportGeoJson();
}
