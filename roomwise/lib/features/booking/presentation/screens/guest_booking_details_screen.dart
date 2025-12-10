import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/core/models/review_dto.dart';

class GuestBookingDetailsScreen extends StatefulWidget {
  final ReservationDto reservation;

  const GuestBookingDetailsScreen({super.key, required this.reservation});

  @override
  State<GuestBookingDetailsScreen> createState() =>
      _GuestBookingDetailsScreenState();
}

class _GuestBookingDetailsScreenState extends State<GuestBookingDetailsScreen> {
  bool _submittingReview = false;
  String? _error;

  bool get _isPast {
    final now = DateTime.now();
    return widget.reservation.checkOut.isBefore(now);
  }

  bool get _isCancelled =>
      widget.reservation.status.toLowerCase() == 'cancelled';

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;

    final dates = '${_fmt(r.checkIn)} – ${_fmt(r.checkOut)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.hotelName ?? 'Hotel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              r.hotelCity ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(dates, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Guests: ${r.guests}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'Total: ${r.currency} ${r.total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (r.confirmationNumber != null)
              Text(
                'Confirmation: ${r.confirmationNumber}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            _StatusChip(status: r.status),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],

            const Spacer(),

            if (_isPast && !_isCancelled)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submittingReview ? null : _openReviewDialog,
                  child: _submittingReview
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Leave a review'),
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
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
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
                      final selected = star <= rating;
                      return IconButton(
                        onPressed: () {
                          setModalState(() => rating = star);
                        },
                        icon: Icon(
                          Icons.star,
                          color: selected ? Colors.amber : Colors.grey.shade400,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Share your experience',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _submitReview(rating, controller.text.trim());
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

  Future<void> _submitReview(int rating, String comment) async {
    setState(() {
      _submittingReview = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      await api.createReview(
        ReviewCreateRequestDto(
          hotelId: widget.reservation.hotelId!, // must come from backend
          reservationId: widget.reservation.id,
          rating: rating,
          body: comment.isEmpty ? null : comment,
        ),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted. Thank you!')),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg;

      if (data is Map<String, dynamic>) {
        msg =
            data['message']?.toString() ??
            data['error']?.toString() ??
            e.message ??
            'Failed to submit review. Please try again.';
      } else if (data is String) {
        msg = data;
      } else {
        msg = e.message ?? 'Failed to submit review. Please try again.';
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
        _error = 'Failed to submit review. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submittingReview = false;
        });
      }
    }
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'cancelled':
        color = Colors.redAccent;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
