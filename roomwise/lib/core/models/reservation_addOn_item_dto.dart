class ReservationAddOnItemDto {
  final int addOnId;
  final int quantity;

  ReservationAddOnItemDto({required this.addOnId, this.quantity = 1});

  Map<String, dynamic> toJson() => {'addOnId': addOnId, 'quantity': quantity};
}
