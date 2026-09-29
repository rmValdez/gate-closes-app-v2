import 'package:gate_closes/core/services/authenticated_socket.dart';
import 'package:gate_closes/core/utils/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Manages realtime Socket.IO connections for the `/conversations` namespace.
///
/// Event names are verified against `gate-closes-api/src/events/conversation.
/// events.ts` and `conversation.controller.ts` — note `join_conversation`/
/// `leave_conversation` (bare), unlike Terminal Echo's prefixed
/// `terminal_echo:join_airport`. The two namespaces are not symmetric; do not
/// copy one pattern onto the other without checking.
class ConversationSocketService {
  ConversationSocketService({
    required this.readToken,
    this.revalidateSession,
  });

  /// Read on every (re)connect handshake so a token rotated by the HTTP
  /// refresh flow is picked up instead of a stale copy captured at creation.
  final Future<String?> Function() readToken;

  /// Called before reconnecting after the server rejects the handshake.
  final Future<void> Function()? revalidateSession;

  AuthenticatedSocket? _connection;
  String? _currentConversationId;

  bool get isConnected => _connection?.socket.connected ?? false;

  /// Connects to the `/conversations` namespace. If [conversationId] is
  /// provided, joins that conversation's room. Otherwise connects to the
  /// namespace to receive user-level events (e.g. `conversation:updated`).
  void connect({
    String? conversationId,
    void Function(Map<String, dynamic> message)? onMessageReceived,
    void Function(Map<String, dynamic> reaction)? onReactionUpdated,
    void Function(Map<String, dynamic> update)? onConversationUpdated,
  }) {
    disconnect();
    _currentConversationId = conversationId;

    final connection = _connection = AuthenticatedSocket(
      namespace: '/conversations',
      // The /conversations middleware reads `auth.token`.
      authKey: 'token',
      readToken: readToken,
      revalidateSession: revalidateSession,
    );
    final socket = connection.socket;

    // Runs on every (re)connect, so the room is rejoined after recovery.
    socket.onConnect((_) {
      if (conversationId != null) {
        appLogger.i(
          'Socket connected to /conversations. Joining $conversationId',
        );
        socket.emit('join_conversation', {'conversationId': conversationId});
      } else {
        appLogger.i(
          'Socket connected to /conversations (listening for user updates)',
        );
      }
    });

    if (onConversationUpdated != null) {
      socket.on('conversation:updated', (data) {
        if (data is Map) {
          onConversationUpdated(data.cast<String, dynamic>());
        }
      });
    }

    if (onMessageReceived != null) {
      socket.on('message:received', (data) {
        if (data is Map) {
          onMessageReceived(data.cast<String, dynamic>());
        }
      });
    }

    if (onReactionUpdated != null) {
      socket.on('reaction:updated', (data) {
        if (data is Map) {
          onReactionUpdated(data.cast<String, dynamic>());
        }
      });
    }

    socket.onDisconnect((_) {
      appLogger.w('Socket disconnected from /conversations');
    });
  }

  void disconnect() {
    final connection = _connection;
    if (connection == null) return;
    if (_currentConversationId != null) {
      connection.socket.emit('leave_conversation', {
        'conversationId': _currentConversationId,
      });
    }
    connection.close();
    _connection = null;
    _currentConversationId = null;
  }
}
