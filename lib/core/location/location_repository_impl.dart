import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository.dart';
import 'package:geolocator/geolocator.dart';

class LocationRepositoryImpl implements LocationRepository {
  const LocationRepositoryImpl();

  @override
  Future<Either<Failure, bool>> requestPermission() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return const Left(
          PermissionFailure('Location services are disabled on device.'),
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const Left(PermissionFailure('Location permission denied.'));
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const Left(
          PermissionFailure(
            'Location permission permanently denied. Enable it in settings.',
          ),
        );
      }

      return const Right(true);
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LocationCoordinates>> getCurrentLocation() async {
    try {
      final permissionResult = await requestPermission();
      if (permissionResult.isLeft()) {
        return Left(
          permissionResult.getLeft().getOrElse(
                () => const PermissionFailure('Location permission required.'),
              ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      return Right(
        LocationCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on Object catch (e) {
      return Left(ServerFailure('Unable to get current location: $e'));
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return const LocationRepositoryImpl();
});
