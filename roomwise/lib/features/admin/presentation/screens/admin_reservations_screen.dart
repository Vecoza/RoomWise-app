import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/admin_reservation_dto.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() => _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _primaryGreen = Color(0xFF05A87A);
  static const _danger = Color(0xFFEF4444);

  final _dateFmt = DateFormat('dd MMM yyyy');

  bool _loading = true;
  bool _cancelling = false;
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

  Future<void> _cancel(AdminReservationDto r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation'),
        content: Text(
          'Are you sure you want to cancel ${r.confirmationNumber ?? r.publicId}?',
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

    setState(() => _cancelling = true);
    try {
      await context.read<RoomWiseApiClient>().cancelAdminReservation(r.id);
      await _load();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await context.read<AuthState>().logout();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code == 401 || code == 403
                ? 'Not authorized. Please log in again.'
                : 'Cancel failed: ${e.response?.statusCode}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _showDetails(AdminReservationDto r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: ListView(
                controller: controller,
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
                  Text(
                    r.confirmationNumber ?? r.publicId,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_dateFmt.format(r.checkIn)} • ${_dateFmt.format(r.checkOut)}',
                    style: const TextStyle(color: _textMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailChip(
                        label: 'Guests',
                        value: r.guests.toString(),
                      ),
                      _DetailChip(
                        label: 'Status',
                        value: r.status,
                        color: _statusColor(r.status),
                      ),
                      _DetailChip(
                        label: 'Total',
                        value: '${r.currency} ${r.total.toStringAsFixed(2)}',
                      ),
                      _DetailChip(
                        label: 'Paid',
                        value: '${r.currency} ${r.amountPaid.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add-ons',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (r.addOns.isEmpty)
                    const Text(
                      'None',
                      style: TextStyle(color: _textMuted),
                    )
                  else
                    Column(
                      children: r.addOns
                          .map(
                            (a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(a.name),
                              subtitle: Text(a.pricingModel),
                              trailing: Text(
                                '${a.currency} ${a.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Created ${_dateFmt.format(r.createdAt)}',
                    style: const TextStyle(color: _textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: _cancelling ? null : () => _cancel(r),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel reservation'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reservations',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Filters(
          statuses: _statuses,
          status: _statusFilter,
          from: _from,
          to: _to,
          sort: _sort,
          sortOptions: _sortOptions,
          onStatusChanged: (v) {
            setState(() => _statusFilter = v);
            _load();
          },
          onClearDates: () {
            setState(() {
              _from = null;
              _to = null;
            });
            _load();
          },
          onPickDates: _pickDateRange,
          onSortChanged: (v) => setState(() => _sort = v),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _ErrorCard(message: _error!, onRetry: _load)
        else if (_items.isEmpty)
          const _EmptyCard()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sortedItems().length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = _sortedItems()[i];
              return _ReservationCard(
                reservation: r,
                onTap: () => _showDetails(r),
              );
            },
          ),
      ],
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

class _Filters extends StatelessWidget {
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

  const _Filters({
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

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        DropdownButton<String>(
          value: status,
          items: statuses
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onStatusChanged(v);
          },
        ),
        DropdownButton<String>(
          value: sort,
          items: sortOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            if (v != null) onSortChanged(v);
          },
        ),
        OutlinedButton.icon(
          onPressed: onPickDates,
          icon: const Icon(Icons.date_range),
          label: Text(dateText),
        ),
        if (from != null || to != null)
          TextButton(
            onPressed: onClearDates,
            child: const Text('Clear dates'),
          ),
      ],
    );
  }
}

class _ReservationCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _primaryGreen = Color(0xFF05A87A);

  final AdminReservationDto reservation;
  final VoidCallback onTap;

  const _ReservationCard({
    required this.reservation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bed, color: _primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.confirmationNumber ?? reservation.publicId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFmt.format(reservation.checkIn)} • ${dateFmt.format(reservation.checkOut)} • ${reservation.guests} guests',
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusPill(status: reservation.status),
                  const SizedBox(height: 8),
                  Text(
                    '${reservation.currency} ${reservation.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                ],
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
      case 'cancelled':
        color = const Color(0xFFEF4444);
        break;
      case 'checkedin':
      case 'checked-in':
        color = const Color(0xFF2563EB);
        break;
      default:
        color = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _DetailChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color ?? Colors.black87,
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

  const _ErrorCard({required this.message, required this.onRetry});

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
  const _EmptyCard();

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
          Text(
            'No reservations found for the current filters.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
