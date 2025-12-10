import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/core/models/wishlist_item_dto.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_register_screen.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/features/guest_hotel/presentation/screens/guest_hotel_preview_screen.dart';
import 'package:roomwise/features/wishlist/wishlist_sync.dart';

class GuestWishlistScreen extends StatefulWidget {
  const GuestWishlistScreen({super.key});

  @override
  GuestWishlistScreenState createState() => GuestWishlistScreenState();
}

class GuestWishlistScreenState extends State<GuestWishlistScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);

  bool _loading = true;
  String? _error;
  List<WishlistItemDto> _items = [];
  WishlistSync? _wishlistSync;
  int _lastWishlistVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = context.read<WishlistSync>();
    if (_wishlistSync != sync) {
      _wishlistSync?.removeListener(_handleWishlistChanged);
      _wishlistSync = sync;
      _lastWishlistVersion = sync.version;
      _wishlistSync?.addListener(_handleWishlistChanged);
    }
  }

  @override
  void dispose() {
    _wishlistSync?.removeListener(_handleWishlistChanged);
    super.dispose();
  }

  void _handleWishlistChanged() {
    final sync = _wishlistSync;
    if (!mounted || sync == null) return;
    if (sync.version == _lastWishlistVersion) return;
    _lastWishlistVersion = sync.version;
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    final auth = context.read<AuthState>();

    if (!auth.isLoggedIn) {
      // no need to call API, just show login/register UI
      setState(() {
        _loading = false;
        _error = null;
        _items = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      final result = await api.getWishlist();

      if (!mounted) return;
      setState(() {
        _items = result;
        _loading = false;
      });
    } on DioException catch (e) {
      debugPrint('Load wishlist failed: $e');
      if (!mounted) return;
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await auth.logout();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _items = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in again to view your wishlist.'),
          ),
        );
      } else {
        setState(() {
          _error = 'Failed to load wishlist.';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load wishlist failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load wishlist.';
        _loading = false;
      });
    }
  }

  Future<void> reload() => _loadWishlist();

  Future<void> _removeFromWishlist(WishlistItemDto item) async {
    try {
      final api = context.read<RoomWiseApiClient>();
      await api.removeFromWishlist(item.hotelId);

      if (!mounted) return;
      setState(() {
        _items.removeWhere(
          (h) => h.id == item.id || h.hotelId == item.hotelId,
        );
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from wishlist')));
    } on DioException catch (e) {
      debugPrint('Remove from wishlist failed: $e');
      if (!mounted) return;
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await context.read<AuthState>().logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to update wishlist.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update wishlist')),
        );
      }
    } catch (e) {
      debugPrint('Remove from wishlist failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update wishlist')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    // NOT LOGGED IN → ask to login/register
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Save your favourite stays',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create an account or log in to start building your wishlist.',
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
                  // reload after login
                  await _loadWishlist();
                },
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      );
    }

    // LOGGED IN → show wishlist list
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
            TextButton(onPressed: _loadWishlist, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_items.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No favourites yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Tap the heart on a hotel to add it to your wishlist.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          final hotel = item.hotel;
          return _WishlistHotelCard(
            hotel: hotel,
            onOpen: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuestHotelPreviewScreen(hotelId: hotel.id),
                ),
              ).then((changed) {
                if (changed == true) {
                  _loadWishlist();
                }
              });
            },
            onRemove: () => _removeFromWishlist(item),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: body,
    );
  }
}

class _WishlistHotelCard extends StatelessWidget {
  final HotelSearchItemDto hotel;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _WishlistHotelCard({
    required this.hotel,
    required this.onOpen,
    required this.onRemove,
  });

  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
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
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child:
                        hotel.thumbnailUrl == null ||
                            hotel.thumbnailUrl!.isEmpty
                        ? Container(color: Colors.grey.shade200)
                        : Image.network(hotel.thumbnailUrl!, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black.withOpacity(0.4),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.favorite,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: onRemove,
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                hotel.city,
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
                        const SizedBox(height: 6),
                        Text(
                          'From €${hotel.fromPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // rating
                  if (hotel.reviewCount > 0)
                    Column(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(height: 2),
                        Text(
                          hotel.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '(${hotel.reviewCount})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
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
    );
  }
}
