// class CityDto {
//   final int id;
//   final String name;
//   final String countryName;

//   CityDto({required this.id, required this.name, required this.countryName});

//   factory CityDto.fromJson(Map<String, dynamic> json) {
//     String _readString(String k1, String k2, {String fallback = ''}) {
//       final v = json[k1] ?? json[k2];
//       return (v as String?) ?? fallback;
//     }

//     return CityDto(
//       id: json['id'] as int? ?? json['Id'] as int,
//       name: _readString('name', 'Name'),
//       countryName: _readString(
//         'countryName',
//         'CountryName',
//         fallback: 'Bosnia & Herzegovina',
//       ),
//     );
//   }
// }

class CityDto {
  final int id;
  final String name;
  final String countryName;

  CityDto({required this.id, required this.name, required this.countryName});

  factory CityDto.fromJson(Map<String, dynamic> json) {
    return CityDto(
      id: json['id'] as int,
      name: json['name'] as String,

      countryName: json['countryName'] as String? ?? 'Bosnia i Herzegovina',
    );
  }
}
