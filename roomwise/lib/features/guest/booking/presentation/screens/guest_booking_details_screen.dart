import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/core/models/review_dto.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestBookingDetailsScreen extends StatefulWidget {
  final ReservationDto reservation;

  const GuestBookingDetailsScreen({super.key, required this.reservation});

  @override
  State<GuestBookingDetailsScreen> createState() =>
      _GuestBookingDetailsScreenState();
}

class _GuestBookingDetailsScreenState extends State<GuestBookingDetailsScreen> {
  // Design tokens
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _submittingReview = false;
  String? _error;

  bool get _isPast {
    final now = DateTime.now();
    return widget.reservation.checkOut.isBefore(now);
  }

  bool get _isCancelled =>
      widget.reservation.status.toLowerCase() == 'cancelled';

  int get _nights => widget.reservation.checkOut
      .difference(widget.reservation.checkIn)
      .inDays
      .clamp(1, 365);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final r = widget.reservation;
    final dates = '${_formatDate(r.checkIn)} – ${_formatDate(r.checkOut)}';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER CARD
                        _HeaderCard(
                          reservation: r,
                          dates: dates,
                          nights: _nights,
                          isCancelled: _isCancelled,
                        ),
                        const SizedBox(height: 24),

                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],

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
                              _SectionTitle(t.bookingDetailsReservation),
                              const SizedBox(height: 8),
                              _DetailRow(
                                label: t.bookingDetailsGuests,
                                value: '${r.guests} ${t.guestsLabel(r.guests)}',
                              ),
                              _DetailRow(
                                label: t.bookingDetailsNights,
                                value: '$_nights',
                              ),
                              if (r.roomTypeName != null &&
                                  r.roomTypeName!.isNotEmpty)
                                _DetailRow(
                                  label: t.bookingDetailsRoomType,
                                  value: r.roomTypeName!,
                                ),
                              _DetailRow(
                                label: t.bookingDetailsTotal,
                                value:
                                    '${r.currency} ${r.total.toStringAsFixed(2)}',
                                highlight: true,
                              ),
                              if (r.confirmationNumber != null) ...[
                                const SizedBox(height: 12),
                                _SectionTitle(t.bookingDetailsReference),
                                const SizedBox(height: 4),
                                Text(
                                  r.confirmationNumber!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.bookingDetailsReferenceHint,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // BOTTOM: REVIEW BUTTON (only for completed, not cancelled)
            if (_isPast && !_isCancelled)
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
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _submittingReview ? null : _openReviewDialog,
                      child: _submittingReview
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              t.bookingsLeaveReview,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openReviewDialog() {
    int rating = 5;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final t = AppLocalizations.of(context)!;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset + 16,
          ),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      t.reviewTitle(
                        widget.reservation.hotelName ?? 'this property',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.reviewSubtitle,
                      style: const TextStyle(fontSize: 12, color: _textMuted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        final selected = star <= rating;
                        return IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setModalState(() => rating = star);
                          },
                          icon: Icon(
                            selected ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 30,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: t.reviewCommentLabel,
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _submitReview(rating, controller.text.trim());
                        },
                        child: Text(
                          t.reviewSubmit,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
      },
    );
  }

  Future<void> _submitReview(int rating, String comment) async {
    final t = AppLocalizations.of(context)!;
    setState(() {
      _submittingReview = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      await api.createReview(
        ReviewCreateRequestDto(
          hotelId: widget.reservation.hotelId!, // should be present from API
          reservationId: widget.reservation.id,
          rating: rating,
          body: comment.isEmpty ? null : comment,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.reviewSubmitted)),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg;

      if (data is Map<String, dynamic>) {
        msg =
            data['message']?.toString() ??
            data['error']?.toString() ??
            e.message ??
            t.reviewSubmitFailed;
      } else if (data is String) {
        msg = data;
      } else {
        msg = e.message ?? t.reviewSubmitFailed;
      }

      debugPrint(
        'Review submit error: status=${e.response?.statusCode}, data=${e.response?.data}',
      );

      if (!mounted) return;
      setState(() {
        _error = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t.reviewSubmitFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submittingReview = false;
        });
      }
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

class _HeaderCard extends StatelessWidget {
  final ReservationDto reservation;
  final String dates;
  final int nights;
  final bool isCancelled;

  const _HeaderCard({
    required this.reservation,
    required this.dates,
    required this.nights,
    required this.isCancelled,
  });

  static const _accentOrange = Color(0xFFFF7A3C);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(reservation.status);
    final statusLabel = reservation.status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hotel + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  reservation.hotelName ?? 'Hotel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _statusIcon(reservation.status),
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
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
            ],
          ),
          const SizedBox(height: 4),
          if (reservation.hotelCity != null &&
              reservation.hotelCity!.isNotEmpty)
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
                    reservation.hotelCity!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.date_range, size: 16, color: _textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$dates · $nights night${nights == 1 ? '' : 's'}',
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
              const Icon(Icons.person_outline, size: 16, color: _textMuted),
              const SizedBox(width: 6),
              Text(
                '${reservation.guests} guest${reservation.guests == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: _textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${reservation.currency} ${reservation.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
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
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
        return Colors.redAccent;
      case 'completed':
      case 'past':
        return const Color(0xFF059669);
      case 'current':
      case 'upcoming':
        return const Color(0xFF2563EB);
      default:
        return _textMuted;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'completed':
      case 'past':
        return Icons.check_circle_outline;
      default:
        return Icons.schedule_outlined;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  static const _textPrimary = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
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
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
