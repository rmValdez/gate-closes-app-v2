import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/connections/data/datasources/conversation_socket_service.dart';
import 'package:gate_closes/features/connections/data/repositories/connections_repository_impl.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:gate_closes/features/connections/domain/repositories/connections_repository.dart';

// --- Dependency wiring ---

final connectionsRepositoryProvider = Provider<ConnectionsRepository>((ref) {
  return ConnectionsRepositoryImpl(ref.watch(apiServiceProvider));
});

// --- State ---

class ConnectionsState extends Equatable {
  const ConnectionsState({
    this.isLoading = false,
    this.connections = const [],
    this.error,
  });

  final bool isLoading;

  /// All of the user's connections, unfiltered — tabs filter client-side by
  /// [ConnectionType] so switching tabs doesn't re-fetch.
  final List<ConnectionEntity> connections;
  final String? error;

  List<ConnectionEntity> byType(ConnectionType type) =>
      connections.where((c) => c.type == type).toList();

  ConnectionsState copyWith({
    bool? isLoading,
    List<ConnectionEntity>? connections,
    String? error,
  }) {
    return ConnectionsState(
      isLoading: isLoading ?? this.isLoading,
      connections: connections ?? this.connections,
      // Intentionally not `error ?? this.error`: passing null clears it.
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, connections, error];
}

// --- Controller ---

class ConnectionsController extends Notifier<ConnectionsState> {
  ConversationSocketService? _socketService;

  @override
  ConnectionsState build() {
    // Rebuild (dropping state and the socket) whenever the signed-in user
    // changes, so one account's data never survives into the next session.
    final userId = ref.watch(
      authControllerProvider.select((s) => s.user?.id),
    );
    ref.onDispose(() {
      _socketService?.disconnect();
      _socketService = null;
    });
    if (userId == null) return const ConnectionsState();

    unawaited(Future.microtask(fetchConnections));
    unawaited(_initSocket());
    return const ConnectionsState(isLoading: true);
  }

  Future<void> _initSocket() async {
    final storage = ref.read(storageServiceProvider);
    final token = await storage.readToken();
    if (token == null || token.isEmpty || !ref.mounted) return;

    _socketService = ConversationSocketService(
      readToken: storage.readToken,
      revalidateSession: () =>
          ref.read(authControllerProvider.notifier).refreshAuth(),
    )..connect(
        onConversationUpdated: (_) {
          unawaited(fetchConnections());
        },
      );
  }

  Future<void> fetchConnections() async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(connectionsRepositoryProvider);
    final result = await repo.getConnections();

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (connections) => state = ConnectionsState(connections: connections),
    );
  }
}

final connectionsControllerProvider =
    NotifierProvider<ConnectionsController, ConnectionsState>(
  ConnectionsController.new,
);
