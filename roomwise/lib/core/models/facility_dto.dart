class FacilityDto {
  final int id;
  final String code;
  final String name;

  FacilityDto({required this.id, required this.code, required this.name});

  factory FacilityDto.fromJson(Map<String, dynamic> json) {
    return FacilityDto(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'code': code, 'name': name};
  }
}
