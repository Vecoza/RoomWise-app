import 'package:flutter/material.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';

class GuestBookingCancelledScreen extends StatelessWidget {
  final GuestBookingListItemDto booking;

  const GuestBookingCancelledScreen({super.key, required this.booking});

  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);

  int get _nights =>
      booking.checkOut.difference(booking.checkIn).inDays.clamp(1, 365);

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${_formatDate(booking.checkIn)} - ${_formatDate(booking.checkOut)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Cancelled reservation')),
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
                  _SectionTitle('Reservation summary'),
                  _DetailRow(label: 'Room type', value: booking.roomTypeName),
                  _DetailRow(
                    label: 'Guests',
                    value:
                        '${booking.guests} guest${booking.guests == 1 ? '' : 's'}',
                  ),
                  _DetailRow(label: 'Nights', value: '$_nights'),
                  _DetailRow(
                    label: 'Original total',
                    value:
                        '${booking.currency} ${booking.total.toStringAsFixed(2)}',
                    highlight: true,
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle('Status'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: const Text(
                          'Cancelled',
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.redAccent.withOpacity(0.08),
                        labelStyle: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This reservation was cancelled. Refunds or charges depend on '
                    'the property’s cancellation policy.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          // Bottom – Book again
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ).copyWith(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryGreen,
                  side: const BorderSide(color: _primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  // TODO: možda navigacija nazad na hotel preview za ponovno bookiranje
                  Navigator.pop(context);
                },
                child: const Text(
                  'Search this hotel again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

// možeš kopirati iste helper klase iz prethodnog file-a
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
