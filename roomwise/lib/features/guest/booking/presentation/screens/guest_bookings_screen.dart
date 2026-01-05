import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';
import 'package:roomwise/core/models/review_dto.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_register_screen.dart';
import 'package:roomwise/features/guest/booking/presentation/screens/guest_booking_cancelled_screen.dart';
import 'package:roomwise/features/guest/booking/presentation/screens/guest_booking_current_screen.dart';
import 'package:roomwise/features/guest/booking/presentation/screens/guest_booking_past_screen.dart';
import 'package:roomwise/features/guest/booking/sync/bookings_sync.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestBookingsScreen extends StatefulWidget {
  const GuestBookingsScreen({super.key});

  @override
  State<GuestBookingsScreen> createState() => _GuestBookingsScreenState();
}

class _GuestBookingsScreenState extends State<GuestBookingsScreen>
    with SingleTickerProviderStateMixin {
  int _lastSyncVersion = 0;

  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _cardBg = Colors.white;
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  late final TabController _tabController;
  int _selectedTabIndex = 0;

  bool _loading = true;
  String? _error;
  bool _hasLoadedOnce = false;

  List<GuestBookingListItemDto> _current = [];
  List<GuestBookingListItemDto> _past = [];
  List<GuestBookingListItemDto> _cancelled = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final sync = context.watch<BookingsSync>();
    if (sync.version != _lastSyncVersion) {
      _lastSyncVersion = sync.version;
      _loadAll();
    }

    final auth = context.watch<AuthState>();
    if (auth.isLoggedIn && !_hasLoadedOnce) {
      _loadAll();
    } else if (!auth.isLoggedIn) {
      setState(() {
        _loading = false;
        _error = null;
        _current = [];
        _past = [];
        _cancelled = [];
        _hasLoadedOnce = false;
      });
    }
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthState>();

    if (!auth.isLoggedIn) {
      setState(() {
        _loading = false;
        _error = null;
        _current = [];
        _past = [];
        _cancelled = [];
        _hasLoadedOnce = false;
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
        _hasLoadedOnce = true;
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
          _error = AppLocalizations.of(context)!.bookingsLoadFailed;
        });
      }
    } catch (e) {
      debugPrint('Load bookings failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.bookingsLoadFailed;
      });
    }
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestLoginScreen(
          onLoginSuccess: () async {
            await _loadAll();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final t = AppLocalizations.of(context)!;

    final currentCount = _current.length;
    final pastCount = _past.length;
    final cancelledCount = _cancelled.length;
    final totalCount = currentCount + pastCount + cancelledCount;

    // NOT LOGGED IN
    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: Text(t.navBookings),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFEFFDF8)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 32,
                          color: _primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        t.bookingsLoggedOutTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t.bookingsLoggedOutSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GuestRegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            t.createAccount,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _openLogin,
                        child: Text(
                          t.alreadyAccount,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // LOGGED IN
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.bookingsTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              totalCount == 0 ? t.bookingsNoStays : t.bookingsTotal(totalCount),
              style: const TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _SummaryChip(
                      label: t.bookingsTabCurrent,
                      value: currentCount.toString(),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: t.bookingsTabPast,
                      value: pastCount.toString(),
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: t.bookingsTabCancelled,
                      value: cancelledCount.toString(),
                      color: Colors.redAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _SegmentTab(
                        label: t.bookingsTabCurrent,
                        selected: _selectedTabIndex == 0,
                        onTap: () => _tabController.animateTo(0),
                      ),
                      _SegmentTab(
                        label: t.bookingsTabPast,
                        selected: _selectedTabIndex == 1,
                        onTap: () => _tabController.animateTo(1),
                      ),
                      _SegmentTab(
                        label: t.bookingsTabCancelled,
                        selected: _selectedTabIndex == 2,
                        onTap: () => _tabController.animateTo(2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 56,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _loadAll, child: Text(t.retry)),
                        ],
                      ),
                    ),
                  ],
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    // subtle slide + fade
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0.03, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_selectedTabIndex),
                    child: _buildTabBody(),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    final t = AppLocalizations.of(context)!;
    switch (_selectedTabIndex) {
      case 0:
        return _BookingsList(
          bookings: _current,
          emptyIcon: Icons.hourglass_empty,
          emptyTitle: t.bookingsEmptyCurrentTitle,
          emptySubtitle: t.bookingsEmptyCurrentSubtitle,
          onReload: _loadAll,
          type: BookingType.current,
        );
      case 1:
        return _BookingsList(
          bookings: _past,
          emptyIcon: Icons.history,
          emptyTitle: t.bookingsEmptyPastTitle,
          emptySubtitle: t.bookingsEmptyPastSubtitle,
          onReload: _loadAll,
          type: BookingType.past,
        );
      case 2:
      default:
        return _BookingsList(
          bookings: _cancelled,
          emptyIcon: Icons.cancel_outlined,
          emptyTitle: t.bookingsEmptyCancelledTitle,
          emptySubtitle: t.bookingsEmptyCancelledSubtitle,
          onReload: _loadAll,
          type: BookingType.cancelled,
        );
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _primaryGreen = Color(0xFF05A87A);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? _primaryGreen.withOpacity(0.14) : Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _primaryGreen : _textMuted,
              ),
              child: Text(label),
            ),
          ),
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

  static const _textMuted = Color(0xFF6B7280);
  static const _textPrimary = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _textMuted.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(emptyIcon, size: 28, color: _textMuted),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    emptyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    emptySubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.separated(
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
        ),
      ),
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
  static const _textMuted = Color(0xFF6B7280);
  static const _textPrimary = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final dateRange =
        '${_formatDate(booking.checkIn)} – ${_formatDate(booking.checkOut)}';

    final statusLabel = switch (type) {
      BookingType.current => t.bookingsStatusUpcoming,
      BookingType.past => t.bookingsStatusCompleted,
      BookingType.cancelled => t.bookingsStatusCancelled,
    };

    final statusColor = switch (type) {
      BookingType.current => const Color(0xFF2563EB),
      BookingType.past => const Color(0xFF059669),
      BookingType.cancelled => Colors.redAccent,
    };

    final nights = booking.checkOut.difference(booking.checkIn).inDays;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image + status chip
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child:
                          booking.thumbnailUrl == null ||
                              booking.thumbnailUrl!.isEmpty
                          ? Container(color: Colors.grey.shade200)
                          : Image.network(
                              booking.thumbnailUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
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
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                      ],
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
                        const Icon(
                          Icons.date_range,
                          size: 16,
                          color: _textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$dateRange · $nights ${t.nightsLabel(nights)}',
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
                          '${booking.guests} ${t.guestsLabel(booking.guests)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            booking.roomTypeName,
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${booking.currency} ${booking.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _accentOrange,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.bookingsTotalPrice,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (type == BookingType.past && !booking.hasReview)
                          TextButton(
                            onPressed: () async {
                              final changed = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                ),
                                builder: (_) =>
                                    _LeaveReviewSheet(booking: booking),
                              );

                              if (changed == true && onChanged != null) {
                                onChanged!();
                              }
                            },
                            child: Text(
                              t.bookingsLeaveReview,
                              style: const TextStyle(fontSize: 12),
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
  static const _textMuted = Color(0xFF6B7280);
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
    final t = AppLocalizations.of(context)!;
    if (_rating == 0) {
      setState(() {
        _error = t.reviewRatingRequired;
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
          _error = t.reviewMissingHotel;
          _submitting = false;
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

      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.reviewSubmitted)));
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
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              t.reviewTitle(widget.booking.hotelName),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              t.reviewSubtitle,
              style: const TextStyle(fontSize: 12, color: _textMuted),
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
                    size: 30,
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
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
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
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        t.reviewSubmit,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
