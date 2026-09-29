import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:gate_closes/features/auth/data/models/user_model.dart';
import 'package:gate_closes/features/auth/data/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockStorageService extends Mock implements StorageService {}

class FakeUserModel extends Fake implements UserModel {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUserModel());
  });
  late MockAuthRemoteDataSource mockRemote;
  late MockStorageService mockStorage;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockRemote = MockAuthRemoteDataSource();
    mockStorage = MockStorageService();
    repository = AuthRepositoryImpl(mockRemote, mockStorage);
  });

  group('AuthRepositoryImpl.login', () {
    const tEmail = 'test@example.com';
    const tPassword = 'password123';
    const tUser = UserModel(
      id: '1',
      email: tEmail,
      name: 'Test',
      token: 'access-token',
      refreshToken: 'refresh-token',
    );

    test('returns Right(user) and persists both tokens on success', () async {
      // Arrange
      when(
        () => mockRemote.login(tEmail, tPassword),
      ).thenAnswer((_) async => tUser);
      when(() => mockStorage.saveToken(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveRefreshToken(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveUserModel(any())).thenAnswer((_) async {});

      // Act
      final result = await repository.login(tEmail, tPassword);

      // Assert
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable(), tUser);
      verify(() => mockStorage.saveToken('access-token')).called(1);
      verify(() => mockStorage.saveRefreshToken('refresh-token')).called(1);
    });

    test('maps UnauthorizedException to UnauthorizedFailure', () async {
      // Arrange
      when(
        () => mockRemote.login(tEmail, tPassword),
      ).thenThrow(const UnauthorizedException('Invalid email or password'));

      // Act
      final result = await repository.login(tEmail, tPassword);

      // Assert
      expect(result.isLeft(), isTrue);
      final failure = result.getLeft().toNullable();
      expect(failure, isA<UnauthorizedFailure>());
      expect(failure!.message, 'Invalid email or password');
      verifyNever(() => mockStorage.saveToken(any()));
    });

    test('maps NetworkException to NetworkFailure', () async {
      // Arrange
      when(
        () => mockRemote.login(tEmail, tPassword),
      ).thenThrow(const NetworkException());

      // Act
      final result = await repository.login(tEmail, tPassword);

      // Assert
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    });

    test('maps ServerException to ServerFailure', () async {
      // Arrange
      when(
        () => mockRemote.login(tEmail, tPassword),
      ).thenThrow(const ServerException('Boom', statusCode: 500));

      // Act
      final result = await repository.login(tEmail, tPassword);

      // Assert
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ServerFailure>());
    });

    test('maps an unexpected error to ServerFailure', () async {
      // Arrange
      when(
        () => mockRemote.login(tEmail, tPassword),
      ).thenThrow(Exception('boom'));

      // Act
      final result = await repository.login(tEmail, tPassword);

      // Assert
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ServerFailure>());
    });
  });

  group('AuthRepositoryImpl.logout', () {
    test('clears the session and returns Right(null)', () async {
      // Arrange
      when(() => mockStorage.readRefreshToken()).thenAnswer((_) async => null);
      when(() => mockRemote.logout(any())).thenAnswer((_) async {});
      when(() => mockStorage.clearSession()).thenAnswer((_) async {});

      // Act
      final result = await repository.logout();

      // Assert
      expect(result.isRight(), isTrue);
      verify(() => mockStorage.clearSession()).called(1);
    });

    test('still clears the local session when offline', () async {
      when(() => mockStorage.readRefreshToken()).thenAnswer((_) async => 'r');
      when(
        () => mockRemote.logout(any()),
      ).thenThrow(const NetworkException());
      when(() => mockStorage.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result.isRight(), isTrue);
      verify(() => mockStorage.clearSession()).called(1);
    });

    test(
      'returns Left(CacheFailure) when clearing the session throws',
      () async {
        // Arrange
        when(
          () => mockStorage.readRefreshToken(),
        ).thenAnswer((_) async => null);
        when(() => mockRemote.logout(any())).thenAnswer((_) async {});
        when(
          () => mockStorage.clearSession(),
        ).thenThrow(Exception('disk error'));

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), isA<CacheFailure>());
      },
    );
  });
}
