import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel parsing against gate-closes-api contracts', () {
    test('parses gate-closes-api login response correctly', () {
      final json = {
        'message': 'Login successful.',
        'user': {
          '_id': '64f1a2b3c4d5e6f7a8b9c0d1',
          'email': 'ava.morgan@example.com',
          'username': 'ava99.01',
          'gender': 'Female',
          'signupCompleted': true,
          'isCompleteProfile': true,
          'picture': 'https://example.com/avatar.png',
        },
        'accessToken': 'header.payload.signature',
        'refreshToken': 'refresh.header.payload.signature',
        'requiresProfileCompletion': false,
      };

      final model = UserModel.fromJson(json);

      expect(model.id, '64f1a2b3c4d5e6f7a8b9c0d1');
      expect(model.email, 'ava.morgan@example.com');
      expect(model.name, 'ava99.01');
      expect(model.gender, 'Female');
      expect(model.token, 'header.payload.signature');
      expect(model.refreshToken, 'refresh.header.payload.signature');
      expect(model.signupCompleted, isTrue);
      expect(model.isCompleteProfile, isTrue);
      expect(model.picture, 'https://example.com/avatar.png');
    });

    test('serializes and deserializes UserModel accurately', () {
      const model = UserModel(
        id: 'user123',
        email: 'user@example.com',
        name: 'user01.23',
        token: 'token123',
        refreshToken: 'refresh123',
        gender: 'Male',
        picture: 'https://example.com/pic.jpg',
      );

      final json = model.toJson();
      expect(json['id'], 'user123');
      expect(json['gender'], 'Male');
      expect(json['picture'], 'https://example.com/pic.jpg');

      final reconstructed = UserModel.fromJson({
        'user': json,
        'accessToken': 'token123',
        'refreshToken': 'refresh123',
      });

      expect(reconstructed.id, model.id);
      expect(reconstructed.email, model.email);
      expect(reconstructed.name, model.name);
      expect(reconstructed.gender, model.gender);
    });

    test('toJson never includes tokens (cached in plaintext prefs)', () {
      const model = UserModel(
        id: 'user123',
        email: 'user@example.com',
        name: 'user01.23',
        token: 'token123',
        refreshToken: 'refresh123',
      );

      final json = model.toJson();
      expect(json.containsKey('token'), isFalse);
      expect(json.containsKey('refreshToken'), isFalse);
    });
  });
}
