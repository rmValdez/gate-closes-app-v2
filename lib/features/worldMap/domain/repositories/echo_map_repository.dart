import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';

/// Echo pins for the world map. Owned by `worldMap` (not `terminal_echo`) so
/// the map reads the `/terminal-echo/map` endpoint without importing another
/// feature.
abstract class EchoMapRepository {
  /// Pins inside the bounding box, or all pins when no box is given.
  Future<Either<Failure, List<TerminalEchoMapNodeEntity>>> getNodes({
    double? west,
    double? south,
    double? east,
    double? north,
  });
}
