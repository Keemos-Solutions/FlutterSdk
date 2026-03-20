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
}
