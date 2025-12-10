// lib/features/booking/presentation/screens/guest_bookings_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';
import 'package:roomwise/core/models/review_dto.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_register_screen.dart';
import 'package:roomwise/features/booking/presentation/screens/guest_booking_cancelled_screen.dart';
import 'package:roomwise/features/booking/presentation/screens/guest_booking_current_screen.dart';
import 'package:roomwise/features/booking/presentation/screens/guest_booking_past_screen.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_login_screen.dart';
// TODO: import your detail screens when we create them
// import 'guest_booking_current_screen.dart';
// import 'guest_booking_past_screen.dart';
// import 'guest_booking_cancelled_screen.dart';

class GuestBookingsScreen extends StatefulWidget {
  const GuestBookingsScreen({super.key});

  @override
  State<GuestBookingsScreen> createState() => _GuestBookingsScreenState();
}

class _GuestBookingsScreenState extends State<GuestBookingsScreen>
    with SingleTickerProviderStateMixin {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);

  late final TabController _tabController;

  bool _loading = true;
  String? _error;

  List<GuestBookingListItemDto> _current = [];
  List<GuestBookingListItemDto> _past = [];
  List<GuestBookingListItemDto> _cancelled = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthState>();

    if (!auth.isLoggedIn) {
      // no bookings if not logged in
      setState(() {
        _loading = false;
        _error = null;
        _current = [];
        _past = [];
        _cancelled = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();

      final results = await Future.wait([
        api.getMyBookings(status: 'Current'),
        api.getMyBookings(status: 'Past'),
        api.getMyBookings(status: 'Cancelled'),
      ]);

      if (!mounted) return;
      setState(() {
        _current = results[0];
        _past = results[1];
        _cancelled = results[2];
        _loading = false;
      });
    } on DioException catch (e) {
      debugPrint('Load bookings failed: $e');
      if (!mounted) return;

      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await context.read<AuthState>().logout();
        setState(() {
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load your bookings.';
        });
      }
    } catch (e) {
      debugPrint('Load bookings failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load your bookings.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    // NOT LOGGED IN → show CTA (pattern like wishlist)
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bookings')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text(
                'Track your stays in one place',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create an account or log in to see your bookings, past stays and cancellations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GuestRegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('Create account'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
                  );
                  await _loadAll();
                },
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      );
    }

    // LOGGED IN → show tabs
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryGreen,
          tabs: const [
            Tab(text: 'Current'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadAll, child: const Text('Retry')),
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _BookingsList(
                    bookings: _current,
                    emptyIcon: Icons.hourglass_empty,
                    emptyTitle: 'No upcoming stays',
                    emptySubtitle:
                        'When you book a stay, you will see it here.',
                    onReload: _loadAll,
                    type: BookingType.current,
                  ),
                  _BookingsList(
                    bookings: _past,
                    emptyIcon: Icons.history,
                    emptyTitle: 'No past stays',
                    emptySubtitle:
                        'After your trips finish, you will see them here.',
                    onReload: _loadAll,
                    type: BookingType.past,
                  ),
                  _BookingsList(
                    bookings: _cancelled,
                    emptyIcon: Icons.cancel_outlined,
                    emptyTitle: 'No cancelled stays',
                    emptySubtitle: 'Cancelled reservations will appear here.',
                    onReload: _loadAll,
                    type: BookingType.cancelled,
                  ),
                ],
              ),
      ),
    );
  }
}

enum BookingType { current, past, cancelled }

class _BookingsList extends StatelessWidget {
  final List<GuestBookingListItemDto> bookings;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onReload;
  final BookingType type;

  const _BookingsList({
    required this.bookings,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onReload,
    required this.type,
  });

  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(emptyIcon, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  emptyTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    emptySubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final b = bookings[index];
        return _BookingCard(
          booking: b,
          type: type,
          onChanged: () {
            onReload();
          },
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final GuestBookingListItemDto booking;
  final BookingType type;
  final VoidCallback? onChanged;

  const _BookingCard({
    required this.booking,
    required this.type,
    this.onChanged,
  });

  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${_formatDate(booking.checkIn)} - ${_formatDate(booking.checkOut)}';

    final statusLabel = switch (type) {
      BookingType.current => 'Upcoming',
      BookingType.past => 'Completed',
      BookingType.cancelled => 'Cancelled',
    };

    final statusColor = switch (type) {
      BookingType.current => Colors.blue,
      BookingType.past => Colors.green,
      BookingType.cancelled => Colors.redAccent,
    };

    return InkWell(
      onTap: () async {
        final result = await _openDetails(context);
        if (result == true && onChanged != null) {
          onChanged!();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child:
                    booking.thumbnailUrl == null ||
                        booking.thumbnailUrl!.isEmpty
                    ? Container(color: Colors.grey.shade200)
                    : Image.network(booking.thumbnailUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hotel name
                    Text(
                      booking.hotelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // City
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            booking.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Date + guests
                    Text(
                      '$dateRange · ${booking.guests} guest${booking.guests == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Room + price + status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            booking.roomTypeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${booking.currency} ${booking.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _accentOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    if (type == BookingType.past && !booking.hasReview) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            final changed = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (_) =>
                                  _LeaveReviewSheet(booking: booking),
                            );

                            if (changed == true && onChanged != null) {
                              onChanged!(); // reload bookings
                            }
                          },
                          child: const Text(
                            'Leave a review',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _openDetails(BuildContext context) {
    if (type == BookingType.current) {
      return Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GuestBookingCurrentScreen(booking: booking),
        ),
      );
    } else if (type == BookingType.past) {
      return Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GuestBookingPastScreen(booking: booking),
        ),
      );
    } else {
      return Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GuestBookingCancelledScreen(booking: booking),
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

class _LeaveReviewSheet extends StatefulWidget {
  final GuestBookingListItemDto booking;

  const _LeaveReviewSheet({required this.booking});

  @override
  State<_LeaveReviewSheet> createState() => _LeaveReviewSheetState();
}

class _LeaveReviewSheetState extends State<_LeaveReviewSheet> {
  static const _primaryGreen = Color(0xFF05A87A);
  final TextEditingController _commentCtrl = TextEditingController();

  int _rating = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() {
        _error = 'Please choose a rating.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      final hotelId = widget.booking.hotelId;
      if (hotelId == null) {
        setState(() {
          _error = 'Hotel information is missing for this booking.';
        });
        return;
      }

      await api.createReview(
        ReviewCreateRequestDto(
          hotelId: hotelId,
          reservationId: widget.booking.id,
          rating: _rating,
          body: _commentCtrl.text.trim().isEmpty
              ? null
              : _commentCtrl.text.trim(),
        ),
      );

      if (!mounted) return;

      Navigator.pop(context, true); // tell caller that something changed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted. Thank you!')),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg;

      if (data is Map<String, dynamic>) {
        msg = data['message']?.toString() ??
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
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      child: Column(
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
            'Rate your stay at ${widget.booking.hotelName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isFilled = starIndex <= _rating;
              return IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isFilled ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 28,
                ),
                onPressed: () {
                  setState(() {
                    _rating = starIndex;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Tell us more (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Submit review',
                      style: TextStyle(
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
}
