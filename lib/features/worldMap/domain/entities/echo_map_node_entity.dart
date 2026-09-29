import 'package:equatable/equatable.dart';

/// The four connection affinities rendered as map nodes.
enum EchoNodeKind {
  terminalEcho,
  parallelSoul,
  destinationThread,
  batonTouch,
}

class TerminalEchoMapNodeEntity extends Equatable {
  const TerminalEchoMapNodeEntity({
    required this.id,
    required this.senderId,
    required this.nodeKind,
    required this.latitude,
    required this.longitude,
    this.replyCount = 0,
    this.listenCount = 0,
    this.reactionCount = 0,
    this.createdAt,
    this.expiresAt,
    this.isNew = false,
  });

  factory TerminalEchoMapNodeEntity.fromGeoJsonFeature(
    Map<String, dynamic> feature,
  ) {
    final properties =
        (feature['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    final geometry =
        (feature['geometry'] as Map?)?.cast<String, dynamic>() ?? {};
    final coordinates = (geometry['coordinates'] as List?) ?? [0.0, 0.0];

    final rawType =
        (properties['type'] ?? feature['type'] ?? 'terminal_echo').toString();
    EchoNodeKind kind;
    switch (rawType) {
      case 'parallel_soul':
        kind = EchoNodeKind.parallelSoul;
      case 'destination_thread':
        kind = EchoNodeKind.destinationThread;
      case 'baton_touch':
        kind = EchoNodeKind.batonTouch;
      default:
        kind = EchoNodeKind.terminalEcho;
    }

    final id =
        (feature['id'] ?? feature['_id'] ?? properties['id'] ?? '').toString();
    final senderId = (properties['senderId'] ?? '').toString();
    final lng = coordinates.isNotEmpty && coordinates[0] is num
        ? (coordinates[0] as num).toDouble()
        : 0.0;
    final lat = coordinates.length > 1 && coordinates[1] is num
        ? (coordinates[1] as num).toDouble()
        : 0.0;

    DateTime? createdAt;
    if (properties['createdAt'] != null) {
      createdAt = DateTime.tryParse(properties['createdAt'].toString());
    }

    return TerminalEchoMapNodeEntity(
      id: id,
      senderId: senderId,
      nodeKind: kind,
      latitude: lat,
      longitude: lng,
      replyCount: (properties['replyCount'] as num?)?.toInt() ?? 0,
      listenCount: (properties['listenCount'] as num?)?.toInt() ?? 0,
      reactionCount: (properties['reactionCount'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      isNew: properties['isNew'] == true,
    );
  }

  final String id;
  final String senderId;
  final EchoNodeKind nodeKind;
  final double latitude;
  final double longitude;
  final int replyCount;
  final int listenCount;
  final int reactionCount;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool isNew;

  @override
  List<Object?> get props => [
        id,
        senderId,
        nodeKind,
        latitude,
        longitude,
        replyCount,
        listenCount,
        reactionCount,
        createdAt,
        expiresAt,
        isNew,
      ];
}
