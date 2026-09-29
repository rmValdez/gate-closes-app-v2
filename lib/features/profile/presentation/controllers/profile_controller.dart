import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:gate_closes/features/profile/data/repositories/profile_repository.dart';
import 'package:gate_closes/features/profile/domain/entities/profile_entity.dart';
import 'package:gate_closes/features/profile/domain/usecases/get_profile_usecase.dart';

// --- Dependency wiring (Riverpod providers) ---

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final remote = ProfileRemoteDataSourceImpl(ref.watch(apiServiceProvider));
  return ProfileRepositoryImpl(remote);
});

final getProfileUseCaseProvider = Provider<GetProfileUseCase>(
  (ref) => GetProfileUseCase(ref.watch(profileRepositoryProvider)),
);

// --- State ---

class ProfileState extends Equatable {
  const ProfileState({this.isLoading = false, this.profile, this.error});

  final bool isLoading;
  final ProfileEntity? profile;
  final String? error;

  ProfileState copyWith({
    bool? isLoading,
    ProfileEntity? profile,
    String? error,
  }) =>
      ProfileState(
        isLoading: isLoading ?? this.isLoading,
        profile: profile ?? this.profile,
        // Intentionally not `error ?? this.error`: passing null clears it.
        error: error,
      );

  @override
  List<Object?> get props => [isLoading, profile, error];
}

// --- Controller ---

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    // Refetch from scratch whenever the signed-in user changes, so a previous
    // account's profile never lingers after logout/login.
    final userId = ref.watch(
      authControllerProvider.select((s) => s.user?.id),
    );
    if (userId == null) return const ProfileState();

    unawaited(Future.microtask(fetchProfile));
    return const ProfileState(isLoading: true);
  }

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true);

    final result = await ref.read(getProfileUseCaseProvider)();

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (profile) => state = ProfileState(profile: profile),
    );
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
