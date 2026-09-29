import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/profile/data/repositories/profile_repository.dart';
import 'package:gate_closes/features/profile/domain/entities/profile_entity.dart';
import 'package:gate_closes/features/profile/presentation/controllers/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/signed_in_auth.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late ProviderContainer container;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
  });

  tearDown(() {
    container.dispose();
  });

  group('ProfileController', () {
    const tProfile = ProfileEntity(
      id: '1',
      name: 'Ada Lovelace',
      email: 'ada@example.com',
    );

    test('build() fetches the profile in the background', () async {
      // Arrange
      when(
        () => mockRepository.getProfile(),
      ).thenAnswer((_) async => const Right(tProfile));
      container = ProviderContainer(
        overrides: [
          signedInAuthOverride,
          profileRepositoryProvider.overrideWithValue(mockRepository),
        ],
      )..read(profileControllerProvider);

      // Act — allow the scheduled microtask fetch to complete.
      await Future<void>.delayed(Duration.zero);

      // Assert
      final state = container.read(profileControllerProvider);
      expect(state.isLoading, false);
      expect(state.profile, tProfile);
      expect(state.error, isNull);
    });

    test('a failed fetch surfaces the error and keeps profile null', () async {
      // Arrange
      const tFailure = ServerFailure('Boom');
      when(
        () => mockRepository.getProfile(),
      ).thenAnswer((_) async => const Left(tFailure));
      container = ProviderContainer(
        overrides: [
          signedInAuthOverride,
          profileRepositoryProvider.overrideWithValue(mockRepository),
        ],
      )..read(profileControllerProvider);

      // Act — allow the scheduled microtask fetch to complete.
      await Future<void>.delayed(Duration.zero);

      // Assert
      final state = container.read(profileControllerProvider);
      expect(state.isLoading, false);
      expect(state.profile, isNull);
      expect(state.error, tFailure.message);
    });
  });
}
