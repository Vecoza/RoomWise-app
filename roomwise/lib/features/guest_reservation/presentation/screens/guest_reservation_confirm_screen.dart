import 'package:flutter/material.dart';
import 'package:roomwise/core/models/payment_dto.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';

class GuestReservationConfirmScreen extends StatelessWidget {
  final ReservationDto reservation;
  final HotelDetailsDto hotel;
  final AvailableRoomTypeDto roomType;
  final PaymentIntentDto? paymentIntent;

  const GuestReservationConfirmScreen({
    super.key,
    required this.reservation,
    required this.hotel,
    required this.roomType,
    this.paymentIntent,
  });

  @override
  Widget build(BuildContext context) {
    final r = reservation;

    return Scaffold(
      appBar: AppBar(title: const Text('Reservation confirmed')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your booking is confirmed!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              hotel.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              roomType.name,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '${r.checkIn.toLocal()} → ${r.checkOut.toLocal()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text('Guests: ${r.guests}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              'Total: ${r.currency} ${r.total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (r.confirmationNumber != null)
              Text(
                'Confirmation number: ${r.confirmationNumber}',
                style: const TextStyle(fontSize: 13),
              ),
            if (paymentIntent != null) ...[
              const SizedBox(height: 8),
              Text(
                'Payment status: ${paymentIntent!.status}',
                style: const TextStyle(fontSize: 13),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Payment method: Pay at property',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Back to home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
