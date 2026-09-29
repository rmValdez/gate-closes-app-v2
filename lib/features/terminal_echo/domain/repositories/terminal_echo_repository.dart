import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';

abstract class TerminalEchoRepository {
  /// Fetches the echoes for an airport feed (or all if airportIata is null).
  Future<Either<Failure, List<TerminalEchoEntity>>> getEchoes({
    String? airportIata,
  });

  /// Publishes a new Terminal Echo. A voice memo is mandatory on the real
  /// API (`TerminalEchoCtrl.create`'s Joi schema requires `fileUrl`/
  /// `fileName`) — `textMessage` is only ever an optional caption alongside
  /// it, never a text-only alternative.
  Future<Either<Failure, TerminalEchoEntity>> createEcho({
    required String textMessage,
    required String airportName,
    required LocationCoordinates coordinates,
    required String fileUrl,
    required String fileName,
    double audioDuration = 0,
    List<double> waveformData = const [],
  });

  /// Updates user reaction on a specific echo.
  Future<Either<Failure, void>> updateReaction({
    required String echoId,
    required EchoReactionType reaction,
  });

  /// Increments listen count when an audio echo is played.
  Future<Either<Failure, void>> incrementListen(String echoId);

  /// Fetches a single Terminal Echo by its id (`GET /terminal-echo/:id`).
  Future<Either<Failure, TerminalEchoEntity>> getEchoById(String id);
}
