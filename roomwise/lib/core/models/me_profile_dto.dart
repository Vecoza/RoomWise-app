class MeProfileDto {
  final String userId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String preferredLanguage;
  final int loyaltyBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? avatarUrl;

  MeProfileDto({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.preferredLanguage,
    required this.loyaltyBalance,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.phone,
  });

  factory MeProfileDto.fromJson(Map<String, dynamic> json) {
    final lang =
        json['preferredLanguage'] ?? json['language'] ?? json['locale'];
    return MeProfileDto(
      userId: json['userId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      phone: json['phone'] as String?,
      preferredLanguage: lang as String? ?? '',
      loyaltyBalance: (json['loyaltyBalance'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class UpdateProfileRequestDto {
  final String firstName;
  final String lastName;
  final String? phone;
  final String preferredLanguage;
  final String? avatarUrl;

  UpdateProfileRequestDto({
    required this.firstName,
    required this.lastName,
    required this.preferredLanguage,
    this.avatarUrl,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        // Send both preferredLanguage and language to be resilient to
        // different backend property names.
        'preferredLanguage': preferredLanguage,
        'language': preferredLanguage,
        'avatarUrl': avatarUrl,
      };
}

class ChangePasswordRequestDto {
  final String currentPassword;
  final String newPassword;

  ChangePasswordRequestDto({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        // Some backends expect "oldPassword" instead of "currentPassword".
        // Send both to stay compatible.
        'currentPassword': currentPassword,
        'oldPassword': currentPassword,
        'newPassword': newPassword,
      };
}
