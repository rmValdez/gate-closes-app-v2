import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/cookie_service.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:gate_closes/features/auth/domain/entities/registration_step.dart';
import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';

/// Repository contract (the abstraction the domain layer depends on).
abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login(String email, String password);

  // --- Signup wizard ---
  Future<Either<Failure, RegistrationStep>> registerEmail(String email);
  Future<Either<Failure, RegistrationStep>> verifyEmail(
    String userId,
    String code,
  );
  Future<Either<Failure, void>> resendCode(String userId);
  Future<Either<Failure, RegistrationStep>> setPassword(
    String userId,
    String password,
    String confirmPassword,
  );
  Future<Either<Failure, RegistrationStep>> setUsernameGender(
    String userId,
    String username,
    String gender,
  );

  // --- Forgot-password wizard ---
  Future<Either<Failure, RegistrationStep>> forgotPassword(String email);
  Future<Either<Failure, void>> resendResetCode(String userId);
  Future<Either<Failure, RegistrationStep>> verifyResetCode(
    String userId,
    String code,
  );
  Future<Either<Failure, RegistrationStep>> resetPassword(
    String userId,
    String password,
    String confirmPassword,
  );

  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserEntity>> refreshAuth();
  Future<Either<Failure, UserEntity>> editProfile({
    String? username,
    String? gender,
  });
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });
}

/// Coordinates the remote data source and local token storage. Catches the
/// data layer's typed exceptions and maps them to typed [Failure] values.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote,
    this._storage, {
    CookieService? cookieService,
  }) : _cookieService = cookieService;

  final AuthRemoteDataSource _remote;
  final StorageService _storage;
  final CookieService? _cookieService;

  @override
  Future<Either<Failure, UserEntity>> login(
    String email,
    String password,
  ) async {
    try {
      final user = await _remote.login(email, password);
      await _storage.saveToken(user.token);
      final refreshToken = user.refreshToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storage.saveRefreshToken(refreshToken);
      }
      // Save full user model to local cache for instant offline startup.
      await _storage.saveUserModel(user);
      return Right(user);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RegistrationStep>> registerEmail(String email) =>
      _step(() => _remote.registerEmail(email));

  @override
  Future<Either<Failure, RegistrationStep>> verifyEmail(
    String userId,
    String code,
  ) =>
      _step(() => _remote.verifyEmail(userId, code));

  @override
  Future<Either<Failure, void>> resendCode(String userId) =>
      _void(() => _remote.resendCode(userId));

  @override
  Future<Either<Failure, RegistrationStep>> setPassword(
    String userId,
    String password,
    String confirmPassword,
  ) =>
      _step(() => _remote.setPassword(userId, password, confirmPassword));

  @override
  Future<Either<Failure, RegistrationStep>> setUsernameGender(
    String userId,
    String username,
    String gender,
  ) =>
      _step(() => _remote.setUsernameGender(userId, username, gender));

  @override
  Future<Either<Failure, RegistrationStep>> forgotPassword(String email) =>
      _step(() => _remote.forgotPassword(email));

  @override
  Future<Either<Failure, void>> resendResetCode(String userId) =>
      _void(() => _remote.resendResetCode(userId));

  @override
  Future<Either<Failure, RegistrationStep>> verifyResetCode(
    String userId,
    String code,
  ) =>
      _step(() => _remote.verifyResetCode(userId, code));

  @override
  Future<Either<Failure, RegistrationStep>> resetPassword(
    String userId,
    String password,
    String confirmPassword,
  ) =>
      _step(() => _remote.resetPassword(userId, password, confirmPassword));

  @override
  Future<Either<Failure, void>> logout() async {
    // Best-effort server-side revoke, then always clear the local session.
    // Refusing to sign out while offline would trap the user in the app; once
    // the refresh token is deleted from the device, the orphaned server
    // session can't be used from here and simply expires.
    try {
      final refreshToken = await _storage.readRefreshToken();
      await _remote.logout(refreshToken);
    } on AppException catch (_) {
      // Offline, server error, or session already revoked — sign out anyway.
    }

    try {
      await _storage.clearSession();
      await _cookieService?.clearCookies();
      return const Right(null);
    } on Object catch (e) {
      return Left(CacheFailure('Failed to clear local session: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> refreshAuth() async {
    try {
      final token = await _storage.readToken();
      if (token == null || token.isEmpty) {
        return const Left(UnauthorizedFailure('No token found'));
      }
      final user = await _remote.checkAuth(token);
      // Update local cache with fresh background fetch.
      await _storage.saveUserModel(user);
      return Right(user);
    } on UnauthorizedException catch (e) {
      await _storage.clearSession(); // Clear stale tokens.
      await _cookieService?.clearCookies();
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Shared try/catch for every wizard step — they all map errors the same
  /// way and differ only in which remote call they wrap.
  Future<Either<Failure, RegistrationStep>> _step(
    Future<RegistrationStep> Function() call,
  ) async {
    try {
      return Right(await call());
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> _void(Future<void> Function() call) async {
    try {
      await call();
      return const Right(null);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> editProfile({
    String? username,
    String? gender,
  }) async {
    try {
      final updated = await _remote.editProfile(
        username: username,
        gender: gender,
      );
      await _storage.saveUserModel(updated);
      return Right(updated);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) =>
      _void(
        () => _remote.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        ),
      );
}
