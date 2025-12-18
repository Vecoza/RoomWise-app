import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/addon_dto.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'package:roomwise/core/models/reservation_addOn_item_dto.dart';
import 'package:roomwise/core/models/reservation_dto.dart'
    show CreateReservationRequestDto;
import 'package:roomwise/features/guest/guest_reservation/presentation/screens/guest_reservation_preview.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestPaymentScreen extends StatefulWidget {
  final CreateReservationRequestDto request;
  final HotelDetailsDto hotel;
  final AvailableRoomTypeDto roomType;

  const GuestPaymentScreen({
    super.key,
    required this.request,
    required this.hotel,
    required this.roomType,
  });

  @override
  State<GuestPaymentScreen> createState() => _GuestPaymentScreenState();
}

class _GuestPaymentScreenState extends State<GuestPaymentScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _loading = false;
  String? _error;
  double _loyaltyBalance = 0;
  bool _loyaltyLoaded = false;

  CardFieldInputDetails? _cardDetails;
  final TextEditingController _cardHolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLoyaltyBalance());
  }

  Future<void> _loadLoyaltyBalance() async {
    try {
      final api = context.read<RoomWiseApiClient>();
      final bal = await api.getLoyaltyBalance();
      if (!mounted) return;
      setState(() {
        _loyaltyBalance = bal.balance.toDouble();
        _loyaltyLoaded = true;
      });
    } catch (e) {
      debugPrint('Payment screen: failed to load loyalty balance: $e');
      if (!mounted) return;
      setState(() {
        _loyaltyBalance = 0;
        _loyaltyLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _onContinueToPreview() async {
    final t = AppLocalizations.of(context)!;
    if (_cardDetails?.complete != true) {
      setState(() {
        _error = t.paymentCardIncomplete;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Do not charge here; just pass data forward
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuestReservationPreviewScreen(
            request: widget.request,
            hotel: widget.hotel,
            roomType: widget.roomType,
            paymentMethod: t.paymentMethodCard,
            cardHolderName: _cardHolderController.text.trim(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day.$month.$year';
  }

  double _computeAddOnsTotal() {
    double total = 0;
    final addOns = widget.hotel.addOns;
    for (final item in widget.request.addOns) {
      AddonDto? found;
      for (final AddonDto a in addOns) {
        if (a.id == item.addOnId) {
          found = a;
          break;
        }
      }
      final addOn = found;
      if (addOn == null) continue;
      double base = addOn.price * item.quantity;
      switch (addOn.pricingModel) {
        case 'PerNight':
          base *= widget.request.checkOut
              .difference(widget.request.checkIn)
              .inDays
              .clamp(1, 365);
          break;
        case 'PerGuestPerNight':
          base *=
              widget.request.checkOut
                  .difference(widget.request.checkIn)
                  .inDays
                  .clamp(1, 365) *
              widget.request.guests;
          break;
        case 'PerStay':
        default:
          break;
      }
      total += base;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final nights = req.checkOut.difference(req.checkIn).inDays.clamp(1, 365);
    final currency = widget.hotel.currency.isNotEmpty
        ? widget.hotel.currency
        : 'EUR';
    final roomTotal = widget.roomType.priceFromPerNight * nights;
    final addOnsTotal = _computeAddOnsTotal();
    final baseTotal = roomTotal + addOnsTotal;
    final loyaltyApplied = _loyaltyLoaded
        ? math.min(_loyaltyBalance, baseTotal)
        : 0;
    final finalTotal = (baseTotal - loyaltyApplied).clamp(0, 1e12);
    final totalText = '$currency ${finalTotal.toStringAsFixed(2)}';
    final dateRange =
        '${_formatDate(req.checkIn)} – ${_formatDate(req.checkOut)}';
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(
          t.paymentTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          16 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Secure badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.lock_rounded,
                                        size: 14,
                                        color: _primaryGreen,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        t.paymentSecureStripe,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Summary card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.hotel.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.roomType.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.date_range_outlined,
                                        size: 16,
                                        color: _textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          dateRange,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _textMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${t.nightsLabel(nights)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 18),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        t.paymentTotalToPay,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: _textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        totalText,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: _accentOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Card details card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.paymentCardTitle,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.paymentCardSubtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _cardHolderController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      labelText: t.paymentCardNameOptional,
                                      labelStyle: const TextStyle(
                                        fontSize: 13,
                                        color: _textMuted,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _bgColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: CardField(
                                      onCardChanged: (details) {
                                        setState(() => _cardDetails = details);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: _textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          t.paymentCardInfo,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.5),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Sticky bottom bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.paymentTotalLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                  ),
                                ),
                                Text(
                                  totalText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _loading
                                    ? null
                                    : _onContinueToPreview,
                                child: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        t.paymentContinue,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
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
  }
}
