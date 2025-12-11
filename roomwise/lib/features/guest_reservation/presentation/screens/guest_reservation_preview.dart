import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/payment_dto.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'guest_reservation_confirm_screen.dart';

class GuestReservationPreviewScreen extends StatefulWidget {
  final ReservationDto reservation;
  final HotelDetailsDto hotel;
  final AvailableRoomTypeDto roomType;
  final String paymentMethod; // 'Card' or 'PayOnArrival'

  const GuestReservationPreviewScreen({
    super.key,
    required this.reservation,
    required this.hotel,
    required this.roomType,
    required this.paymentMethod,
  });

  @override
  State<GuestReservationPreviewScreen> createState() =>
      _GuestReservationPreviewScreenState();
}

class _GuestReservationPreviewScreenState
    extends State<GuestReservationPreviewScreen> {
  // design tokens (same palette as other guest screens)
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _submitting = false;
  String? _error;
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'preview-body');

  @override
  void initState() {
    super.initState();
    _logScreenData();
  }

  void _logScreenData() {
    final r = widget.reservation;
    final h = widget.hotel;
    final room = widget.roomType;
    debugPrint(
      '[PreviewScreen] reservationId=${r.id}, hotel=${h.name}, room=${room.name}, '
      'paymentMethod=${widget.paymentMethod}, guests=${r.guests}, '
      'total=${r.currency} ${r.total.toStringAsFixed(2)}, '
      'dates=${r.checkIn} -> ${r.checkOut}',
    );

    // After first frame, log body size to confirm it's in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = _bodyKey.currentContext?.size;
      debugPrint('[PreviewScreen] body size: $size');
    });
  }

  Future<void> _onConfirmPressed() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      PaymentIntentDto? intent;

      if (widget.paymentMethod == 'Card') {
        final api = context.read<RoomWiseApiClient>();

        // Ask backend for PaymentIntent for this reservation
        intent = await api.createPaymentIntent(
          reservationId: widget.reservation.id,
          paymentMethod: 'Card',
        );
        // Stripe confirmation would go here using intent.clientSecret
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GuestReservationConfirmScreen(
            reservation: widget.reservation,
            hotel: widget.hotel,
            roomType: widget.roomType,
            paymentIntent: intent,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to confirm reservation. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final isCard = widget.paymentMethod == 'Card';

    debugPrint('[PreviewScreen] build -> start');

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: BackButton(
          color: _textPrimary,
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Review your stay',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      // IMPORTANT: we no longer use bottomNavigationBar
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepsHeader(),
                    const SizedBox(height: 16),
                    _buildSummaryHero(),
                    const SizedBox(height: 16),
                    _buildHotelCard(),
                    const SizedBox(height: 16),
                    _buildDetailsCard(),
                    const SizedBox(height: 16),
                    _buildPaymentCard(isCard),
                    const SizedBox(height: 14),
                    _buildFinePrint(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Sticky bottom row (replaces bottomNavigationBar)
            _buildBottomBarRow(isCard),
          ],
        ),
      ),
    );
  }

  // ---------- UI sections ----------

  Widget _buildBottomBarRow(bool isCard) {
    final r = widget.reservation;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You will pay',
                  style: TextStyle(fontSize: 11, color: _textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.currency} ${r.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _accentOrange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            width: 180,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _submitting ? null : _onConfirmPressed,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isCard ? 'Confirm & pay' : 'Confirm reservation',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stepper: Stay → Add-ons → Payment → Review
  Widget _buildStepsHeader() {
    final steps = <Map<String, Object>>[
      {'label': 'Stay', 'icon': Icons.hotel},
      {'label': 'Add-ons', 'icon': Icons.extension},
      {'label': 'Payment', 'icon': Icons.credit_card},
      {'label': 'Review', 'icon': Icons.visibility_outlined},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isActive = index <= 3; // last step (Review) active
              final label = steps[index]['label'] as String;
              final icon = steps[index]['icon'] as IconData;

              return Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: isActive
                          ? _primaryGreen
                          : Colors.grey.shade300,
                      child: Icon(
                        icon,
                        size: 13,
                        color: isActive ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    if (width > 360) ...[
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive ? _textPrimary : _textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// Gradient hero with dates + payment pill
  Widget _buildSummaryHero() {
    final r = widget.reservation;
    final isCard = widget.paymentMethod == 'Card';
    final nights = widgetDateRangeNights;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF05A87A), Color(0xFF0FB18A), Color(0xFFFF7A3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'One last look before you go',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(r.checkIn)} → ${_formatDate(r.checkOut)} · $nights night${nights == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCard
                                  ? Icons.credit_card
                                  : Icons.meeting_room_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isCard ? 'Card payment' : 'Pay at property',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Guests: ${r.guests}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelCard() {
    final hotel = widget.hotel;
    final room = widget.roomType;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hotel name + city
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  hotel.name.isNotEmpty ? hotel.name[0].toUpperCase() : 'H',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: _textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hotel.city,
                            style: const TextStyle(
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
          const SizedBox(height: 10),
          // Room details row
          Row(
            children: [
              const Icon(Icons.bed_outlined, size: 16, color: _textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  room.name,
                  style: const TextStyle(fontSize: 13, color: _textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final r = widget.reservation;
    final nights = widgetDateRangeNights;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stay details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dateBox(
                  label: 'Check-in',
                  icon: Icons.login,
                  value: _formatDate(r.checkIn),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateBox(
                  label: 'Check-out',
                  icon: Icons.logout,
                  value: _formatDate(r.checkOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pill(
                icon: Icons.nightlight_round,
                label: '$nights night${nights == 1 ? '' : 's'}',
              ),
              _pill(
                icon: Icons.person_outline,
                label: '${r.guests} guest${r.guests == 1 ? '' : 's'}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total amount',
                style: TextStyle(fontSize: 12, color: _textMuted),
              ),
              Text(
                '${r.currency} ${r.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _accentOrange,
                ),
              ),
            ],
          ),
          if (r.confirmationNumber != null) ...[
            const SizedBox(height: 10),
            Text(
              'Temporary reference: ${r.confirmationNumber}',
              style: const TextStyle(fontSize: 11, color: _textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(bool isCard) {
    final r = widget.reservation;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCard ? Icons.credit_card : Icons.meeting_room_outlined,
                  size: 20,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCard ? 'Card (online via Stripe)' : 'Pay at property',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isCard
                          ? 'We’ll securely process ${r.currency} ${r.total.toStringAsFixed(2)} with your card.'
                          : 'You’ll pay ${r.currency} ${r.total.toStringAsFixed(2)} directly at the property when you arrive.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinePrint() {
    return const Text(
      'By confirming, you agree to the property’s cancellation policy and '
      'RoomWise terms of service.',
      style: TextStyle(fontSize: 11, color: _textMuted, height: 1.4),
    );
  }

  // ---------- small helpers ----------

  Widget _dateBox({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: _textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryGreen),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _textPrimary),
          ),
        ],
      ),
    );
  }

  // helper: nights if DTO doesn't provide
  int get widgetDateRangeNights {
    final diff = widget.reservation.checkOut
        .difference(widget.reservation.checkIn)
        .inDays;
    return diff > 0 ? diff : 1;
  }

  // DATE FORMATTER – no time part
  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = d.day.toString().padLeft(2, '0');
    final month = months[d.month - 1];
    final year = d.year.toString();
    return '$day $month $year'; // e.g. 20 Dec 2025
  }
}
