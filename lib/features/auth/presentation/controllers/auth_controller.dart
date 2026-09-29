import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/core/services/cookie_service.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:gate_closes/features/auth/data/repositories/auth_repository.dart';
import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';
import 'package:gate_closes/features/auth/domain/usecases/login_usecase.dart';
import 'package:gate_closes/features/auth/domain/usecases/refresh_auth_usecase.dart';

// --- Dependency wiring (Riverpod providers) ---

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    storage: ref.watch(storageServiceProvider),
    cookieService: ref.watch(cookieServiceProvider),
    onUnauthenticated: () {
      unawaited(ref.read(authControllerProvider.notifier).onUnauthenticated());
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = AuthRemoteDataSourceImpl(ref.watch(apiServiceProvider));
  return AuthRepositoryImpl(
    remote,
    ref.watch(storageServiceProvider),
    cookieService: ref.watch(cookieServiceProvider),
  );
});

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final refreshAuthUseCaseProvider = Provider<RefreshAuthUseCase>(
  (ref) => RefreshAuthUseCase(ref.watch(authRepositoryProvider)),
);

// --- State ---

class AuthState extends Equatable {
  const AuthState({this.isLoading = false, this.user, this.error});

  final bool isLoading;
  final UserEntity? user;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({bool? isLoading, UserEntity? user, String? error}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        user: user ?? this.user,
        // Intentionally not `error ?? this.error`: passing null clears it.
        error: error,
      );

  @override
  List<Object?> get props => [isLoading, user, error];
}

// --- Controller ---

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Hydrate state from local cache (instant startup, no flicker).
    final cachedUser = ref.read(storageServiceProvider).readUserModel();
    if (cachedUser != null) {
      // Fire-and-forget background refresh to re-validate the cached user.
      unawaited(Future.microtask(refreshAuth));
    }
    return AuthState(user: cachedUser);
  }

  /// Called by the ApiService interceptor when a 401 cannot be recovered.
  Future<void> onUnauthenticated() async {
    await ref.read(storageServiceProvider).clearSession();
    state = const AuthState();
  }

  /// Silent background re-validation of the stored token.
  Future<void> refreshAuth() async {
    final result = await ref.read(refreshAuthUseCaseProvider).execute();
    result.fold(
      (failure) {
        // Only a rejected session signs the user out. Network/server errors
        // (offline cold start, API blip) keep the cached user so the app
        // still opens; the next authenticated call re-validates.
        if (failure is UnauthorizedFailure) state = const AuthState();
      },
      (user) => state = AuthState(user: user),
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    final result = await ref.read(loginUseCaseProvider)(email, password);

    return result.fold(
      (failure) {
        state = AuthState(error: failure.message);
        return false;
      },
      (user) {
        state = AuthState(user: user);
        return true;
      },
    );
  }

  Future<bool> logout() async {
    final result = await ref.read(authRepositoryProvider).logout();
    return result.fold(
      // Keep the user signed in on failure — server session was not revoked.
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (_) {
        state = const AuthState();
        return true;
      },
    );
  }

  Future<bool> editProfile({String? username, String? gender}) async {
    state = state.copyWith(isLoading: true);
    final result = await ref.read(authRepositoryProvider).editProfile(
          username: username,
          gender: gender,
        );
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (user) {
        state = state.copyWith(isLoading: false, user: user);
        return true;
      },
    );
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false);
        return true;
      },
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
