import 'dart:async';
import 'dart:math' as math;

import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/utils/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// A Socket.IO connection to one API namespace that stays authenticated.
///
/// * The access token is read on every (re)connect handshake, so a token the
///   HTTP layer rotated is picked up instead of a stale copy.
/// * Transport drops are retried by socket.io itself. A handshake the server
///   *rejects* (auth middleware `next(new Error(...))`, typically an expired
///   token) is not — the client destroys the socket and stays down. Here that
///   case calls `revalidateSession` (which lets the HTTP interceptor refresh
///   the token, or signs the user out) and reconnects with backoff.
class AuthenticatedSocket {
  AuthenticatedSocket({
    required String namespace,
    required String authKey,
    required Future<String?> Function() readToken,
    Future<void> Function()? revalidateSession,
  }) : _revalidateSession = revalidateSession {
    final uri = Uri.parse(AppConfig.instance.baseUrl);
    socket = io.io(
      '${uri.scheme}://${uri.host}:${uri.port}$namespace',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableForceNew()
          .setAuthFn((send) {
            unawaited(readToken().then((token) => send({authKey: token})));
          })
          .build(),
    );

    socket
      ..onConnect((_) => _attempt = 0)
      ..onConnectError((err) {
        appLogger.w('Socket $namespace connect error: $err');
        _scheduleRecovery();
      });
  }

  late final io.Socket socket;
  final Future<void> Function()? _revalidateSession;

  Timer? _retryTimer;
  int _attempt = 0;
  bool _closed = false;

  static const Duration _maxBackoff = Duration(seconds: 30);

  void _scheduleRecovery() {
    // `active` is still true for transport errors, which socket.io retries on
    // its own. It is false only after a server-side rejection.
    if (_closed || socket.active || (_retryTimer?.isActive ?? false)) return;

    final seconds = math.min(_maxBackoff.inSeconds, 1 << _attempt);
    _attempt = math.min(_attempt + 1, 5);
    _retryTimer = Timer(Duration(seconds: seconds), () async {
      if (_closed) return;
      try {
        await _revalidateSession?.call();
      } on Object catch (e) {
        appLogger.w('Socket session revalidation failed: $e');
      }
      if (!_closed) socket.connect();
    });
  }

  /// Stops recovery and tears the connection down. The instance is unusable
  /// afterwards.
  void close() {
    _closed = true;
    _retryTimer?.cancel();
    socket
      ..disconnect()
      ..dispose();
  }
}
