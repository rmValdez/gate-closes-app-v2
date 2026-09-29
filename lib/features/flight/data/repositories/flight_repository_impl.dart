import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/flight/data/models/flight_ticket_model.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:gate_closes/features/flight/domain/repositories/flight_repository.dart';

class FlightRepositoryImpl implements FlightRepository {
  const FlightRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, FlightTicketEntity?>> getActiveFlightTicket() async {
    try {
      final response = await _api.get(ApiEndpoints.flightTicket);
      if (response == null) return const Right(null);

      final rawData = (response as Map)['data'];
      if (rawData == null || rawData is! Map) return const Right(null);

      final model =
          FlightTicketModel.fromJson(response.cast<String, dynamic>());
      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> createFlightTicket({
    required String flightNumber,
    required String fromAirport,
    required String toAirport,
    required DateTime departureDateTime,
    DateTime? returnDateTime,
    DateTime? arrivalDateTime,
    DateTime? boardingDateTime,
    String? terminal,
    String? gate,
    String? seat,
    String? idempotencyKey,
  }) async {
    try {
      final payload = <String, dynamic>{
        'flightNumber': flightNumber.trim(),
        'fromAirport': fromAirport.trim(),
        'toAirport': toAirport.trim(),
        'departureDateTime': departureDateTime.toIso8601String(),
      };
      if (returnDateTime != null) {
        payload['returnDateTime'] = returnDateTime.toIso8601String();
      }
      if (arrivalDateTime != null) {
        payload['arrivalDateTime'] = arrivalDateTime.toIso8601String();
      }
      if (boardingDateTime != null) {
        payload['boardingDateTime'] = boardingDateTime.toIso8601String();
      }
      if (terminal != null) payload['terminal'] = terminal;
      if (gate != null) payload['gate'] = gate;
      if (seat != null) payload['seat'] = seat;
      if (idempotencyKey != null) payload['idempotencyKey'] = idempotencyKey;

      final response = await _api.postWith(
        ApiEndpoints.flightTicket,
        body: payload,
        idempotencyKey: idempotencyKey,
      );
      final message =
          (response as Map)['message']?.toString() ?? 'Flight ticket created.';
      return Right(message);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> updateFlightTicket({
    String? flightNumber,
    String? fromAirport,
    String? toAirport,
    DateTime? departureDateTime,
    DateTime? returnDateTime,
    DateTime? arrivalDateTime,
    DateTime? boardingDateTime,
    String? terminal,
    String? gate,
    String? seat,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (flightNumber != null) payload['flightNumber'] = flightNumber.trim();
      if (fromAirport != null) payload['fromAirport'] = fromAirport.trim();
      if (toAirport != null) payload['toAirport'] = toAirport.trim();
      if (departureDateTime != null) {
        payload['departureDateTime'] = departureDateTime.toIso8601String();
      }
      if (returnDateTime != null) {
        payload['returnDateTime'] = returnDateTime.toIso8601String();
      }
      if (arrivalDateTime != null) {
        payload['arrivalDateTime'] = arrivalDateTime.toIso8601String();
      }
      if (boardingDateTime != null) {
        payload['boardingDateTime'] = boardingDateTime.toIso8601String();
      }
      if (terminal != null) payload['terminal'] = terminal;
      if (gate != null) payload['gate'] = gate;
      if (seat != null) payload['seat'] = seat;

      final response = await _api.put(ApiEndpoints.flightTicket, payload);
      final message =
          (response as Map)['message']?.toString() ?? 'Flight ticket updated.';
      return Right(message);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFlightTicket() async {
    try {
      await _api.delete(ApiEndpoints.flightTicket);
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
