import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/admin_reservation_dto.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() =>
      _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  static const _textMuted = Color(0xFF6B7280);
  static const _primaryGreen = Color(0xFF05A87A);
  static const _danger = Color(0xFFEF4444);

  final _dateFmt = DateFormat('dd MMM yyyy');
  final NumberFormat _compact = NumberFormat.compact();

  bool _loading = true;
  String? _error;
  String _statusFilter = 'All';
  DateTime? _from;
  DateTime? _to;
  String _sort = 'Newest';
  List<AdminReservationDto> _items = const [];

  final List<String> _statuses = const [
    'All',
    'Pending',
    'Confirmed',
    'CheckedIn',
    'CheckedOut',
    'Completed',
    'Cancelled',
  ];
  final List<String> _sortOptions = const [
    'Newest',
    'Oldest',
    'Total high → low',
    'Total low → high',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = context.read<RoomWiseApiClient>();
    try {
      final items = await api.getAdminReservations(
        status: _statusFilter == 'All' ? null : _statusFilter,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await context.read<AuthState>().logout();
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = code == 401 || code == 403
            ? 'Not authorized. Please log in again.'
            : 'Failed to load reservations.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load reservations.';
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (res != null) {
      setState(() {
        _from = res.start;
        _to = res.end;
      });
      _load();
    }
  }

  bool _canCancel(AdminReservationDto r) {
    final s = r.status
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .trim();
    return s != 'completed' && s != 'cancelled' && s != 'checkedout';
  }

  String _humanizeStatus(String s) {
    var out = s.trim();
    out = out.replaceAll('-', ' ').replaceAll('_', ' ');
    out = out.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}');
    final parts = out
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .toList();
    return parts.isEmpty ? s : parts.join(' ');
  }

  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      default:
        return code;
    }
  }

  String _amount(double v) {
    final abs = v.abs();
    if ((abs - abs.roundToDouble()).abs() < 0.000001) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2);
  }

  Future<void> _cancelFromSheet({
    required BuildContext sheetContext,
    required AdminReservationDto reservation,
    required void Function(bool) setBusy,
  }) async {
    if (!_canCancel(reservation)) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(
            'This reservation can’t be cancelled (${_humanizeStatus(reservation.status)}).',
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: sheetContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation'),
        content: Text(
          'Are you sure you want to cancel ${reservation.confirmationNumber ?? reservation.publicId}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setBusy(true);
    try {
      await context.read<RoomWiseApiClient>().cancelAdminReservation(
        reservation.id,
      );
      await _load();
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reservation cancelled.')));
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        if (!mounted) return;
        await context.read<AuthState>().logout();
      }
      if (!sheetContext.mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(
            code == 401 || code == 403
                ? 'Not authorized. Please log in again.'
                : 'Cancel failed: ${e.response?.statusCode}',
          ),
        ),
      );
    } catch (e) {
      if (!sheetContext.mounted) return;
      ScaffoldMessenger.of(
        sheetContext,
      ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    } finally {
      setBusy(false);
    }
  }

  void _showDetails(AdminReservationDto r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            void setBusy(bool v) => setModalState(() => busy = v);

            return _ReservationDetailsSheet(
              reservation: r,
              dateFmt: _dateFmt,
              statusColor: _statusColor(r.status),
              statusLabel: _humanizeStatus(r.status),
              currencySymbol: _currencySymbol(r.currency),
              amount: _amount,
              canCancel: _canCancel(r),
              busy: busy,
              onClose: () => Navigator.of(context).pop(),
              onCancel: busy
                  ? null
                  : () => _cancelFromSheet(
                      sheetContext: context,
                      reservation: r,
                      setBusy: setBusy,
                    ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _loading
          ? const _ReservationsSkeleton(key: ValueKey('loading'))
          : _error != null
          ? _ErrorCard(
              key: const ValueKey('error'),
              message: _error!,
              onRetry: _load,
            )
          : _ReservationsBody(
              key: const ValueKey('body'),
              items: _items,
              statuses: _statuses,
              status: _statusFilter,
              from: _from,
              to: _to,
              sort: _sort,
              sortOptions: _sortOptions,
              compact: _compact,
              onStatusChanged: (v) {
                setState(() => _statusFilter = v);
                _load();
              },
              onSortChanged: (v) => setState(() => _sort = v),
              onPickDates: _pickDateRange,
              onClearDates: () {
                setState(() {
                  _from = null;
                  _to = null;
                });
                _load();
              },
              onOpenDetails: _showDetails,
              sortedItems: _sortedItems,
            ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReservationsHeroHeader(
            title: 'Reservations',
            subtitle: 'Filter, inspect, and manage bookings.',
            loading: _loading,
            onRefresh: _load,
            activeStatus: _statusFilter,
            from: _from,
            to: _to,
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  List<AdminReservationDto> _sortedItems() {
    final list = List<AdminReservationDto>.from(_items);
    switch (_sort) {
      case 'Oldest':
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Total high → low':
        list.sort((a, b) => b.total.compareTo(a.total));
        break;
      case 'Total low → high':
        list.sort((a, b) => a.total.compareTo(b.total));
        break;
      case 'Newest':
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return _primaryGreen;
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return _danger;
      case 'checkedin':
      case 'checked-in':
        return const Color(0xFF2563EB);
      case 'completed':
      case 'checkedout':
      case 'checked-out':
        return const Color(0xFF10B981);
      default:
        return _textMuted;
    }
  }
}

class _ReservationsHeroHeader extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onRefresh;
  final String activeStatus;
  final DateTime? from;
  final DateTime? to;

  const _ReservationsHeroHeader({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onRefresh,
    required this.activeStatus,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = (from != null && to != null)
        ? '${DateFormat('dd MMM').format(from!)} - ${DateFormat('dd MMM yyyy').format(to!)}'
        : 'Any dates';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8ECFF), Color(0xFFEFFBF6)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SoftCirclesPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: _textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: _textMuted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(label: 'Status: $activeStatus'),
                  _Pill(label: dateText),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading
                    ? const LinearProgressIndicator(
                        key: ValueKey('progress'),
                        minHeight: 3,
                      )
                    : const SizedBox(key: ValueKey('no-progress'), height: 3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: _textPrimary,
        ),
      ),
    );
  }
}

class _SoftCirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF3B82F6).withOpacity(0.10);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.25), 70, paint);

    paint.color = const Color(0xFF05A87A).withOpacity(0.10);
    canvas.drawCircle(Offset(size.width * 0.20, size.height * 0.05), 55, paint);

    paint.color = Colors.white.withOpacity(0.35);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.95), 90, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReservationDetailsSheet extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final AdminReservationDto reservation;
  final DateFormat dateFmt;
  final Color statusColor;
  final String statusLabel;
  final String currencySymbol;
  final String Function(double) amount;
  final bool canCancel;
  final bool busy;
  final VoidCallback onClose;
  final VoidCallback? onCancel;

  const _ReservationDetailsSheet({
    required this.reservation,
    required this.dateFmt,
    required this.statusColor,
    required this.statusLabel,
    required this.currencySymbol,
    required this.amount,
    required this.canCancel,
    required this.busy,
    required this.onClose,
    required this.onCancel,
  });

  String _currencySymbolFor(String code) {
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nights = reservation.checkOut.difference(reservation.checkIn).inDays;
    final paidRatio = reservation.total <= 0
        ? 0.0
        : (reservation.amountPaid / reservation.total).clamp(0.0, 1.0);
    final isPaid = paidRatio >= 0.999;
    final totalAddons = reservation.addOns.fold<double>(
      0,
      (p, a) => p + a.price,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Material(
            color: const Color(0xFFF8FAFC),
            child: CustomScrollView(
              controller: controller,
              slivers: [
                SliverToBoxAdapter(
                  child: _SheetHeader(
                    title:
                        reservation.confirmationNumber ?? reservation.publicId,
                    subtitle:
                        '${dateFmt.format(reservation.checkIn)} → ${dateFmt.format(reservation.checkOut)}',
                    statusColor: statusColor,
                    statusLabel: statusLabel,
                    onClose: onClose,
                    busy: busy,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        final cols = w >= 720 ? 4 : 2;
                        final tileW = (w - (cols - 1) * 10) / cols;

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: tileW,
                              child: _MetricTile(
                                icon: Icons.groups_outlined,
                                label: 'Guests',
                                value: reservation.guests.toString(),
                              ),
                            ),
                            SizedBox(
                              width: tileW,
                              child: _MetricTile(
                                icon: Icons.bedtime_outlined,
                                label: 'Nights',
                                value: nights.toString(),
                              ),
                            ),
                            SizedBox(
                              width: tileW,
                              child: _MetricTile(
                                icon: Icons.payments_outlined,
                                label: 'Total',
                                value:
                                    '$currencySymbol ${amount(reservation.total)}',
                              ),
                            ),
                            SizedBox(
                              width: tileW,
                              child: _MetricTile(
                                icon: Icons.verified_outlined,
                                label: 'Paid',
                                value:
                                    '$currencySymbol ${amount(reservation.amountPaid)}',
                                valueColor: isPaid
                                    ? const Color(0xFF05A87A)
                                    : _textPrimary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            title: 'Payment',
                            subtitle: isPaid
                                ? 'Paid in full'
                                : 'Outstanding: $currencySymbol ${amount(reservation.total - reservation.amountPaid)}',
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: paidRatio),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) {
                                return LinearProgressIndicator(
                                  value: v,
                                  minHeight: 8,
                                  backgroundColor: Colors.black.withOpacity(
                                    0.06,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    statusColor,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    color: _textMuted.withOpacity(0.95),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '$currencySymbol ${amount(reservation.total)}',
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Paid',
                                  style: TextStyle(
                                    color: _textMuted.withOpacity(0.95),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '$currencySymbol ${amount(reservation.amountPaid)}',
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            title: 'Add-ons',
                            subtitle: reservation.addOns.isEmpty
                                ? 'None'
                                : '${reservation.addOns.length} item${reservation.addOns.length == 1 ? '' : 's'} • $currencySymbol ${amount(totalAddons)}',
                          ),
                          const SizedBox(height: 10),
                          if (reservation.addOns.isEmpty)
                            Text(
                              'No add-ons for this reservation.',
                              style: TextStyle(
                                color: _textMuted.withOpacity(0.95),
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (final a in reservation.addOns) ...[
                                  _AddonRow(
                                    name: a.name,
                                    subtitle: a.pricingModel,
                                    trailing:
                                        '${_currencySymbolFor(a.currency)} ${amount(a.price)}',
                                  ),
                                  if (a != reservation.addOns.last)
                                    Divider(
                                      height: 16,
                                      color: Colors.black.withOpacity(0.06),
                                    ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Created ${dateFmt.format(reservation.createdAt)}',
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        if (!canCancel)
                          const _InfoBanner(
                            icon: Icons.lock_outline,
                            title: 'Cancellation disabled',
                            message:
                                'This reservation can’t be cancelled in its current state.',
                          ),
                        if (canCancel) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: onCancel,
                              icon: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cancel),
                              label: Text(
                                busy ? 'Cancelling…' : 'Cancel reservation',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: busy ? null : onClose,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Close'),
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
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String title;
  final String subtitle;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onClose;
  final bool busy;

  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.statusColor,
    required this.statusLabel,
    required this.onClose,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8ECFF), Color(0xFFEFFBF6)],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SoftCirclesPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: busy ? null : onClose,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.75),
                    ),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: _textMuted)),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(status: statusLabel),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor ?? _textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(
              color: _textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _AddonRow extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String name;
  final String subtitle;
  final String trailing;

  const _AddonRow({
    required this.name,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          trailing,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final IconData icon;
  final String title;
  final String message;

  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(color: _textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationsBody extends StatelessWidget {
  final List<AdminReservationDto> items;
  final List<String> statuses;
  final String status;
  final DateTime? from;
  final DateTime? to;
  final String sort;
  final List<String> sortOptions;
  final NumberFormat compact;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onPickDates;
  final VoidCallback onClearDates;
  final void Function(AdminReservationDto) onOpenDetails;
  final List<AdminReservationDto> Function() sortedItems;

  const _ReservationsBody({
    super.key,
    required this.items,
    required this.statuses,
    required this.status,
    required this.from,
    required this.to,
    required this.sort,
    required this.sortOptions,
    required this.compact,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onPickDates,
    required this.onClearDates,
    required this.onOpenDetails,
    required this.sortedItems,
  });

  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = items.length;
    final pending = items
        .where((r) => r.status.toLowerCase() == 'pending')
        .length;
    final cancelled = items
        .where((r) => r.status.toLowerCase() == 'cancelled')
        .length;
    final upcoming = items
        .where(
          (r) =>
              r.checkIn.isAfter(DateTime(now.year, now.month, now.day)) &&
              r.status.toLowerCase() != 'cancelled',
        )
        .length;

    final currencies = items.map((e) => e.currency).toSet();
    final currency = currencies.length == 1 ? currencies.first : null;
    final sumTotal = items.fold<double>(0, (p, r) => p + r.total);
    final sumText = currency == null
        ? 'Mixed'
        : '${_currencySymbol(currency)} ${compact.format(sumTotal)}';

    final list = sortedItems();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w >= 980 ? 4 : (w >= 640 ? 2 : 1);
            final tileW = (w - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.receipt_long,
                    label: 'Total',
                    accent: const Color(0xFF3B82F6),
                    value: _CountUpText.int(value: total),
                    hint: sumText,
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.timelapse,
                    label: 'Pending',
                    accent: const Color(0xFFF59E0B),
                    value: _CountUpText.int(value: pending),
                    hint: 'Needs attention',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.event_available,
                    label: 'Upcoming',
                    accent: const Color(0xFF05A87A),
                    value: _CountUpText.int(value: upcoming),
                    hint: 'Future check-ins',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.cancel,
                    label: 'Cancelled',
                    accent: const Color(0xFFEF4444),
                    value: _CountUpText.int(value: cancelled),
                    hint: 'In current list',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _ReservationsFiltersCard(
          statuses: statuses,
          status: status,
          from: from,
          to: to,
          sort: sort,
          sortOptions: sortOptions,
          onStatusChanged: onStatusChanged,
          onPickDates: onPickDates,
          onClearDates: onClearDates,
          onSortChanged: onSortChanged,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: list.isEmpty
              ? const _EmptyCard(key: ValueKey('empty'))
              : ListView.separated(
                  key: const ValueKey('list'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final t = (i * 0.05).clamp(0.0, 0.35);
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(
                        milliseconds: 260 + (i * 30).clamp(0, 180),
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) {
                        final slide = (1 - v) * (12 + 10 * t);
                        return Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, slide),
                            child: child,
                          ),
                        );
                      },
                      child: _ReservationCard(
                        reservation: r,
                        onTap: () => onOpenDetails(r),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ReservationsFiltersCard extends StatelessWidget {
  final List<String> statuses;
  final String status;
  final DateTime? from;
  final DateTime? to;
  final String sort;
  final List<String> sortOptions;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onPickDates;
  final VoidCallback onClearDates;
  final ValueChanged<String> onSortChanged;

  const _ReservationsFiltersCard({
    required this.statuses,
    required this.status,
    required this.from,
    required this.to,
    required this.sort,
    required this.sortOptions,
    required this.onStatusChanged,
    required this.onPickDates,
    required this.onClearDates,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = (from != null && to != null)
        ? '${DateFormat('dd MMM').format(from!)} - ${DateFormat('dd MMM yyyy').format(to!)}'
        : 'Any dates';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = statuses[i];
                final selected = s == status;
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => onStatusChanged(s),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PillSelect<String>(
                value: sort,
                items: sortOptions,
                onChanged: onSortChanged,
                icon: Icons.sort,
              ),
              OutlinedButton.icon(
                onPressed: onPickDates,
                icon: const Icon(Icons.date_range),
                label: Text(dateText),
              ),
              if (from != null || to != null)
                TextButton.icon(
                  onPressed: onClearDates,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillSelect<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final IconData icon;

  const _PillSelect({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: Icon(icon, size: 18),
          items: items
              .map((s) => DropdownMenuItem<T>(value: s, child: Text('$s')))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _ReservationsSkeleton extends StatefulWidget {
  const _ReservationsSkeleton({super.key});

  @override
  State<_ReservationsSkeleton> createState() => _ReservationsSkeletonState();
}

class _ReservationsSkeletonState extends State<_ReservationsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final base =
            Color.lerp(Colors.grey.shade200, Colors.grey.shade100, t) ??
            Colors.grey.shade200;

        Widget box({double? width, required double height, BorderRadius? r}) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: base,
              borderRadius: r ?? BorderRadius.circular(16),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cols = w >= 980 ? 4 : (w >= 640 ? 2 : 1);
                final tileW = (w - (cols - 1) * 12) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(
                    4,
                    (i) => SizedBox(width: tileW, child: box(height: 74)),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(width: 90, height: 14, r: BorderRadius.circular(8)),
                  const SizedBox(height: 10),
                  box(height: 42),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: box(height: 102),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final IconData icon;
  final String label;
  final Widget value;
  final String? hint;
  final Color accent;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                  child: value,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _textMuted.withOpacity(0.95),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountUpText extends StatefulWidget {
  final double value;
  final String Function(double) format;

  const _CountUpText._({required this.value, required this.format});

  factory _CountUpText.int({required int value}) {
    return _CountUpText._(
      value: value.toDouble(),
      format: (v) => v.round().toString(),
    );
  }

  @override
  State<_CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<_CountUpText> {
  late double _from;

  @override
  void initState() {
    super.initState();
    _from = 0;
  }

  @override
  void didUpdateWidget(covariant _CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(widget.format(v)),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final AdminReservationDto reservation;
  final VoidCallback onTap;

  const _ReservationCard({required this.reservation, required this.onTap});

  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      default:
        return code;
    }
  }

  String _amount(double v) {
    final abs = v.abs();
    if ((abs - abs.roundToDouble()).abs() < 0.000001) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2);
  }

  String _humanizeStatus(String s) {
    var out = s.trim();
    out = out.replaceAll('-', ' ').replaceAll('_', ' ');
    out = out.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}');
    final parts = out
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .toList();
    return parts.isEmpty ? s : parts.join(' ');
  }

  ({Color color, IconData icon}) _statusVisual(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return (color: const Color(0xFF10B981), icon: Icons.verified_outlined);
      case 'pending':
        return (color: const Color(0xFFF59E0B), icon: Icons.schedule);
      case 'cancelled':
        return (color: const Color(0xFFEF4444), icon: Icons.cancel_outlined);
      case 'checkedin':
      case 'checked-in':
        return (color: const Color(0xFF2563EB), icon: Icons.hotel_outlined);
      case 'checkedout':
      case 'checked-out':
        return (color: const Color(0xFF0EA5E9), icon: Icons.logout_outlined);
      case 'completed':
        return (color: const Color(0xFF05A87A), icon: Icons.task_alt_outlined);
      default:
        return (color: const Color(0xFF6B7280), icon: Icons.info_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM');
    final visual = _statusVisual(reservation.status);
    final statusLabel = _humanizeStatus(reservation.status);
    final nights = reservation.checkOut.difference(reservation.checkIn).inDays;
    final paidRatio = reservation.total <= 0
        ? 0.0
        : (reservation.amountPaid / reservation.total).clamp(0.0, 1.0);
    final isPaid = paidRatio >= 0.999;
    final symbol = _currencySymbol(reservation.currency);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: _Card(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        visual.color.withOpacity(0.85),
                        visual.color.withOpacity(0.25),
                      ],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            visual.color.withOpacity(0.20),
                            visual.color.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: visual.color.withOpacity(0.16),
                        ),
                      ),
                      child: Icon(visual.icon, color: visual.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  reservation.confirmationNumber ??
                                      reservation.publicId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${dateFmt.format(reservation.checkIn)} → ${dateFmt.format(reservation.checkOut)}'
                            ' • $nights ${nights == 1 ? 'night' : 'nights'}'
                            ' • ${reservation.guests} ${reservation.guests == 1 ? 'guest' : 'guests'}',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                          if (reservation.addOns.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '+ ${reservation.addOns.length} add-on${reservation.addOns.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: _textMuted.withOpacity(0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusPill(status: statusLabel),
                          const SizedBox(height: 10),
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$symbol ${_amount(reservation.total)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (reservation.amountPaid > 0 && !isPaid)
                            SizedBox(
                              width: 120,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: paidRatio,
                                  minHeight: 6,
                                  backgroundColor: Colors.black.withOpacity(
                                    0.06,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    visual.color,
                                  ),
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPaid
                                      ? Icons.verified
                                      : Icons.payments_outlined,
                                  size: 14,
                                  color: isPaid
                                      ? const Color(0xFF05A87A)
                                      : _textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isPaid ? 'Paid' : 'Unpaid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isPaid
                                        ? const Color(0xFF05A87A)
                                        : _textMuted,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _textMuted.withOpacity(0.7),
                      size: 26,
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
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
        color = const Color(0xFF10B981);
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        break;
      case 'completed':
        color = const Color(0xFF05A87A);
        break;
      case 'cancelled':
        color = const Color(0xFFEF4444);
        break;
      case 'checkedin':
      case 'checked-in':
      case 'checked in':
        color = const Color(0xFF2563EB);
        break;
      case 'checkedout':
      case 'checked-out':
      case 'checked out':
        color = const Color(0xFF0EA5E9);
        break;
      default:
        color = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: const [
          Icon(Icons.inbox_outlined, color: Color(0xFF6B7280)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No reservations found for the current filters.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
