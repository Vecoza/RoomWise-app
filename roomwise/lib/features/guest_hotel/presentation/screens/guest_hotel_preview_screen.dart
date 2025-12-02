import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'package:roomwise/features/guest_reservation/presentation/screens/guest_reservation_details_screen.dart';

class GuestHotelPreviewScreen extends StatefulWidget {
  final int hotelId;
  final DateTimeRange? dateRange;
  final int? guests;

  const GuestHotelPreviewScreen({
    super.key,
    required this.hotelId,
    this.dateRange,
    this.guests,
  });

  @override
  State<GuestHotelPreviewScreen> createState() =>
      _GuestHotelPreviewScreenState();
}

class _GuestHotelPreviewScreenState extends State<GuestHotelPreviewScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);

  bool _loading = true;
  String? _error;
  HotelDetailsDto? _hotel;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();

      final details = await api.getHotelDetails(
        hotelId: widget.hotelId,
        checkIn: widget.dateRange?.start,
        checkOut: widget.dateRange?.end,
        guests: widget.guests,
      );

      if (!mounted) return;
      setState(() {
        _hotel = details;
        _loading = false;
      });
    } on DioException catch (e) {
      debugPrint('Hotel details load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load hotel details.';
        _loading = false;
      });
    } catch (e) {
      debugPrint('Hotel details load failed (non-Dio): $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load hotel details.';
        _loading = false;
      });
    }
  }

  void _onSelectRoom(AvailableRoomTypeDto roomType) {
    final hotel = _hotel;
    if (hotel == null) return;

    if (widget.dateRange == null || widget.guests == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select dates and number of guests first.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestReservationDetailsScreen(
          hotel: hotel,
          roomType: roomType,
          dateRange: widget.dateRange!,
          guests: widget.guests!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadDetails, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_hotel == null) {
      body = const Center(child: Text('Hotel not found.'));
    } else {
      body = _buildContent(_hotel!);
    }

    return Scaffold(
      appBar: AppBar(title: Text(_hotel?.name ?? 'Hotel')),
      body: RefreshIndicator(onRefresh: _loadDetails, child: body),
    );
  }

  Widget _buildContent(HotelDetailsDto hotel) {
    final rooms = hotel.availableRoomTypes ?? const <AvailableRoomTypeDto>[];
    final heroImage = hotel.heroImageUrl?.isNotEmpty == true
        ? hotel.heroImageUrl
        : null;
    final fallbackGallery = hotel.galleryUrls.isNotEmpty
        ? hotel.galleryUrls.first
        : null;
    final mainImageUrl = heroImage ?? fallbackGallery;
    final currency = hotel.currency.isNotEmpty ? hotel.currency : 'EUR';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image
          if (mainImageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(mainImageUrl, fit: BoxFit.cover),
            )
          else
            Container(
              height: 200,
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.hotel, size: 48, color: Colors.grey),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hotel name + rating
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hotel.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hotel.rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hotel.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        hotel.city,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                if (hotel.description != null &&
                    hotel.description!.trim().isNotEmpty) ...[
                  const Text(
                    'About this stay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hotel.description!,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                ],

                // Facilities
                if (hotel.facilities.isNotEmpty) ...[
                  const Text(
                    'Facilities',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: hotel.facilities.map((f) {
                      return Chip(
                        label: Text(
                          f.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Add-ons
                if (hotel.addOns.isNotEmpty) ...[
                  const Text(
                    'Add-ons',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: hotel.addOns.map((a) {
                      return Chip(
                        label: Text(
                          a.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Rooms list
                const Text(
                  'Rooms',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (rooms.isEmpty)
                  const Text(
                    'No rooms available for the selected dates.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _RoomTypeCard(
                        room: room,
                        currency: currency,
                        onSelect: () => _onSelectRoom(room),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomTypeCard extends StatelessWidget {
  final AvailableRoomTypeDto room;
  final String currency;
  final VoidCallback onSelect;

  const _RoomTypeCard({
    required this.room,
    required this.currency,
    required this.onSelect,
  });

  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    final sizePart = room.sizeM2 != null
        ? ' · ${room.sizeM2!.toStringAsFixed(0)} m²'
        : '';
    final availabilityText = room.roomsLeft > 5
        ? 'Good availability'
        : room.roomsLeft > 0
        ? 'Only ${room.roomsLeft} left'
        : 'Sold out';

    final availabilityColor = room.roomsLeft == 0
        ? Colors.redAccent
        : room.roomsLeft <= 5
        ? Colors.orange
        : Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + capacity / size
            Text(
              room.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Sleeps ${room.capacity}$sizePart',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),

            // Price
            Text(
              '$currency ${room.priceFromPerNight.toStringAsFixed(2)} / night',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _accentOrange,
              ),
            ),
            const SizedBox(height: 4),

            // Availability
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: availabilityColor),
                const SizedBox(width: 6),
                Text(
                  availabilityText,
                  style: TextStyle(
                    fontSize: 12,
                    color: availabilityColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: room.roomsLeft == 0 ? null : onSelect,
                child: const Text(
                  'Choose room',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
