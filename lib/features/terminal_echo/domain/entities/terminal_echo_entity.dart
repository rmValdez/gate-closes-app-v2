import 'package:equatable/equatable.dart';

/// Supported emoji reaction types for a Terminal Echo.
enum EchoReactionType {
  like,
  love,
  haha,
  wow,
  sad,
  angry,
}

/// Domain entity representing a spatial public Terminal Echo.
class TerminalEchoEntity extends Equatable {
  const TerminalEchoEntity({
    required this.id,
    required this.senderId,
    required this.textMessage,
    required this.airportIata,
    required this.createdAt,
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
    this.userReaction,
  });

  final String id;
  final String senderId;
  final String textMessage;
  final String airportIata;
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
  final String? userReaction;

  bool get isVoiceMemo => fileUrl != null && fileUrl!.isNotEmpty;

  int get totalReactions =>
      countReactLike +
      countReactLove +
      countReactHaha +
      countReactWow +
      countReactSad +
      countReactAngry;

  TerminalEchoEntity copyWith({
    String? id,
    String? senderId,
    String? textMessage,
    String? airportIata,
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
    String? userReaction,
  }) {
    return TerminalEchoEntity(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      textMessage: textMessage ?? this.textMessage,
      airportIata: airportIata ?? this.airportIata,
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
      userReaction: userReaction ?? this.userReaction,
    );
  }

  /// Applies a realtime `{reactionKey, action}` broadcast: +1 for
  /// `increment`, -1 otherwise, never below zero. Unknown keys are ignored.
  TerminalEchoEntity withReactionDelta(String reactionKey, String action) {
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
        senderId,
        textMessage,
        airportIata,
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
        userReaction,
      ];
}
