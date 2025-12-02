class PaymentIntentDto {
  final int id;
  final int reservationId;
  final String stripePaymentIntentId;
  final int amount;
  final String currency;
  final String status;
  final String clientSecret;

  PaymentIntentDto({
    required this.id,
    required this.reservationId,
    required this.stripePaymentIntentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.clientSecret,
  });

  factory PaymentIntentDto.fromJson(Map<String, dynamic> json) {
    return PaymentIntentDto(
      id: json['id'] as int? ?? 0,
      reservationId: json['reservationId'] as int? ?? 0,
      stripePaymentIntentId: json['stripePaymentIntentId'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'eur',
      status: json['status'] as String? ?? '',
      clientSecret: json['clientSecret'] as String? ?? '',
    );
  }
}
