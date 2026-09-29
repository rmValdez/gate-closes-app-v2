import 'package:gate_closes/core/services/authenticated_socket.dart';
import 'package:gate_closes/core/utils/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Manages realtime Socket.IO connections for the `/terminal-echo` namespace.
///
/// Rooms: `airport:<IATA>` for the feed ([connectAirport]) and
/// `thread:<echoId>` for a reply thread ([connectThread]) — see
/// `gate-closes-api/src/events/terminal.echo.events.ts`.
class TerminalEchoSocketService {
  TerminalEchoSocketService({
    required this.readToken,
    this.revalidateSession,
  });

  /// Read on every (re)connect handshake so a token rotated by the HTTP
  /// refresh flow is picked up instead of a stale copy captured at creation.
  final Future<String?> Function() readToken;

  /// Called before reconnecting after the server rejects the handshake.
  final Future<void> Function()? revalidateSession;

  AuthenticatedSocket? _connection;
  void Function()? _leave;

  bool get isConnected => _connection?.socket.connected ?? false;

  /// Joins the `airport:<IATA>` room. Scoped server-side so feeds never leak
  /// across airports.
  void connectAirport({
    required String airportIata,
    void Function(Map<String, dynamic> echo)? onNewEcho,
    void Function(Map<String, dynamic> reaction)? onReactionUpdated,
  }) {
    final socket = _open(
      onConnect: (socket) => socket.emit(
        'terminal_echo:join_airport',
        {'airportIata': airportIata},
      ),
    );
    _leave = () => socket.emit(
          'terminal_echo:leave_airport',
          {'airportIata': airportIata},
        );

    if (onNewEcho != null) {
      socket.on('terminal_echo:changed', (data) {
        if (data is Map && data['type'] == 'create' && data['data'] is Map) {
          onNewEcho((data['data'] as Map).cast<String, dynamic>());
        }
      });
    }
    if (onReactionUpdated != null) {
      socket.on('terminal_echo:reaction_updated', (data) {
        if (data is Map) onReactionUpdated(data.cast<String, dynamic>());
      });
    }
  }

  /// Joins the `thread:<echoId>` room for live replies on one echo.
  void connectThread({
    required String echoId,
    void Function(Map<String, dynamic> data)? onReplyCreated,
    void Function(Map<String, dynamic> data)? onReplyReactionUpdated,
  }) {
    final room = {'room': 'thread:$echoId'};
    final socket = _open(
      onConnect: (socket) => socket.emit('terminal_echo:join_map', room),
    );
    _leave = () => socket.emit('terminal_echo:leave_map', room);

    if (onReplyCreated != null) {
      socket.on('terminal_echo_reply:created', (data) {
        if (data is Map) onReplyCreated(data.cast<String, dynamic>());
      });
    }
    if (onReplyReactionUpdated != null) {
      socket.on('terminal_echo_reply:reaction_updated', (data) {
        if (data is Map) onReplyReactionUpdated(data.cast<String, dynamic>());
      });
    }
  }

  io.Socket _open({required void Function(io.Socket socket) onConnect}) {
    disconnect();
    final connection = _connection = AuthenticatedSocket(
      namespace: '/terminal-echo',
      // The /terminal-echo middleware reads `auth.accessToken`.
      authKey: 'accessToken',
      readToken: readToken,
      revalidateSession: revalidateSession,
    );
    final socket = connection.socket;
    // Runs on every (re)connect, so the room is rejoined after recovery.
    socket
      ..onConnect((_) => onConnect(socket))
      ..onDisconnect((_) {
        appLogger.w('Socket disconnected from /terminal-echo');
      });
    return socket;
  }

  void disconnect() {
    final connection = _connection;
    if (connection == null) return;
    _leave?.call();
    connection.close();
    _connection = null;
    _leave = null;
  }
}
