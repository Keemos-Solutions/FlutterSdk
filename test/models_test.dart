import 'package:test/test.dart';
import 'package:keemos_sdk/src/models.dart';

void main() {
  test('TokenResponse serialization', () {
    final json = {
      'access_token': 'abc123',
      'token_type': 'Bearer',
      'expires_in': 900,
    };
    final t = TokenResponse.fromJson(json);
    expect(t.accessToken, 'abc123');
    expect(t.tokenType, 'Bearer');
    expect(t.expiresIn, 900);
  });

  test('ChangePasswordRequest serialization', () {
    final req = ChangePasswordRequest(
      oldPassword: 'OldPass123!@#',
      newPassword: 'NewPass456!@#',
    );

    final out = req.toJson();
    expect(out['old_password'], 'OldPass123!@#');
    expect(out['new_password'], 'NewPass456!@#');
  });

  test('SocialProviderRequest serialization', () {
    final req = SocialProviderRequest(
      provider: 'facebook',
      token: 'fb_token_value',
    );

    final out = req.toJson();
    expect(out['provider'], 'facebook');
    expect(out['token'], 'fb_token_value');
  });
}
