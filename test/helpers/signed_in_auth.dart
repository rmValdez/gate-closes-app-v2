import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

/// Stands in for [AuthController] with a fixed signed-in user and no
/// background refresh — for tests of controllers scoped to the current user.
class SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
        user: UserEntity(id: 'u1', email: 'u1@example.com', name: 'u1'),
      );
}

/// Add to a `ProviderContainer`'s overrides to start signed in.
final Override signedInAuthOverride =
    authControllerProvider.overrideWith(SignedInAuthController.new);
