import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/airport/data/models/airport_model.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/domain/repositories/airport_repository.dart';
import 'package:geolocator/geolocator.dart';

class AirportRepositoryImpl implements AirportRepository {
  const AirportRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, AirportEntity?>> checkInsideAirport(
    LocationCoordinates coordinates,
  ) async {
    try {
      final quantized = coordinates.quantize();

      final response = await _api.get(
        ApiEndpoints.airportCheckInside,
        query: {
          'lat': quantized.latitude,
          'lng': quantized.longitude,
        },
      );

      if (response == null) {
        return const Right(null);
      }

      final model =
          AirportModel.fromJson((response as Map).cast<String, dynamic>());
      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AirportEntity>>> searchAirports(
    String query,
  ) async {
    try {
      final response = await _api.get(
        ApiEndpoints.airportSearch,
        query: {'q': query},
      );

      final rawData = (response as Map)['data'];
      if (rawData is! List) return const Right([]);

      final list = rawData
          .whereType<Map<String, dynamic>>()
          .map(AirportModel.fromJson)
          .toList();

      return Right(list);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AirportEntity>>> findNearby(
    LocationCoordinates coordinates, {
    double radiusKm = 50,
  }) async {
    try {
      final quantized = coordinates.quantize();

      final response = await _api.get(
        ApiEndpoints.airportNearby,
        query: {
          'lat': quantized.latitude,
          'lng': quantized.longitude,
          'radius': radiusKm,
        },
      );

      final rawData = (response as Map)['data'];
      if (rawData is! List) return const Right([]);

      final list = rawData
          .whereType<Map<String, dynamic>>()
          .map(AirportModel.fromJson)
          .map((airport) {
        if (airport.latitude == null || airport.longitude == null) {
          return airport;
        }
        final meters = Geolocator.distanceBetween(
          coordinates.latitude,
          coordinates.longitude,
          airport.latitude!,
          airport.longitude!,
        );
        return airport.copyWith(distanceKm: meters / 1000);
      }).toList()
        ..sort(
          (a, b) => (a.distanceKm ?? double.infinity)
              .compareTo(b.distanceKm ?? double.infinity),
        );

      return Right(list);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getAirportGeoJson() async {
    try {
      final response = await _api.get(ApiEndpoints.airportGeoJson);
      final rawData = (response as Map)['data'];
      if (rawData is Map<String, dynamic>) {
        return Right(rawData);
      } else if (rawData is Map) {
        return Right(rawData.cast<String, dynamic>());
      }
      return const Right(<String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      });
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
