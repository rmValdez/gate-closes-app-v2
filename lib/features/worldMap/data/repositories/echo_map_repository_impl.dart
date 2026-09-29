import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';

class EchoMapRepositoryImpl implements EchoMapRepository {
  const EchoMapRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, List<TerminalEchoMapNodeEntity>>> getNodes({
    double? west,
    double? south,
    double? east,
    double? north,
  }) async {
    try {
      final hasBounds =
          west != null && south != null && east != null && north != null;
      final response = await _api.get(
        ApiEndpoints.terminalEchoMap,
        query: hasBounds
            ? {'west': west, 'south': south, 'east': east, 'north': north}
            : null,
      );

      // `data` is a GeoJSON FeatureCollection.
      final data = response is Map ? response['data'] : null;
      final features = data is Map ? data['features'] : null;
      if (features is! List) return const Right([]);
      return Right(
        features
            .whereType<Map<dynamic, dynamic>>()
            .map((f) => f.cast<String, dynamic>())
            .map(TerminalEchoMapNodeEntity.fromGeoJsonFeature)
            .toList(),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
