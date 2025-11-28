import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_register_screen.dart';

import 'package:provider/provider.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_login_screen.dart'; // only if AuthState uses Provider

class GuestHotelPreviewScreen extends StatefulWidget {
  final int hotelId;

  const GuestHotelPreviewScreen({super.key, required this.hotelId});

  @override
  State<GuestHotelPreviewScreen> createState() =>
      _GuestHotelPreviewScreenState();
}

class _GuestHotelPreviewScreenState extends State<GuestHotelPreviewScreen> {
  // final _api = RoomWiseApiClient();

  bool _loading = true;
  String? _error;
  HotelDetailsDto? _hotel;

  // --- wishlist state ---
  bool _wishlistBusy = false;
  bool _isInWishlist = false;

  @override
  void initState() {
    super.initState();
    _loadHotel();
  }

  Future<void> _loadHotel() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      final result = await api.getHotelDetails(hotelId: widget.hotelId);

      setState(() {
        _hotel = result;
        _loading = false;
      });

      await _syncWishlistStatus();
    } catch (e) {
      debugPrint('Load hotel details failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load hotel details.';
        _loading = false;
      });
    }
  }

  Future<void> _syncWishlistStatus() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) return;

    try {
      final api = context.read<RoomWiseApiClient>();
      final wishlistHotels = await api.getWishlist();

      if (!mounted) return;
      final exists = wishlistHotels.any((h) => h.id == widget.hotelId);

      setState(() {
        _isInWishlist = exists;
      });
    } on DioException catch (e) {
      debugPrint('Load wishlist status failed: $e');
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await auth.logout();
        if (!mounted) return;
        setState(() {
          _isInWishlist = false;
        });
      }
    } catch (e) {
      debugPrint('Load wishlist status failed: $e');
    }
  }

  void _openLoginFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestLoginScreen(
          onLoginSuccess: () {
            _syncWishlistStatus();
          },
        ),
      ),
    );
  }

  Future<void> _onToggleWishlist() async {
    final auth = context.read<AuthState>();

    // If not logged in → navigate to login screen
    if (!auth.isLoggedIn) {
      _openLoginFlow();
      return;
    }

    if (_wishlistBusy) return;

    setState(() {
      _wishlistBusy = true;
    });

    try {
      final api = context.read<RoomWiseApiClient>();

      if (_isInWishlist) {
        // remove by hotelId
        await api.removeFromWishlist(widget.hotelId);
        if (!mounted) return;
        setState(() {
          _isInWishlist = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from wishlist')));
      } else {
        // add by hotelId
        await api.addToWishlist(widget.hotelId);
        if (!mounted) return;
        setState(() {
          _isInWishlist = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to wishlist')));
      }
    } on DioException catch (e) {
      debugPrint('Toggle wishlist failed: $e');
      if (!mounted) return;
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await auth.logout();
        if (!mounted) return;
        setState(() {
          _isInWishlist = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to use wishlist')),
        );
        _openLoginFlow();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update wishlist')),
        );
      }
    } catch (e) {
      debugPrint('Toggle wishlist failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update wishlist')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _wishlistBusy = false;
        });
      }
    }
  }

  void _onSelectRoom(AvailableRoomTypeDto room) {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      _showAuthRequiredModal(room);
      return;
    }

    // TODO: go to reservation flow with selected roomTypeId, dates, guests
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reservation flow coming soon.')),
    );
  }

  void _showAuthRequiredModal(AvailableRoomTypeDto room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              children: [
                const Text(
                  'Sign in to book',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You need an account to book a room. Log in or create a free account.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GuestLoginScreen(),
                        ),
                      );
                    },
                    child: const Text('Log in'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
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
            TextButton(onPressed: _loadHotel, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_hotel == null) {
      body = const Center(child: Text('Hotel not found.'));
    } else {
      body = _buildContent(_hotel!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_hotel?.name ?? 'Hotel'),
        actions: [
          IconButton(
            icon: Icon(
              _isInWishlist ? Icons.favorite : Icons.favorite_border,
              color: _isInWishlist ? Colors.redAccent : null,
            ),
            onPressed: _onToggleWishlist,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildContent(HotelDetailsDto hotel) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: hotel.photos.isEmpty ? 1 : hotel.photos.length,
              itemBuilder: (context, index) {
                if (hotel.photos.isEmpty) {
                  return Container(color: Colors.grey.shade200);
                }
                final url = hotel.photos[index];
                return Image.network(url, fit: BoxFit.cover);
              },
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
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
                        '${hotel.city} • ${hotel.addressLine}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 18, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      hotel.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  hotel.description,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),

                // AMENITIES
                if (hotel.amenities.isNotEmpty) ...[
                  const Text(
                    'Amenities',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: hotel.amenities
                        .map(
                          (a) => Chip(
                            label: Text(
                              a,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // AVAILABLE ROOMS
                const Text(
                  'Available rooms',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                if (hotel.availableRoomTypes.isEmpty)
                  const Text(
                    'No rooms matching your criteria.',
                    style: TextStyle(fontSize: 13),
                  )
                else
                  Column(
                    children: hotel.availableRoomTypes
                        .map(
                          (r) => _RoomTypeCard(
                            room: r,
                            onSelect: () => _onSelectRoom(r),
                          ),
                        )
                        .toList(),
                  ),

                const SizedBox(height: 24),
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
  final VoidCallback onSelect;

  static const _primaryGreen = Color(0xFF05A87A);

  const _RoomTypeCard({required this.room, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sleeps ${room.capacity}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  '€${room.nightlyPrice.toStringAsFixed(0)} / night',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (room.roomsLeft <= 5)
                  Text(
                    '${room.roomsLeft} rooms left',
                    style: TextStyle(
                      fontSize: 11,
                      color: room.roomsLeft <= 2
                          ? Colors.red
                          : Colors.orangeAccent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: onSelect,
              child: const Text('Select', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
