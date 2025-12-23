class AdminAddonUpsertRequest {
  final String name;
  final String? description;
  final String pricingModel; // e.g., PerStay | PerNight
  final double price;
  final String currency;
  final bool isActive;

  const AdminAddonUpsertRequest({
    required this.name,
    this.description,
    required this.pricingModel,
    required this.price,
    required this.currency,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'pricingModel': pricingModel,
        'price': price,
        'currency': currency,
        'isActive': isActive,
      };
}
