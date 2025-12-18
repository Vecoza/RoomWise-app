import 'package:flutter/material.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestBookingPastScreen extends StatelessWidget {
  final GuestBookingListItemDto booking;

  const GuestBookingPastScreen({super.key, required this.booking});

  // Design tokens
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  int get _nights =>
      booking.checkOut.difference(booking.checkIn).inDays.clamp(1, 365);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final dateRange =
        '${_formatDate(booking.checkIn)} – ${_formatDate(booking.checkOut)}';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgColor,
        centerTitle: false,
        title: Text(
          t.bookingPastTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HERO IMAGE + FLOATING CARD
                      _HeaderSection(
                        booking: booking,
                        dateRange: dateRange,
                        nights: _nights,
                      ),
                      const SizedBox(height: 36),

                      // STAY SUMMARY CARD
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
                            _SectionTitle(t.bookingPastStaySummary),
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
                              label: t.bookingPastTotalPaid,
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
                                      0xFF059669,
                                    ).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Color(0xFF059669),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        t.bookingPastStatusCompleted,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t.bookingPastMessage,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // LITTLE FOOTER TEXT
                      Text(
                        t.bookingPastTip,
                        style: const TextStyle(fontSize: 12, color: _textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // (Optional) still here if you ever want to trigger a review from this screen.
  void _openReviewBottomSheet(
    BuildContext context,
    GuestBookingListItemDto booking,
  ) {
    final t = AppLocalizations.of(context)!;
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
                  Text(
                    t.reviewYourStay,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
                    decoration: InputDecoration(
                      labelText: t.reviewCommentLabel,
                      border: const OutlineInputBorder(),
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
                        // TODO: wire review API if you want from here
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t.reviewSubmitted),
                          ),
                        );
                      },
                      child: Text(t.reviewSubmit),
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

/// HEADER (image + floating card)
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
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final image = booking.thumbnailUrl;
    final hasImage = image != null && image.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // HERO
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: hasImage
                ? Image.network(image!, fit: BoxFit.cover)
                : Container(color: Colors.grey.shade300),
          ),
        ),

        // GRADIENT OVERLAY + STATUS CHIP
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.08),
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
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                SizedBox(width: 6),
                Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ),

        // FLOATING INFO CARD
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
                  // Hotel name + city
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
                  // Dates + guests
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
