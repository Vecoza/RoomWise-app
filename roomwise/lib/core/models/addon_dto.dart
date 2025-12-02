class AddonDto {
  final int id;
  final int hotelId;
  final String name;
  final String? description;
  final String pricingModel;
  final double price;
  final String currency;
  final bool isActive;

  AddonDto({
    required this.id,
    required this.hotelId,
    required this.name,
    required this.description,
    required this.pricingModel,
    required this.price,
    required this.currency,
    required this.isActive,
  });

  factory AddonDto.fromJson(Map<String, dynamic> json) {
    return AddonDto(
      id: json['id'] ?? 0,
      hotelId: json['hotelId'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      pricingModel: json['pricingModel'] ?? 'PerNight',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EUR',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hotelId': hotelId,
      'name': name,
      'description': description,
      'pricingModel': pricingModel,
      'price': price,
      'currency': currency,
      'isActive': isActive,
    };
  }
}
