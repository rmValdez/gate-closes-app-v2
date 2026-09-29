import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/services/adapter_config/adapter_config.dart';
import 'package:gate_closes/core/services/cookie_service.dart';
import 'package:gate_closes/core/services/storage_service.dart';

/// Attaches the access token to outgoing requests and transparently refreshes
/// it once when the server returns 401, then retries the original request.
///
/// If refresh fails (or there is no refresh token), the local session is
/// cleared so the router falls back to the login flow. Extends
/// [QueuedInterceptor] so concurrent 401s don't trigger parallel refreshes.
///
/// The refresh call uses a separate, bare [Dio] so it does not recurse through
/// this interceptor.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(
    this._storage, {
    required String baseUrl,
    this.cookieService,
    this.onUnauthenticated,
    Dio? refreshClient,
  }) : _refreshClient = refreshClient ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                contentType: Headers.jsonContentType,
                // Without these a hung refresh stalls every queued request.
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 10),
              ),
            ) {
    configureWebCredentials(_refreshClient);
    final jar = cookieService?.jar;
    if (jar != null && !kIsWeb) {
      _refreshClient.interceptors.add(CookieManager(jar));
    }
  }

  final StorageService _storage;
  final CookieService? cookieService;
  final Dio _refreshClient;
  final void Function()? onUnauthenticated;

  /// Marks a request that has already been retried after a refresh, to avoid
  /// infinite 401 loops.
  static const String _retriedFlag = 'auth_retried';

  /// Endpoints that must NOT carry a bearer token or trigger a refresh.
  static const Set<String> _authPaths = {
    ApiEndpoints.login,
    ApiEndpoints.refresh,
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_authPaths.contains(options.path)) {
      final token = await _storage.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = options.extra[_retriedFlag] == true;
    final isAuthCall = _authPaths.contains(options.path);

    if (!isUnauthorized || alreadyRetried || isAuthCall) {
      handler.next(err);
      return;
    }

    // Concurrent 401s queue up behind the first one's refresh. If the stored
    // token already differs from the one this request was sent with, that
    // refresh happened — replay with it instead of rotating again.
    final sentWith = (options.headers['Authorization'] as String?)
        ?.replaceFirst('Bearer ', '');
    final current = await _storage.readToken();
    final alreadyRefreshed =
        current != null && current.isNotEmpty && current != sentWith;
    final newToken = alreadyRefreshed ? current : await _refreshToken();
    if (newToken == null) {
      await _storage.clearSession();
      await cookieService?.clearCookies();
      onUnauthenticated?.call();
      handler.next(err);
      return;
    }

    // Replay the original request with the fresh token.
    options
      ..extra[_retriedFlag] = true
      ..headers['Authorization'] = 'Bearer $newToken';
    try {
      final response = await _refreshClient.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Exchanges the stored refresh token for a new access token. Returns the new
  /// access token, or null if refresh isn't possible.
  Future<String?> _refreshToken() async {
    final refreshToken = await _storage.readRefreshToken();

    try {
      final res = await _refreshClient.post<dynamic>(
        ApiEndpoints.refresh,
        data: (refreshToken != null && refreshToken.isNotEmpty)
            ? {'refreshToken': refreshToken}
            : null,
      );
      final rawData = res.data;
      if (rawData is! Map) return null;

      final payload = (rawData['data'] is Map)
          ? (rawData['data'] as Map).cast<String, dynamic>()
          : rawData.cast<String, dynamic>();

      final token = (payload['token'] ?? payload['accessToken']) as String?;
      final newRefresh = payload['refreshToken'] as String?;
      if (token == null || token.isEmpty) return null;

      await _storage.saveToken(token);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _storage.saveRefreshToken(newRefresh);
      }
      return token;
    } on DioException {
      return null;
    }
  }
}
