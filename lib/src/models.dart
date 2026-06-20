class LoginRequest {
  final String email;
  final String password;
  final String? deviceName;

  LoginRequest({
    required this.email,
    required this.password,
    this.deviceName,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (deviceName != null && deviceName!.trim().isNotEmpty) {
      json['device_name'] = deviceName!.trim();
    }
    return json;
  }
}

class RegisterRequest {
  final String email;
  final String password;
  final String? fullName;

  RegisterRequest({
    required this.email,
    required this.password,
    this.fullName,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (fullName != null && fullName!.trim().isNotEmpty) {
      json['full_name'] = fullName!.trim();
    }
    return json;
  }
}

class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}

class ResetPasswordRequest {
  final String email;
  final String otp;
  final String newPassword;

  ResetPasswordRequest({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      };
}

class SocialProviderRequest {
  final String provider;
  final String token;

  SocialProviderRequest({required this.provider, required this.token});

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'token': token,
      };
}

class ChangePasswordRequest {
  final String oldPassword;
  final String newPassword;

  ChangePasswordRequest({required this.oldPassword, required this.newPassword});

  Map<String, dynamic> toJson() => {
        'old_password': oldPassword,
        'new_password': newPassword,
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
  final String? id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? facebookId;
  final String? googleId;
  final String? appleId;
  final Map<String, dynamic>? appSettings;

  UserProfile({
    this.id,
    this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.facebookId,
    this.googleId,
    this.appleId,
    this.appSettings,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] ?? json['user_id'] ?? json['userId'],
        email: json['email'],
        fullName: json['full_name'] ?? json['fullName'],
        phone: json['phone'],
        avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
        facebookId: json['facebook_id'] ?? json['facebookId'],
        googleId: json['google_id'] ?? json['googleId'],
        appleId: json['apple_id'] ?? json['appleId'],
        appSettings: json['app_settings'] != null
            ? Map<String, dynamic>.from(json['app_settings'] as Map)
            : (json['appSettings'] != null
                ? Map<String, dynamic>.from(json['appSettings'] as Map)
                : null),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'facebook_id': facebookId,
        'google_id': googleId,
        'apple_id': appleId,
        'app_settings': appSettings,
      };
}
