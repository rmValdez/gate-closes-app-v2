/// Low-level exceptions thrown by the data layer (ApiService and data sources).
///
/// Repositories catch these and translate them into typed `Failure` values, so
/// exceptions never escape the data layer into controllers or the UI.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// No connectivity, DNS failure, or timeout.
class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection']);
}

/// The request was rejected because the session is missing or invalid (401).
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized access']);
}

/// Any other non-success response (4xx/5xx) or an unexpected server error.
class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode});

  final int? statusCode;
}
