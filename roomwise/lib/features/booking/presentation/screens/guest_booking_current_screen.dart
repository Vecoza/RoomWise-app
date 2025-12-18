import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';
import 'package:roomwise/features/booking/sync/bookings_sync.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestBookingCurrentScreen extends StatefulWidget {
  final GuestBookingListItemDto booking;

  const GuestBookingCurrentScreen({super.key, required this.booking});

  @override
  State<GuestBookingCurrentScreen> createState() =>
      _GuestBookingCurrentScreenState();
}

class _GuestBookingCurrentScreenState extends State<GuestBookingCurrentScreen> {
  // Design tokens
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _isCancelling = false;

  int get _nights => widget.booking.checkOut
      .difference(widget.booking.checkIn)
      .inDays
      .clamp(1, 365);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final booking = widget.booking;
    final dateRange =
        '${_formatDate(booking.checkIn)} – ${_formatDate(booking.checkOut)}';

    final daysUntil = booking.checkIn
        .difference(DateTime.now())
        .inDays
        .clamp(0, 365);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgColor,
        centerTitle: false,
        title: Text(
          t.bookingDetailsTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderSection(
                              booking: booking,
                              dateRange: dateRange,
                              nights: _nights,
                              daysUntil: daysUntil,
                            ),
                            const SizedBox(height: 32),

                            // DETAILS CARD
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionTitle(t.bookingCurrentStayDetails),
                                  const SizedBox(height: 8),
                                  _DetailRow(
                                    label: t.bookingDetailsRoomType,
                                    value: booking.roomTypeName,
                                  ),
                                  _DetailRow(
                                    label: t.bookingDetailsGuests,
                                    value:
                                        '${booking.guests} ${t.guestsLabel(booking.guests)}',
                                  ),
                                  _DetailRow(
                                    label: t.bookingDetailsNights,
                                    value: '$_nights',
                                  ),
                                  _DetailRow(
                                    label: t.bookingDetailsTotal,
                                    value:
                                        '${booking.currency} ${booking.total.toStringAsFixed(2)}',
                                    highlight: true,
                                  ),
                                  const SizedBox(height: 16),
                                  _SectionTitle(t.bookingPastStatusTitle),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2563EB,
                                          ).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.flight_takeoff,
                                              size: 16,
                                              color: Color(0xFF2563EB),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              t.bookingCurrentStatusUpcoming,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    daysUntil == 0
                                        ? t.bookingCurrentToday
                                        : t.bookingCurrentCountdown(
                                            _formatDate(booking.checkIn),
                                            daysUntil,
                                          ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _SectionTitle(t.bookingCurrentImportant),
                                  const SizedBox(height: 8),
                                  Text(
                                    t.bookingCurrentImportantText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _textMuted,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // BOTTOM ACTION
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _bgColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t.bookingCurrentChangePlans,
                        style:
                            const TextStyle(fontSize: 12, color: _textMuted),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _isCancelling ? null : _onCancelPressed,
                        child: _isCancelling
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                t.bookingCurrentCancel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCancelPressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel reservation'),
        content: const Text(
          'Are you sure you want to cancel this reservation?\n\n'
          'Refunds depend on the hotel’s cancellation policy and how close '
          'you are to check-in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep reservation'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, cancel',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);

    try {
      final api = context.read<RoomWiseApiClient>();
      await api.cancelReservation(widget.booking.id);

      if (!mounted) return;

      context.read<BookingsSync>().markChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation has been cancelled.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You can't cancel this reservation less than 24h before check-in.",
          ),
        ),
      );
    }
  }

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
    return '${d.day} ${months[d.month - 1]}';
  }
}

/// HEADER → hero image + gradient + floating card (matching past screen)
class _HeaderSection extends StatelessWidget {
  final GuestBookingListItemDto booking;
  final String dateRange;
  final int nights;
  final int daysUntil;

  const _HeaderSection({
    required this.booking,
    required this.dateRange,
    required this.nights,
    required this.daysUntil,
  });

  static const _accentOrange = Color(0xFFFF7A3C);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final image = booking.thumbnailUrl;
    final hasImage = image != null && image.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: hasImage
                ? Image.network(image!, fit: BoxFit.cover)
                : Container(color: Colors.grey.shade300),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.45),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
                Text(
                  daysUntil == 0
                      ? 'Check-in today'
                      : '${daysUntil} day${daysUntil == 1 ? '' : 's'} to go',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: -26,
          child: Material(
            color: Colors.white,
            elevation: 6,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.hotelName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                          booking.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.date_range, size: 16, color: _textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$dateRange · $nights night${nights == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: _textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${booking.guests} guest${booking.guests == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${booking.currency} ${booking.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _accentOrange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Total price',
                            style: TextStyle(fontSize: 11, color: _textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
      color: highlight ? Colors.black : _textMuted,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _textMuted)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
