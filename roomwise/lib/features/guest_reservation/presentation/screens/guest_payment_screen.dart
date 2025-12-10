import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'package:roomwise/features/guest_reservation/presentation/screens/guest_reservation_preview';

class GuestPaymentScreen extends StatefulWidget {
  final ReservationDto reservation;
  final HotelDetailsDto hotel;
  final AvailableRoomTypeDto roomType;
  final String clientSecret;

  const GuestPaymentScreen({
    super.key,
    required this.reservation,
    required this.hotel,
    required this.roomType,
    required this.clientSecret,
  });

  @override
  State<GuestPaymentScreen> createState() => _GuestPaymentScreenState();
}

class _GuestPaymentScreenState extends State<GuestPaymentScreen> {
  static const _primaryGreen = Color(0xFF05A87A);

  bool _loading = false;
  String? _error;

  CardFieldInputDetails? _cardDetails;
  final TextEditingController _cardHolderController = TextEditingController();

  @override
  void dispose() {
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _onContinueToPreview() async {
    if (_cardDetails?.complete != true) {
      setState(() {
        _error = 'Please enter complete card details.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: widget.clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name: _cardHolderController.text.trim().isEmpty
                  ? null
                  : _cardHolderController.text.trim(),
            ),
          ),
        ),
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuestReservationPreviewScreen(
            reservation: widget.reservation,
            hotel: widget.hotel,
            roomType: widget.roomType,
            paymentMethod: 'Card',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.hotel.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.roomType.name,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              'Total: ${r.currency} ${r.total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 24),
            const Text(
              'Card details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cardHolderController,
              decoration: const InputDecoration(
                labelText: 'Name on card (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            CardField(
              onCardChanged: (details) {
                setState(() => _cardDetails = details);
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : _onContinueToPreview,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue to preview'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
