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
  final double? displayTotalOverride;

  const GuestReservationConfirmScreen({
    super.key,
    required this.reservation,
    required this.hotel,
    required this.roomType,
    this.paymentIntent,
    this.displayTotalOverride,
  });

  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  int get _nights =>
      reservation.checkOut.difference(reservation.checkIn).inDays.clamp(1, 365);

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day.$month.$year';
  }

  String _formatDateRange() {
    return '${_formatDate(reservation.checkIn)} – ${_formatDate(reservation.checkOut)}';
  }

  (String label, Color color, Color bg) _paymentStatusStyle() {
    if (paymentIntent == null) {
      return (
        'Pay at property',
        const Color(0xFF6B7280),
        const Color(0xFFE5E7EB),
      );
    }

    final status = paymentIntent!.status.toLowerCase();
    if (status.contains('succeed') || status == 'succeeded') {
      return (
        'Payment completed',
        _primaryGreen,
        _primaryGreen.withOpacity(0.08),
      );
    }
    if (status.contains('processing')) {
      return (
        'Payment processing',
        const Color(0xFF2563EB),
        const Color(0xFFDBEAFE),
      );
    }
    if (status.contains('requires')) {
      return (
        'Action required',
        const Color(0xFFF97316),
        const Color(0xFFFFEDD5),
      );
    }

    return (
      'Payment: ${paymentIntent!.status}',
      const Color(0xFF6B7280),
      const Color(0xFFE5E7EB),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final effectiveCurrency = r.currency.toUpperCase();
    final expected = displayTotalOverride ?? r.total;

    double? totalDisplay;
    String? currencyDisplay;

    if (displayTotalOverride != null) {
      totalDisplay = displayTotalOverride;
      currencyDisplay = effectiveCurrency;
    }

    if (totalDisplay == null && paymentIntent != null) {
      final raw = paymentIntent!.amount.toDouble();
      final coerced = _coerceAmount(raw, expected);
      totalDisplay = coerced;
      currencyDisplay = paymentIntent!.currency.toUpperCase();
    }

    totalDisplay ??= r.total;
    currencyDisplay ??= effectiveCurrency;

    final totalText =
        '$currencyDisplay ${totalDisplay.toStringAsFixed(2)}';
    final (statusLabel, statusColor, statusBg) = _paymentStatusStyle();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Reservation confirmed',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Success badge
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _primaryGreen.withOpacity(0.12),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 42,
                                color: _primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Your booking is confirmed!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'We’ve sent your confirmation to your email.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: _textMuted),
                            ),
                            const SizedBox(height: 20),

                            // Main card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hotel & room
                                  Text(
                                    hotel.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    roomType.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Dates & guests row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: _bgColor,
                                        ),
                                        child: const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 18,
                                          color: _textMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Stay details',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDateRange(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: _textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$_nights night${_nights == 1 ? '' : 's'} • ${r.guests} guest${r.guests == 1 ? '' : 's'}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: _textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Payment + total
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.payments_outlined,
                                              size: 14,
                                              color: statusColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Total paid',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _textMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            totalText,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: _accentOrange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  const Divider(height: 20),

                                  // Confirmation number
                                  if (r.confirmationNumber != null) ...[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.confirmation_number_outlined,
                                          size: 18,
                                          color: _textMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Confirmation number',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                r.confirmationNumber!,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                  ],

                                  // Info text
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: _textMuted,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'You can view or manage this reservation from your bookings at any time.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Sticky bottom button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            );
                          },
                          child: const Text(
                            'Back to home',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Some backends return minor units (cents), some return major units.
  // If the raw amount is already close to expected, use it; otherwise divide by 100.
  double _coerceAmount(double raw, double expected) {
    if ((raw - expected).abs() < 1.0) return raw;
    return raw / 100.0;
  }
}
