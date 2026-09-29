import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:gate_closes/features/connections/domain/repositories/connections_repository.dart';
import 'package:gate_closes/features/connections/presentation/controllers/connections_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/signed_in_auth.dart';

class MockConnectionsRepository extends Mock implements ConnectionsRepository {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late ProviderContainer container;
  late MockConnectionsRepository mockRepository;
  late MockStorageService mockStorage;

  setUp(() {
    mockRepository = MockConnectionsRepository();
    mockStorage = MockStorageService();
    when(() => mockStorage.readUserModel()).thenReturn(null);
    when(() => mockStorage.readToken()).thenAnswer((_) async => null);
  });

  tearDown(() {
    container.dispose();
  });

  group('ConnectionsController', () {
    const tConnections = [
      ConnectionEntity(
        id: 'c1',
        type: ConnectionType.parallelSoul,
        participantIds: ['u1', 'u2'],
        dmKey: 'dm-1',
        otherUserId: 'u2',
        otherUserName: 'jane',
      ),
      ConnectionEntity(
        id: 'c2',
        type: ConnectionType.batonTouch,
        participantIds: ['u1', 'u3'],
        dmKey: 'dm-2',
        otherUserId: 'u3',
        otherUserName: 'sam',
        hasUnread: true,
      ),
    ];

    test('build() fetches connections in the background', () async {
      when(
        () => mockRepository.getConnections(),
      ).thenAnswer((_) async => const Right(tConnections));
      container = ProviderContainer(
        overrides: [
          signedInAuthOverride,
          connectionsRepositoryProvider.overrideWithValue(mockRepository),
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
      )..read(connectionsControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(connectionsControllerProvider);
      expect(state.isLoading, false);
      expect(state.connections, tConnections);
      expect(state.error, isNull);
    });

    test('byType filters client-side per connection paradigm', () async {
      when(
        () => mockRepository.getConnections(),
      ).thenAnswer((_) async => const Right(tConnections));
      container = ProviderContainer(
        overrides: [
          signedInAuthOverride,
          connectionsRepositoryProvider.overrideWithValue(mockRepository),
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
      )..read(connectionsControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(connectionsControllerProvider);
      expect(state.byType(ConnectionType.parallelSoul), [tConnections[0]]);
      expect(state.byType(ConnectionType.batonTouch), [tConnections[1]]);
      expect(state.byType(ConnectionType.destinationThread), isEmpty);
    });

    test('a failed fetch surfaces the error and keeps connections empty',
        () async {
      const tFailure = ServerFailure('Boom');
      when(
        () => mockRepository.getConnections(),
      ).thenAnswer((_) async => const Left(tFailure));
      container = ProviderContainer(
        overrides: [
          signedInAuthOverride,
          connectionsRepositoryProvider.overrideWithValue(mockRepository),
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
      )..read(connectionsControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(connectionsControllerProvider);
      expect(state.isLoading, false);
      expect(state.connections, isEmpty);
      expect(state.error, tFailure.message);
    });
  });
}
