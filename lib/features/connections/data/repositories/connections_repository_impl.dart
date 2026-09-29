import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/connections/data/models/connection_model.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:gate_closes/features/connections/domain/repositories/connections_repository.dart';
import 'package:uuid/uuid.dart';

class ConnectionsRepositoryImpl implements ConnectionsRepository {
  const ConnectionsRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, List<ConnectionEntity>>> getConnections({
    ConnectionType? type,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (type != null) {
        query['type'] = type.toApiKey();
      }

      final response = await _api.get(
        ApiEndpoints.conversations,
        query: query.isEmpty ? null : query,
      );

      final rawData = (response as Map)['data'];
      if (rawData is! List) return const Right([]);

      final list = rawData
          .whereType<Map<String, dynamic>>()
          .map(ConnectionModel.fromJson)
          .toList();

      return Right(list);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConnectionEntity>> createConnection({
    required ConnectionType type,
    required String otherUserId,
  }) async {
    try {
      final payload = {
        'type': type.toApiKey(),
        'otherUserId': otherUserId,
      };

      final response = await _api.postWith(
        ApiEndpoints.conversations,
        body: payload,
        idempotencyKey: const Uuid().v4(),
      );
      final rawData = (response as Map)['data'];
      final model =
          ConnectionModel.fromJson((rawData as Map).cast<String, dynamic>());

      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ConnectionEntity>>> searchConnections({
    required String query,
    ConnectionType? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{'q': query};
      if (type != null) {
        queryParams['type'] = type.toApiKey();
      }

      final response = await _api.get(
        ApiEndpoints.conversationSearch,
        query: queryParams,
      );

      final rawData = (response as Map)['data'];
      if (rawData is! List) return const Right([]);

      final list = rawData
          .whereType<Map<String, dynamic>>()
          .map(ConnectionModel.fromJson)
          .toList();

      return Right(list);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
