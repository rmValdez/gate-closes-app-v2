import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/terminal_echo/data/models/terminal_echo_model.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_repository.dart';
import 'package:uuid/uuid.dart';

class TerminalEchoRepositoryImpl implements TerminalEchoRepository {
  const TerminalEchoRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, List<TerminalEchoEntity>>> getEchoes({
    String? airportIata,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (airportIata != null && airportIata.isNotEmpty) {
        query['airportName'] = airportIata;
      }

      final response = await _api.get(
        ApiEndpoints.terminalEcho,
        query: query.isEmpty ? null : query,
      );

      final rawData = (response as Map)['data'];
      if (rawData is! List) return const Right([]);

      final list = rawData
          .whereType<Map<String, dynamic>>()
          .map(TerminalEchoModel.fromJson)
          .toList();

      return Right(list);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TerminalEchoEntity>> createEcho({
    required String textMessage,
    required String airportName,
    required LocationCoordinates coordinates,
    required String fileUrl,
    required String fileName,
    double audioDuration = 0,
    List<double> waveformData = const [],
  }) async {
    try {
      final quantized = coordinates.quantize();

      final payload = <String, dynamic>{
        'textMessage': textMessage,
        'airportName': airportName,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'location': {
          'type': 'Point',
          'coordinates': [quantized.longitude, quantized.latitude],
        },
        'audioDuration': audioDuration,
        'waveformData': waveformData,
      };

      // Fresh key per post: lets the transport retry safely without the
      // server creating the same echo twice.
      final response = await _api.postWith(
        ApiEndpoints.terminalEcho,
        body: payload,
        idempotencyKey: const Uuid().v4(),
      );
      final rawData = (response as Map)['data'];
      final model =
          TerminalEchoModel.fromJson((rawData as Map).cast<String, dynamic>());
      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateReaction({
    required String echoId,
    required EchoReactionType reaction,
  }) async {
    try {
      await _api.patch(
        ApiEndpoints.terminalEchoReaction(echoId),
        {'reaction': reaction.name},
      );
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> incrementListen(String echoId) async {
    try {
      await _api.patch(ApiEndpoints.terminalEchoListen(echoId));
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TerminalEchoEntity>> getEchoById(String id) async {
    try {
      final response = await _api.get('${ApiEndpoints.terminalEcho}/$id');
      final rawData = (response as Map)['data'];
      final model = TerminalEchoModel.fromJson(
        (rawData is Map) ? rawData.cast<String, dynamic>() : {},
      );
      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
