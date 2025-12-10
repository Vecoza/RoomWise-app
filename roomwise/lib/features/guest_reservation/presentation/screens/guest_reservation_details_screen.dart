import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/addon_dto.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/features/guest_reservation/presentation/screens/guest_payment_screen.dart';
import 'package:roomwise/features/guest_reservation/presentation/screens/guest_reservation_preview';

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

  final Set<int> _selectedAddonIds = {};
  String _paymentMethod = 'Card'; // 'Card' or 'PayOnArrival'

  bool _submitting = false;
  String? _error;

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
      const SnackBar(
        content: Text('Please log in to reserve a room.'),
      ),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
    );

    return context.mounted && context.read<AuthState>().isLoggedIn;
  }

  /// Main CTA: create reservation, then branch to payment / preview.
  Future<void> _onContinuePressed() async {
    final canProceed = await _ensureLoggedIn();
    if (!canProceed) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();

      final req = CreateReservationRequestDto(
        hotelId: widget.hotel.id,
        roomTypeId: widget.roomType.id,
        checkIn: widget.dateRange.start,
        checkOut: widget.dateRange.end,
        guests: widget.guests,
        addonIds: _selectedAddonIds.toList(),
        paymentMethod: _paymentMethod, // 'Card' or 'PayOnArrival'
      );

      debugPrint('CREATE RESERVATION REQUEST JSON: ${req.toJson()}');

      final reservation = await api.createReservation(req);

      if (!mounted) return;

      // If card payment → go to payment screen (card form)
      if (_paymentMethod == 'Card') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestPaymentScreen(
              reservation: reservation,
              hotel: widget.hotel,
              roomType: widget.roomType,
            ),
          ),
        );
      } else {
        // Pay at property → go directly to preview (no card form)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestReservationPreviewScreen(
              reservation: reservation,
              hotel: widget.hotel,
              roomType: widget.roomType,
              paymentMethod: 'PayOnArrival',
            ),
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint('Create reservation failed: ${e.response?.statusCode}');
      debugPrint('Response data: ${e.response?.data}');
      debugPrint('Response headers: ${e.response?.headers}');

      if (mounted) {
        setState(() {
          _error = 'Failed to create reservation. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Create reservation failed (non-Dio): $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to create reservation. Please try again.';
        });
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
      appBar: AppBar(title: const Text('Reservation details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HOTEL + DATES
            Text(
              hotel.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDate(widget.dateRange.start)} → '
              '${_formatDate(widget.dateRange.end)} · '
              '${widget.guests} guest${widget.guests == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // ROOM INFO
            Text(
              room.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Sleeps ${room.capacity}'
              '${room.sizeM2 != null ? ' · ${room.sizeM2!.toStringAsFixed(0)} m²' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // ADD-ONS
            if (hotel.addOns.isNotEmpty) ...[
              const Text(
                'Add-ons',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  itemCount: hotel.addOns.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = hotel.addOns[index];
                    final selected = _selectedAddonIds.contains(a.id);

                    return CheckboxListTile(
                      value: selected,
                      onChanged: (value) => _toggleAddon(a, value ?? false),
                      title: Text(a.name),
                      subtitle: Text(
                        '${a.price.toStringAsFixed(2)} ${a.currency} '
                        '(${a.pricingModel})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            ] else
              const Text(
                'No add-ons available for this hotel.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

            const SizedBox(height: 12),

            // PAYMENT METHOD
            const Text(
              'Payment method',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    value: 'Card',
                    groupValue: _paymentMethod,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Credit / debit card'),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _paymentMethod = value);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    value: 'PayOnArrival',
                    groupValue: _paymentMethod,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pay at property'),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _paymentMethod = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // PRICE SUMMARY
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price summary ($_nights night${_nights == 1 ? '' : 's'})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _priceRow('Room', _roomTotal),
                  _priceRow('Add-ons', _addOnsTotal),
                  const Divider(),
                  _priceRow('Total (approx.)', _grandTotal, highlight: true),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _onContinuePressed,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, double amount, {bool highlight = false}) {
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
            ),
          ),
          Text(
            '€${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? _accentOrange : Colors.black,
            ),
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
