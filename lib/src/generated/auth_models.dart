class AuthToken {
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;

  AuthToken({required this.accessToken, this.refreshToken, this.expiresIn});

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
        accessToken: json['access_token'] ?? json['accessToken'] ?? '',
        refreshToken: json['refresh_token'] ?? json['refreshToken'],
        expiresIn: json['expires_in'] ?? json['expiresIn'],
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
      };
}

class UserProfileModel {
  final String? id;
  final String? name;
  final String? email;

  UserProfileModel({this.id, this.name, this.email});

  factory UserProfileModel.fromJson(Map<String, dynamic> json) => UserProfileModel(
        id: json['id'] ?? json['user_id'] ?? json['userId'],
        name: json['name'] ?? json['full_name'] ?? json['fullName'],
        email: json['email'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };
}
