import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';

class FlightTicketModel extends FlightTicketEntity {
  const FlightTicketModel({
    required super.id,
    required super.userId,
    required super.flightNumber,
    required super.fromAirport,
    required super.toAirport,
    required super.departureDateTime,
    super.returnDateTime,
    super.arrivalDateTime,
    super.boardingDateTime,
    super.fromAirportName,
    super.toAirportName,
    super.terminal,
    super.gate,
    super.seat,
  });

  factory FlightTicketModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
            ? (json['data'] as Map).cast<String, dynamic>()
            : json;

    final id = (payload['_id'] ?? payload['id'] ?? '').toString();
    final userId = (payload['userId'] ?? '').toString();
    final flightNumber = (payload['flightNumber'] ?? '').toString();
    final fromAirport = (payload['fromAirport'] ?? '').toString();
    final toAirport = (payload['toAirport'] ?? '').toString();

    final departureStr = (payload['departureDateTime'] ?? '').toString();
    final departureDateTime = DateTime.tryParse(departureStr) ?? DateTime.now();

    final returnStr = (payload['returnDateTime'] ?? '').toString();
    final returnDateTime = DateTime.tryParse(returnStr);

    DateTime? arrivalDateTime;
    if (payload['arrivalDateTime'] != null) {
      arrivalDateTime =
          DateTime.tryParse(payload['arrivalDateTime'].toString());
    }

    DateTime? boardingDateTime;
    if (payload['boardingDateTime'] != null) {
      boardingDateTime =
          DateTime.tryParse(payload['boardingDateTime'].toString());
    }

    return FlightTicketModel(
      id: id,
      userId: userId,
      flightNumber: flightNumber,
      fromAirport: fromAirport,
      toAirport: toAirport,
      departureDateTime: departureDateTime,
      returnDateTime: returnDateTime,
      arrivalDateTime: arrivalDateTime,
      boardingDateTime: boardingDateTime,
      fromAirportName: payload['fromAirportName'] as String?,
      toAirportName: payload['toAirportName'] as String?,
      terminal: payload['terminal'] as String?,
      gate: payload['gate'] as String?,
      seat: payload['seat'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'flightNumber': flightNumber,
        'fromAirport': fromAirport,
        'toAirport': toAirport,
        'departureDateTime': departureDateTime.toIso8601String(),
        'returnDateTime': returnDateTime?.toIso8601String(),
        'arrivalDateTime': arrivalDateTime?.toIso8601String(),
        'boardingDateTime': boardingDateTime?.toIso8601String(),
        'fromAirportName': fromAirportName,
        'toAirportName': toAirportName,
        'terminal': terminal,
        'gate': gate,
        'seat': seat,
      };
}
