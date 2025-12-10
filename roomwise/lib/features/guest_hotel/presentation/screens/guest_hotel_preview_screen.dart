import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'package:roomwise/core/models/hotel_image_dto.dart';
import 'package:roomwise/core/models/review_response_dto.dart';
import 'package:roomwise/core/search/search_state.dart';
import 'package:roomwise/features/guest_reservation/presentation/screens/guest_reservation_details_screen.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/features/wishlist/wishlist_sync.dart';

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
  bool _wishlistUpdating = false;
  bool _wishlistChanged = false;
  bool? _isWishlisted;
  int _currentImageIndex = 0;
  final List<ReviewResponseDto> _reviews = [];
  bool _reviewsLoading = false;
  String? _reviewsError;
  int _reviewsPage = 1;
  bool _reviewsHasMore = true;

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
      await _loadReviews(reset: true);
      await _syncWishlistStatus();
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

  Future<void> _syncWishlistStatus() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      if (_isWishlisted != false && mounted) {
        setState(() {
          _isWishlisted = false;
        });
      }
      return;
    }

    try {
      final api = context.read<RoomWiseApiClient>();
      final wishlist = await api.getWishlist();
      if (!mounted) return;
      final isSaved = wishlist.any(
        (item) =>
            item.hotelId == widget.hotelId || item.hotel.id == widget.hotelId,
      );
      setState(() => _isWishlisted = isSaved);
    } catch (e) {
      debugPrint('Wishlist status check failed: $e');
    }
  }

  void _onSelectRoom(AvailableRoomTypeDto roomType) {
    final hotel = _hotel;
    if (hotel == null) return;

    final search = context.read<SearchState>();
    final dateRange = widget.dateRange ??
        (search.hasSelection
            ? DateTimeRange(start: search.checkIn!, end: search.checkOut!)
            : null);
    final guests = widget.guests ?? search.guests;

    if (dateRange == null || guests == null) {
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
          dateRange: dateRange,
          guests: guests,
        ),
      ),
    );
  }

  Future<void> _toggleWishlist() async {
    if (_wishlistUpdating) return;

    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to update wishlist.')),
      );

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
      );

      if (!mounted) return;
      await _syncWishlistStatus();
      if (context.read<AuthState>().isLoggedIn) {
        return _toggleWishlist();
      }
      return;
    }

    setState(() => _wishlistUpdating = true);

    final api = context.read<RoomWiseApiClient>();
    final currentlyWishlisted = _isWishlisted ?? false;

    try {
      if (currentlyWishlisted) {
        await api.removeFromWishlist(widget.hotelId);
      } else {
        await api.addToWishlist(widget.hotelId);
      }

      if (!mounted) return;
      setState(() {
        _isWishlisted = !currentlyWishlisted;
        _wishlistChanged = true;
      });

      context.read<WishlistSync>().notifyChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyWishlisted ? 'Removed from wishlist' : 'Added to wishlist',
          ),
        ),
      );
    } on DioException catch (e) {
      debugPrint('Wishlist update failed: $e');
      if (!mounted) return;

      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await auth.logout();
        if (!mounted) return;
        setState(() => _isWishlisted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to update wishlist.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update wishlist')),
        );
      }
    } catch (e) {
      debugPrint('Wishlist update failed (non-Dio): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update wishlist')),
      );
    } finally {
      if (mounted) {
        setState(() => _wishlistUpdating = false);
      }
    }
  }

  Future<bool> _handleWillPop() async {
    Navigator.of(context).pop(_wishlistChanged);
    return false;
  }

  Future<void> _loadReviews({bool reset = false}) async {
    final hotel = _hotel;
    if (hotel == null) return;

    if (reset) {
      setState(() {
        _reviews.clear();
        _reviewsPage = 1;
        _reviewsHasMore = true;
        _reviewsError = null;
      });
    }

    if (_reviewsLoading || !_reviewsHasMore) return;

    setState(() {
      _reviewsLoading = true;
      _reviewsError = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      final res = await api.getHotelReviews(
        hotelId: hotel.id,
        page: _reviewsPage,
        pageSize: 10,
      );

      if (!mounted) return;

      setState(() {
        _reviews.addAll(res.items);
        final total = res.totalCount ?? _reviews.length;
        _reviewsHasMore = _reviews.length < total;
        if (_reviewsHasMore) {
          _reviewsPage += 1;
        }
        _reviewsLoading = false;
        _reviewsError = null;
      });
    } catch (e) {
      debugPrint('Load reviews failed: $e');
      if (!mounted) return;
      setState(() {
        _reviewsLoading = false;
        _reviewsError = 'Failed to load reviews';
      });
    }
  }

  Widget _buildWishlistButton() {
    final saved = _isWishlisted ?? false;

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.black.withOpacity(0.45),
      child: _wishlistUpdating
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                saved ? Icons.favorite : Icons.favorite_border,
                color: saved ? Colors.redAccent : Colors.white,
              ),
              onPressed: _toggleWishlist,
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

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_wishlistChanged),
          ),
          title: Text(_hotel?.name ?? 'Hotel'),
        ),
        body: RefreshIndicator(onRefresh: _loadDetails, child: body),
      ),
    );
  }

  List<HotelImageDto> _galleryImages(HotelDetailsDto hotel) {
    if (hotel.images.isNotEmpty) return hotel.images;
    if (hotel.galleryUrls.isNotEmpty) {
      return hotel.galleryUrls
          .asMap()
          .entries
          .map(
            (e) => HotelImageDto(
              id: e.key,
              hotelId: hotel.id,
              url: e.value,
              sortOrder: e.key,
            ),
          )
          .toList();
    }
    return [];
  }

  Widget _buildImageGallery(HotelDetailsDto hotel) {
    final images = _galleryImages(hotel);
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, size: 48),
          ),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _openFullScreenGallery(hotel),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() => _currentImageIndex = index);
                },
                itemBuilder: (context, index) {
                  final img = images[index];
                  return Hero(
                    tag: 'hotel-${hotel.id}-image-$index',
                    child: Image.network(
                      img.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (index) {
            final isActive = index == _currentImageIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              width: isActive ? 20 : 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive ? _accentOrange : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }

  void _openFullScreenGallery(HotelDetailsDto hotel) {
    final images = _galleryImages(hotel);
    if (images.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        int pageIndex = _currentImageIndex;
        final controller = PageController(
          initialPage: _currentImageIndex,
          viewportFraction: 1,
        );
        return StatefulBuilder(
          builder: (context, setLocal) {
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Scaffold(
                backgroundColor: Colors.black,
                body: SafeArea(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: controller,
                        itemCount: images.length,
                        onPageChanged: (i) => setLocal(() => pageIndex = i),
                        itemBuilder: (context, index) {
                          final img = images[index];
                          return Center(
                            child: Hero(
                              tag: 'hotel-${hotel.id}-image-$index',
                              child: InteractiveViewer(
                                child: Image.network(
                                  img.url,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            '${pageIndex + 1} / ${images.length}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(HotelDetailsDto hotel) {
    final rooms = hotel.availableRoomTypes;
    final currency = hotel.currency.isNotEmpty ? hotel.currency : 'EUR';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Stack(
              children: [
                _buildImageGallery(hotel),
                Positioned(top: 10, right: 10, child: _buildWishlistButton()),
              ],
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
                    Builder(
                      builder: (context) {
                        final reviewAvg = _reviewsAverage();
                        if (reviewAvg <= 0) return const SizedBox.shrink();
                        return Row(
                          children: [
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
                                    reviewAvg.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_reviews.length} review${_reviews.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        );
                      },
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

                _buildReviewsSection(hotel),

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

  Widget _buildReviewsSection(HotelDetailsDto hotel) {
    final hasAnyReviews = _reviews.isNotEmpty;
    final avg = _reviewsAverage();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_reviewsLoading && _reviews.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_reviewsError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _reviewsError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton(onPressed: () => _loadReviews(reset: true), child: const Text('Retry')),
            ],
          )
        else if (_reviews.isEmpty)
          const Text(
            'No reviews yet.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          )
        else
          Column(
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reviews.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final r = _reviews[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStars(r.rating),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(r.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      if (r.title?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          r.title!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (r.body?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          r.body!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  );
                },
              ),
              if (_reviewsHasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: _reviewsLoading ? null : _loadReviews,
                    child: _reviewsLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load more'),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }

  double _reviewsAverage() {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
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
