import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';

class GuestBookingCurrentScreen extends StatefulWidget {
  final GuestBookingListItemDto booking;

  const GuestBookingCurrentScreen({super.key, required this.booking});

  @override
  State<GuestBookingCurrentScreen> createState() =>
      _GuestBookingCurrentScreenState();
}

class _GuestBookingCurrentScreenState extends State<GuestBookingCurrentScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);

  bool _isCancelling = false;

  int get _nights => widget.booking.checkOut
      .difference(widget.booking.checkIn)
      .inDays
      .clamp(1, 365);

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final dateRange =
        '${_formatDate(booking.checkIn)} - ${_formatDate(booking.checkOut)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Reservation details')),
      body: Column(
        children: [
          _HeaderSection(
            booking: booking,
            dateRange: dateRange,
            nights: _nights,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Stay details'),
                  _DetailRow(label: 'Room type', value: booking.roomTypeName),
                  _DetailRow(
                    label: 'Guests',
                    value:
                        '${booking.guests} guest${booking.guests == 1 ? '' : 's'}',
                  ),
                  _DetailRow(label: 'Nights', value: '$_nights'),
                  _DetailRow(
                    label: 'Total price',
                    value:
                        '${booking.currency} ${booking.total.toStringAsFixed(2)}',
                    highlight: true,
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle('Status'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: const Text(
                          'Upcoming stay',
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.blue.withOpacity(0.08),
                        labelStyle: const TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your reservation is confirmed. You will check-in on '
                    '${_formatDate(booking.checkIn)}.',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle('Important info'),
                  const SizedBox(height: 4),
                  const Text(
                    'Check the property’s cancellation policy before cancelling. '
                    'Some stays may be non-refundable or partially refundable.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ).copyWith(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _isCancelling ? null : _onCancelPressed,
          child: _isCancelling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Cancel reservation',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCancelPressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel reservation'),
        content: const Text(
          'Are you sure you want to cancel this reservation? '
          'Refund depends on the hotel’s cancellation policy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);

    try {
      final api = context.read<RoomWiseApiClient>();
      await api.cancelReservation(
        reservationId: widget.booking.id,
        reservationPublicId: widget.booking.publicId,
      );

      if (!mounted) return;

      // Show message and return to list with "changed = true"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation has been cancelled.')),
      );

      Navigator.pop(context, true); // <--- important: signals refresh
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel reservation. ${e.toString()}'),
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

class _HeaderSection extends StatelessWidget {
  final GuestBookingListItemDto booking;
  final String dateRange;
  final int nights;

  const _HeaderSection({
    required this.booking,
    required this.dateRange,
    required this.nights,
  });

  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: booking.thumbnailUrl == null || booking.thumbnailUrl!.isEmpty
              ? Container(color: Colors.grey.shade200)
              : Image.network(booking.thumbnailUrl!, fit: BoxFit.cover),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(top: 10, bottom: 8),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.hotelName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    booking.city,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    dateRange,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 6),
                  Text(
                    '$nights night${nights == 1 ? '' : 's'} · '
                    '${booking.guests} guest${booking.guests == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${booking.currency} ${booking.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _accentOrange,
                ),
              ),
            ],
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
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
      color: highlight ? Colors.black : Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
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
