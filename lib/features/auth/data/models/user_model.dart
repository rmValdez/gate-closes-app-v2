import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';

/// Data-layer extension of [UserEntity] that knows how to (de)serialize and
/// carries the auth token returned by the API.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    required this.token,
    this.refreshToken,
    super.gender,
    super.picture,
    super.signupCompleted = true,
    super.isCompleteProfile = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
            ? (json['data'] as Map).cast<String, dynamic>()
            : json;
    final user = (payload['user'] is Map<String, dynamic>)
        ? payload['user'] as Map<String, dynamic>
        : (payload['user'] is Map)
            ? (payload['user'] as Map).cast<String, dynamic>()
            : payload;

    final token = (payload['token'] ?? payload['accessToken'] ?? '').toString();
    final refreshToken = payload['refreshToken'] as String?;

    return UserModel(
      id: (user['_id'] ?? user['id'] ?? payload['_id'] ?? payload['id'] ?? '')
          .toString(),
      email: (user['email'] ?? payload['email'] ?? '').toString(),
      name: (user['username'] ??
              user['name'] ??
              payload['username'] ??
              payload['name'] ??
              '')
          .toString(),
      token: token,
      refreshToken: refreshToken,
      gender: user['gender'] as String?,
      picture: user['picture'] as String?,
      signupCompleted: user['signupCompleted'] as bool? ?? true,
      isCompleteProfile: user['isCompleteProfile'] as bool? ?? true,
    );
  }

  /// Short-lived access token (bearer).
  final String token;

  /// Long-lived token used to obtain a new access token. Optional — some
  /// backends issue only an access token.
  final String? refreshToken;

  /// Profile fields only. Tokens are deliberately excluded: this map is
  /// cached in plaintext SharedPreferences, while tokens live exclusively in
  /// `StorageService`'s secure storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'gender': gender,
        'picture': picture,
        'signupCompleted': signupCompleted,
        'isCompleteProfile': isCompleteProfile,
      };

  @override
  List<Object?> get props => [...super.props, token, refreshToken];
}
