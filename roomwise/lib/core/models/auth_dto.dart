class RegisterRequestDto {
  final String firstName;
  final String lastName;
  final String email;
  final String password;

  RegisterRequestDto({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'password': password,
  };
}

class LoginRequestDto {
  final String email;
  final String password;

  LoginRequestDto({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class AuthResponseDto {
  final String token;
  final String refreshToken;
  final DateTime refreshExpiresUtc;
  final String? email;
  final List<String> roles;

  AuthResponseDto({
    required this.token,
    required this.refreshToken,
    required this.refreshExpiresUtc,
    this.email,
    required this.roles,
  });

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      refreshExpiresUtc: DateTime.parse(json['refreshExpiresUtc'] as String),
      email: json['email'] as String?,
      roles:
          (json['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
