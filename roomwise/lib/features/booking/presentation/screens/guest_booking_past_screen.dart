import 'package:flutter/material.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';

class GuestBookingPastScreen extends StatelessWidget {
  final GuestBookingListItemDto booking;

  const GuestBookingPastScreen({super.key, required this.booking});

  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);

  int get _nights =>
      booking.checkOut.difference(booking.checkIn).inDays.clamp(1, 365);

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${_formatDate(booking.checkIn)} - ${_formatDate(booking.checkOut)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Past stay details')),
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
                  _SectionTitle('Stay summary'),
                  _DetailRow(label: 'Room type', value: booking.roomTypeName),
                  _DetailRow(
                    label: 'Guests',
                    value:
                        '${booking.guests} guest${booking.guests == 1 ? '' : 's'}',
                  ),
                  _DetailRow(label: 'Nights', value: '$_nights'),
                  _DetailRow(
                    label: 'Total paid',
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
                          'Completed stay',
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.green.withOpacity(0.08),
                        labelStyle: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We hope you enjoyed your stay. Share your experience to help '
                    'other guests and the property.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          // Bottom review button removed (reviews initiated from booking cards).
        ],
      ),
    );
  }

  void _openReviewBottomSheet(
    BuildContext context,
    GuestBookingListItemDto booking,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        int selectedRating = 5;
        final controller = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rate your stay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      final filled = star <= selectedRating;
                      return IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() => selectedRating = star);
                        },
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: filled ? Colors.amber : Colors.grey,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Tell us more about your experience',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        // TODO: pozvati backend /reviews za ovu rezervaciju
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Review submitted (TODO wire API).'),
                          ),
                        );
                      },
                      child: const Text('Submit review'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
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

// Reuse header / section / detail rows – možeš ih izvući u zajednički file
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
