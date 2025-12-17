import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/addon_dto.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/reservation_addOn_item_dto.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/features/booking/sync/bookings_sync.dart';
import 'package:roomwise/features/guest_reservation/presentation/screens/guest_reservation_preview.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/features/guest_reservation/presentation/screens/guest_payment_screen.dart';

class GuestReservationDetailsScreen extends StatefulWidget {
  final HotelDetailsDto hotel;
  final AvailableRoomTypeDto roomType;
  final DateTimeRange dateRange;
  final int guests;

  const GuestReservationDetailsScreen({
    super.key,
    required this.hotel,
    required this.roomType,
    required this.dateRange,
    required this.guests,
  });

  @override
  State<GuestReservationDetailsScreen> createState() =>
      _GuestReservationDetailsScreenState();
}

class _GuestReservationDetailsScreenState
    extends State<GuestReservationDetailsScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final Set<int> _selectedAddonIds = {};
  String _paymentMethod = 'Card'; // 'Card' or 'PayOnArrival'
  bool _submitting = false;
  String? _error;
  double _loyaltyBalance = 0;
  bool _loyaltyLoaded = false;

  int get _nights => widget.dateRange.duration.inDays;

  double get _roomTotal => widget.roomType.priceFromPerNight * _nights;

  double get _addOnsTotal {
    double total = 0;
    for (final a in widget.hotel.addOns) {
      if (!_selectedAddonIds.contains(a.id)) continue;

      double base = a.price;
      switch (a.pricingModel) {
        case 'PerNight':
          base *= _nights;
          break;
        case 'PerGuestPerNight':
          base *= _nights * widget.guests;
          break;
        case 'PerStay':
        default:
          break;
      }
      total += base;
    }
    return total;
  }

  double get _grandTotal => _roomTotal + _addOnsTotal;
  double get _loyaltyApplied =>
      _loyaltyLoaded ? math.min(_loyaltyBalance, _grandTotal) : 0;
  double get _finalTotal => (_grandTotal - _loyaltyApplied).clamp(0, 1e12);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLoyaltyBalance());
  }

  Future<void> _loadLoyaltyBalance() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      setState(() {
        _loyaltyBalance = 0;
        _loyaltyLoaded = true;
      });
      return;
    }

    try {
      final api = context.read<RoomWiseApiClient>();
      final balanceDto = await api.getLoyaltyBalance();
      if (!mounted) return;
      setState(() {
        _loyaltyBalance = balanceDto.balance.toDouble();
        _loyaltyLoaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load loyalty balance: $e');
      if (!mounted) return;
      setState(() {
        _loyaltyBalance = 0;
        _loyaltyLoaded = true;
      });
    }
  }

  void _toggleAddon(AddonDto addon, bool selected) {
    setState(() {
      if (selected) {
        _selectedAddonIds.add(addon.id);
      } else {
        _selectedAddonIds.remove(addon.id);
      }
    });
  }

  Future<bool> _ensureLoggedIn() async {
    final auth = context.read<AuthState>();
    if (auth.isLoggedIn) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in to reserve a room.')),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
    );

    return context.mounted && context.read<AuthState>().isLoggedIn;
  }

  Future<void> _onContinuePressed() async {
    final canProceed = await _ensureLoggedIn();
    if (!canProceed) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final selectedAddOnItems = _selectedAddonIds
          .map((id) => ReservationAddOnItemDto(addOnId: id, quantity: 1))
          .toList();

      final req = CreateReservationRequestDto(
        hotelId: widget.hotel.id,
        roomTypeId: widget.roomType.id,
        checkIn: widget.dateRange.start,
        checkOut: widget.dateRange.end,
        guests: widget.guests,
        addOns: selectedAddOnItems,
        paymentMethod: _paymentMethod,
      );

      debugPrint('CREATE RESERVATION REQUEST JSON (deferred): ${req.toJson()}');

      if (_paymentMethod == 'Card') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestPaymentScreen(
              request: req,
              hotel: widget.hotel,
              roomType: widget.roomType,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestReservationPreviewScreen(
              request: req,
              hotel: widget.hotel,
              roomType: widget.roomType,
              paymentMethod: 'PayOnArrival',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final room = widget.roomType;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgColor,
        title: const Text(
          'Review your stay',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepsHeader(),
              const SizedBox(height: 12),
              _buildRoomHeaderCard(hotel, room),
              const SizedBox(height: 12),
              _buildStaySummaryCard(),
              const SizedBox(height: 12),
              _buildAddOnsCard(),
              const SizedBox(height: 12),
              _buildPaymentMethodCard(),
              const SizedBox(height: 12),
              _buildPriceSummaryCard(),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(hotel),
    );
  }

  // ---------- UI SECTIONS ----------

  Widget _buildBottomBar(HotelDetailsDto hotel) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 11, color: _textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${hotel.currency} ${_finalTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _accentOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              width: 150,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitting ? null : _onContinuePressed,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
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

  Widget _buildStepsHeader() {
    // Visual stepper: Stay → Add-ons → Payment → Summary
    final steps = <Map<String, Object>>[
      {'label': 'Stay', 'icon': Icons.hotel},
      {'label': 'Add-ons', 'icon': Icons.extension},
      {'label': 'Payment', 'icon': Icons.credit_card},
      {'label': 'Summary', 'icon': Icons.receipt_long},
    ];

    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isActive = index <= 2; // we're currently on "Payment" step
          final label = steps[index]['label'] as String;
          final icon = steps[index]['icon'] as IconData;

          return Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: isActive
                      ? _primaryGreen
                      : Colors.grey.shade300,
                  child: Icon(
                    icon,
                    size: 13,
                    color: isActive ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                if (width > 340) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? _textPrimary : _textMuted,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRoomHeaderCard(
    HotelDetailsDto hotel,
    AvailableRoomTypeDto room,
  ) {
    final images =
        (room.imageUrls.isNotEmpty
                ? room.imageUrls
                : hotel.images.map((e) => e.url).toList())
            .where((e) => e.isNotEmpty)
            .toList();

    final heroUrl =
        room.thumbnailUrl ??
        (images.isNotEmpty
            ? images.first
            : hotel.heroImageUrl ??
                  (hotel.images.isNotEmpty ? hotel.images[0].url : null));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heroUrl != null && heroUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.isNotEmpty ? images.length : 1,
                      itemBuilder: (context, index) {
                        final url = images.isNotEmpty ? images[index] : heroUrl;
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        );
                      },
                    ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${images.length} photos',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hotel.name,
                  style: const TextStyle(fontSize: 13, color: _textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildChip(
                      icon: Icons.person_outline,
                      label:
                          'Sleeps ${room.capacity}${room.sizeM2 != null ? ' · ${room.sizeM2!.toStringAsFixed(0)} m²' : ''}',
                    ),
                    if (room.bedType != null && room.bedType!.isNotEmpty)
                      _buildChip(
                        icon: Icons.bed_outlined,
                        label: room.bedType!,
                      ),
                    _buildChip(
                      icon: (room.isSmokingAllowed ?? false)
                          ? Icons.smoking_rooms
                          : Icons.smoke_free,
                      label: (room.isSmokingAllowed ?? false)
                          ? 'Smoking'
                          : 'Non-smoking',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${widget.hotel.currency} ${room.priceFromPerNight.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _accentOrange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/ night',
                      style: TextStyle(fontSize: 12, color: _textMuted),
                    ),
                    const Spacer(),
                    if (room.roomsLeft > 0)
                      Text(
                        room.roomsLeft <= 3
                            ? 'Only ${room.roomsLeft} left'
                            : '${room.roomsLeft} rooms left',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaySummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: _textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(widget.dateRange.start)} → '
                  '${_formatDate(widget.dateRange.end)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_nights night${_nights == 1 ? '' : 's'} · ${widget.guests} guest${widget.guests == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: _textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOnsCard() {
    final hotel = widget.hotel;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add-ons',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          if (hotel.addOns.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'No add-ons available for this stay.',
                style: TextStyle(fontSize: 12, color: _textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: hotel.addOns.length,
              separatorBuilder: (_, __) => const Divider(height: 10),
              itemBuilder: (context, index) {
                final a = hotel.addOns[index];
                final selected = _selectedAddonIds.contains(a.id);

                final priceLabel =
                    '${a.price.toStringAsFixed(2)} ${a.currency} (${a.pricingModel})';

                return InkWell(
                  onTap: () => _toggleAddon(a, !selected),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        height: 26,
                        width: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: selected
                              ? _primaryGreen.withOpacity(0.15)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: selected
                                ? _primaryGreen
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Icon(
                          selected ? Icons.check_rounded : Icons.add_rounded,
                          size: 18,
                          color: selected
                              ? _primaryGreen
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              priceLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment method',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _paymentTile(
                  value: 'Card',
                  label: 'Card',
                  description: 'Pay now with card',
                  icon: Icons.credit_card,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _paymentTile(
                  value: 'PayOnArrival',
                  label: 'Pay at property',
                  description: 'Pay on arrival',
                  icon: Icons.meeting_room_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentTile({
    required String value,
    required String label,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () {
        setState(() => _paymentMethod = value);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? _primaryGreen.withOpacity(0.06) : _bgColor,
          border: Border.all(
            color: isSelected ? _primaryGreen : Colors.grey.shade300,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isSelected ? _primaryGreen : Colors.white,
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : _textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: _textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price summary ($_nights night${_nights == 1 ? '' : 's'})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          _priceRow('Room', _roomTotal),
          _priceRow('Add-ons', _addOnsTotal),
          if (_loyaltyApplied > 0)
            _priceRow('Loyalty discount', -_loyaltyApplied),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          _priceRow('Total (approx.)', _finalTotal, highlight: true),
          const SizedBox(height: 4),
          const Text(
            'Final price may vary slightly depending on currency and fees.',
            style: TextStyle(fontSize: 11, color: _textMuted),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount, {bool highlight = false}) {
    final currency = widget.hotel.currency;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              color: _textPrimary,
            ),
          ),
          Text(
            '$currency ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
              color: highlight ? _accentOrange : _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _textPrimary),
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
