import 'package:equatable/equatable.dart';

/// Domain entity representing a reply to a Terminal Echo.
class TerminalEchoReplyEntity extends Equatable {
  const TerminalEchoReplyEntity({
    required this.id,
    required this.terminalEchoId,
    required this.senderId,
    required this.createdAt,
    this.textMessage = '',
    this.fileUrl,
    this.fileName,
    this.audioDuration = 0,
    this.waveformData = const [],
    this.countListens = 0,
    this.countReactLike = 0,
    this.countReactLove = 0,
    this.countReactHaha = 0,
    this.countReactWow = 0,
    this.countReactSad = 0,
    this.countReactAngry = 0,
    this.senderUsername,
    this.senderGender,
    this.currentUserReactions = const [],
  });

  final String id;
  final String terminalEchoId;
  final String senderId;
  final String textMessage;
  final DateTime createdAt;
  final String? fileUrl;
  final String? fileName;
  final double audioDuration;
  final List<double> waveformData;
  final int countListens;
  final int countReactLike;
  final int countReactLove;
  final int countReactHaha;
  final int countReactWow;
  final int countReactSad;
  final int countReactAngry;
  final String? senderUsername;
  final String? senderGender;
  final List<String> currentUserReactions;

  bool get isVoiceMemo => fileUrl != null && fileUrl!.isNotEmpty;

  int get totalReactions =>
      countReactLike +
      countReactLove +
      countReactHaha +
      countReactWow +
      countReactSad +
      countReactAngry;

  bool hasReacted(String emojiOrKey) =>
      currentUserReactions.contains(emojiOrKey);

  TerminalEchoReplyEntity copyWith({
    String? id,
    String? terminalEchoId,
    String? senderId,
    String? textMessage,
    DateTime? createdAt,
    String? fileUrl,
    String? fileName,
    double? audioDuration,
    List<double>? waveformData,
    int? countListens,
    int? countReactLike,
    int? countReactLove,
    int? countReactHaha,
    int? countReactWow,
    int? countReactSad,
    int? countReactAngry,
    String? senderUsername,
    String? senderGender,
    List<String>? currentUserReactions,
  }) {
    return TerminalEchoReplyEntity(
      id: id ?? this.id,
      terminalEchoId: terminalEchoId ?? this.terminalEchoId,
      senderId: senderId ?? this.senderId,
      textMessage: textMessage ?? this.textMessage,
      createdAt: createdAt ?? this.createdAt,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      audioDuration: audioDuration ?? this.audioDuration,
      waveformData: waveformData ?? this.waveformData,
      countListens: countListens ?? this.countListens,
      countReactLike: countReactLike ?? this.countReactLike,
      countReactLove: countReactLove ?? this.countReactLove,
      countReactHaha: countReactHaha ?? this.countReactHaha,
      countReactWow: countReactWow ?? this.countReactWow,
      countReactSad: countReactSad ?? this.countReactSad,
      countReactAngry: countReactAngry ?? this.countReactAngry,
      senderUsername: senderUsername ?? this.senderUsername,
      senderGender: senderGender ?? this.senderGender,
      currentUserReactions: currentUserReactions ?? this.currentUserReactions,
    );
  }

  /// Applies a realtime `{reactionKey, action}` broadcast: +1 for
  /// `increment`, -1 otherwise, never below zero. Unknown keys are ignored.
  TerminalEchoReplyEntity withReactionDelta(String reactionKey, String action) {
    final d = action == 'increment' ? 1 : -1;
    int bump(int count) => (count + d) < 0 ? 0 : count + d;
    switch (reactionKey) {
      case 'like':
        return copyWith(countReactLike: bump(countReactLike));
      case 'love':
        return copyWith(countReactLove: bump(countReactLove));
      case 'haha':
        return copyWith(countReactHaha: bump(countReactHaha));
      case 'wow':
        return copyWith(countReactWow: bump(countReactWow));
      case 'sad':
        return copyWith(countReactSad: bump(countReactSad));
      case 'angry':
        return copyWith(countReactAngry: bump(countReactAngry));
      default:
        return this;
    }
  }

  @override
  List<Object?> get props => [
        id,
        terminalEchoId,
        senderId,
        textMessage,
        createdAt,
        fileUrl,
        fileName,
        audioDuration,
        waveformData,
        countListens,
        countReactLike,
        countReactLove,
        countReactHaha,
        countReactWow,
        countReactSad,
        countReactAngry,
        senderUsername,
        senderGender,
        currentUserReactions,
      ];
}
