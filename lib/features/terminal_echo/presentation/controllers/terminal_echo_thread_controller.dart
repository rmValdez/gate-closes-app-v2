import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/terminal_echo/data/datasources/terminal_echo_socket_service.dart';
import 'package:gate_closes/features/terminal_echo/data/models/terminal_echo_reply_model.dart';
import 'package:gate_closes/features/terminal_echo/data/repositories/terminal_echo_reply_repository_impl.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_reply_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_reply_repository.dart';

final terminalEchoReplyRepositoryProvider =
    Provider<TerminalEchoReplyRepository>((ref) {
  return TerminalEchoReplyRepositoryImpl(ref.watch(apiServiceProvider));
});

class TerminalEchoThreadState extends Equatable {
  const TerminalEchoThreadState({
    this.isLoading = false,
    this.isSending = false,
    this.replies = const [],
    this.echoId,
    this.error,
  });

  final bool isLoading;
  final bool isSending;
  final List<TerminalEchoReplyEntity> replies;
  final String? echoId;
  final String? error;

  TerminalEchoThreadState copyWith({
    bool? isLoading,
    bool? isSending,
    List<TerminalEchoReplyEntity>? replies,
    String? echoId,
    String? error,
  }) {
    return TerminalEchoThreadState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      replies: replies ?? this.replies,
      echoId: echoId ?? this.echoId,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, isSending, replies, echoId, error];
}

class TerminalEchoThreadController extends Notifier<TerminalEchoThreadState> {
  TerminalEchoSocketService? _socketService;
  String? _echoId;

  @override
  TerminalEchoThreadState build() {
    // Reset (and drop the socket) whenever the signed-in user changes.
    ref
      ..watch(authControllerProvider.select((s) => s.user?.id))
      ..onDispose(() {
        _disconnectSocket();
        _echoId = null;
      });
    return const TerminalEchoThreadState();
  }

  Future<void> openThread(String echoId) async {
    _echoId = echoId;
    state = state.copyWith(isLoading: true, echoId: echoId);
    final repo = ref.read(terminalEchoReplyRepositoryProvider);
    final result = await repo.getReplies(echoId);
    // The user may have opened another thread while this one was loading.
    if (!ref.mounted || _echoId != echoId) return;

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (replies) {
        state = state.copyWith(
          isLoading: false,
          replies: replies,
        );
        _initSocket(echoId);
      },
    );
  }

  void _initSocket(String echoId) {
    _disconnectSocket();
    _socketService = TerminalEchoSocketService(
      readToken: ref.read(storageServiceProvider).readToken,
      revalidateSession: () =>
          ref.read(authControllerProvider.notifier).refreshAuth(),
    )..connectThread(
        echoId: echoId,
        onReplyCreated: (data) {
          if (data['reply'] is! Map) return;
          final newReply = TerminalEchoReplyModel.fromJson(
            (data['reply'] as Map).cast<String, dynamic>(),
          );
          if (!state.replies.any((r) => r.id == newReply.id)) {
            state = state.copyWith(replies: [newReply, ...state.replies]);
          }
        },
        onReplyReactionUpdated: (data) {
          final replyId = data['replyId']?.toString();
          final reactionKey = data['reactionKey']?.toString();
          final action = data['action']?.toString();
          if (replyId == null || reactionKey == null || action == null) return;

          state = state.copyWith(
            replies: [
              for (final reply in state.replies)
                reply.id == replyId
                    ? reply.withReactionDelta(reactionKey, action)
                    : reply,
            ],
          );
        },
      );
  }

  void _disconnectSocket() {
    _socketService?.disconnect();
    _socketService = null;
  }

  Future<bool> sendReply({
    String? fileUrl,
    String? fileName,
    String? textMessage,
    double audioDuration = 0,
    List<double> waveformData = const [],
  }) async {
    final echoId = _echoId;
    if (echoId == null) return false;

    state = state.copyWith(isSending: true);
    final repo = ref.read(terminalEchoReplyRepositoryProvider);

    final result = await repo.createReply(
      terminalEchoId: echoId,
      fileUrl: fileUrl,
      fileName: fileName,
      textMessage: textMessage,
      audioDuration: audioDuration,
      waveformData: waveformData,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSending: false, error: failure.message);
        return false;
      },
      (reply) {
        if (!state.replies.any((r) => r.id == reply.id)) {
          state = state.copyWith(
            isSending: false,
            replies: [reply, ...state.replies],
          );
        } else {
          state = state.copyWith(isSending: false);
        }
        return true;
      },
    );
  }

  Future<void> react({
    required String replyId,
    required EchoReactionType reaction,
  }) async {
    final target = state.replies.firstWhere((r) => r.id == replyId);
    final isCurrentlyReacted = target.hasReacted(reaction.name);

    // Optimistic local update
    final delta = isCurrentlyReacted ? -1 : 1;
    final updatedReactions = List<String>.from(target.currentUserReactions);
    if (isCurrentlyReacted) {
      updatedReactions.remove(reaction.name);
    } else {
      updatedReactions.add(reaction.name);
    }

    var countLike = target.countReactLike;
    var countLove = target.countReactLove;
    var countHaha = target.countReactHaha;
    var countWow = target.countReactWow;
    var countSad = target.countReactSad;
    var countAngry = target.countReactAngry;

    switch (reaction) {
      case EchoReactionType.like:
        countLike = (countLike + delta).clamp(0, 999999);
      case EchoReactionType.love:
        countLove = (countLove + delta).clamp(0, 999999);
      case EchoReactionType.haha:
        countHaha = (countHaha + delta).clamp(0, 999999);
      case EchoReactionType.wow:
        countWow = (countWow + delta).clamp(0, 999999);
      case EchoReactionType.sad:
        countSad = (countSad + delta).clamp(0, 999999);
      case EchoReactionType.angry:
        countAngry = (countAngry + delta).clamp(0, 999999);
    }

    state = state.copyWith(
      replies: state.replies.map((r) {
        if (r.id != replyId) return r;
        return r.copyWith(
          countReactLike: countLike,
          countReactLove: countLove,
          countReactHaha: countHaha,
          countReactWow: countWow,
          countReactSad: countSad,
          countReactAngry: countAngry,
          currentUserReactions: updatedReactions,
        );
      }).toList(),
    );

    final repo = ref.read(terminalEchoReplyRepositoryProvider);
    await repo.updateReaction(
      replyId: replyId,
      reaction: reaction,
      isCurrentlyReacted: isCurrentlyReacted,
    );
  }

  Future<void> incrementListen(String replyId) async {
    final repo = ref.read(terminalEchoReplyRepositoryProvider);
    await repo.incrementListen(replyId);
  }
}

final terminalEchoThreadControllerProvider =
    NotifierProvider<TerminalEchoThreadController, TerminalEchoThreadState>(
  TerminalEchoThreadController.new,
);
