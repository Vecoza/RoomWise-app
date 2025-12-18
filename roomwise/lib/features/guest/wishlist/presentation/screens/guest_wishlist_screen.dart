import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/core/models/wishlist_item_dto.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_register_screen.dart';
import 'package:roomwise/features/guest/onboarding/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/features/guest/guest_hotel/presentation/screens/guest_hotel_preview_screen.dart';
import 'package:roomwise/features/guest/wishlist/wishlist_sync.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestWishlistScreen extends StatefulWidget {
  const GuestWishlistScreen({super.key});

  @override
  GuestWishlistScreenState createState() => GuestWishlistScreenState();
}

class GuestWishlistScreenState extends State<GuestWishlistScreen> {
  // --- DESIGN TOKENS (align with other guest screens) ---
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF5F7FA);
  static const _cardColor = Colors.white;
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const double _cardRadius = 18;
  static const double _cardPadding = 12;

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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.wishlistLoginAgain),
          ),
        );
      } else {
        setState(() {
          _error = AppLocalizations.of(context)!.wishlistLoadFailed;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load wishlist failed: $e');
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.wishlistLoadFailed;
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
        _items.removeWhere((h) => h.id == item.id || h.hotelId == item.hotelId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.wishlistRemoved)),
      );
    } on DioException catch (e) {
      debugPrint('Remove from wishlist failed: $e');
      if (!mounted) return;
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await context.read<AuthState>().logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.wishlistUpdateLogin),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.wishlistUpdateFailed),
          ),
        );
      }
    } catch (e) {
      debugPrint('Remove from wishlist failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.wishlistUpdateFailed),
        ),
      );
    }
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(t.wishlistTitle),
        backgroundColor: _bgColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: auth.isLoggedIn ? _buildLoggedIn(t) : _buildLoggedOut(t),
      ),
    );
  }

  // ---------- LOGGED OUT ----------

  Widget _buildLoggedOut(AppLocalizations t) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 64, color: _textMuted),
              const SizedBox(height: 16),
              Text(
                t.wishlistLoggedOutTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.wishlistLoggedOutSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _textMuted),
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
                      borderRadius: BorderRadius.circular(12),
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
                    t.wishlistCreateAccount,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
                  );
                  await _loadWishlist();
                },
                child: Text(t.alreadyAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- LOGGED IN ----------

  Widget _buildLoggedIn(AppLocalizations t) {
    return RefreshIndicator(
      onRefresh: _loadWishlist,
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
                  TextButton(onPressed: _loadWishlist, child: Text(t.retry)),
                ],
              ),
            )
          : (_items.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final hotel = item.hotel;

                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: _WishlistHotelCard(
                                hotel: hotel,
                                onOpen: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GuestHotelPreviewScreen(
                                        hotelId: hotel.id,
                                      ),
                                    ),
                                  ).then((changed) {
                                    if (changed == true) {
                                      _loadWishlist();
                                    }
                                  });
                                },
                                onRemove: () => _removeFromWishlist(item),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Builder(
            builder: (context) {
              final t = AppLocalizations.of(context)!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: _textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.wishlistNoFavouritesTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      t.wishlistNoFavouritesSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: _textMuted),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
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
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // image + heart
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
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.black.withOpacity(0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.favorite,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // name, location, price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
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
                                hotel.city,
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
                        const SizedBox(height: 6),
                        Text(
                          'From €${hotel.fromPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7E5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hotel.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(${hotel.reviewCount})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textMuted,
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
