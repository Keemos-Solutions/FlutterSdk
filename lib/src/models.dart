class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class TokenResponse {
  final String accessToken;
  final String? tokenType;
  final int? expiresIn;

  TokenResponse({required this.accessToken, this.tokenType, this.expiresIn});

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'] ?? json['accessToken'] ?? '',
        tokenType: json['token_type'],
        expiresIn: json['expires_in'],
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
      };
}

class UserProfile {
  final String? userId;
  final String? fullName;
  final String? email;

  UserProfile({this.userId, this.fullName, this.email});

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['user_id'] ?? json['userId'],
        fullName: json['full_name'] ?? json['fullName'],
        email: json['email'],
      );
}
