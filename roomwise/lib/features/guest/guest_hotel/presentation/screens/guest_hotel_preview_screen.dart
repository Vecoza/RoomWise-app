import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/core/models/hotel_image_dto.dart';
import 'package:roomwise/core/models/review_response_dto.dart';
import 'package:roomwise/core/search/search_state.dart';
import 'package:roomwise/features/guest/guest_reservation/presentation/screens/guest_reservation_details_screen.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/features/guest/wishlist/wishlist_sync.dart';
import 'package:roomwise/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _bgColor = Color(0xFFF3F4F6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _loading = true;
  String? _error;
  HotelDetailsDto? _hotel;
  bool _wishlistUpdating = false;
  bool _wishlistChanged = false;
  bool? _isWishlisted;
  int _currentImageIndex = 0;
  DateTimeRange? _activeRange;
  int? _activeGuests;

  final List<ReviewResponseDto> _reviews = [];
  bool _reviewsLoading = false;
  String? _reviewsError;
  int _reviewsPage = 1;
  bool _reviewsHasMore = true;

  final List<HotelSearchItemDto> _recommended = [];
  bool _recommendedLoading = false;
  String? _recommendedError;
  bool _recommendedFallback = false;
  String? _lastAuthToken;

  @override
  void initState() {
    super.initState();
    _lastAuthToken = context.read<AuthState>().token;
    final search = context.read<SearchState>();
    _activeRange =
        widget.dateRange ??
        (search.checkIn != null && search.checkOut != null
            ? DateTimeRange(start: search.checkIn!, end: search.checkOut!)
            : null);
    _activeGuests = widget.guests ?? search.guests;
    _loadDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authToken = context.read<AuthState>().token;
    if (authToken == _lastAuthToken) return;
    _lastAuthToken = authToken;

    if (_hotel == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRecommendations();
    });
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
        checkIn: _activeRange?.start,
        checkOut: _activeRange?.end,
        guests: _activeGuests,
      );

      if (!mounted) return;
      setState(() {
        _hotel = details;
        _loading = false;
      });

      await _recordRecentlyViewed(details);
      await _loadReviews(reset: true);
      await _syncWishlistStatus();
      await _loadRecommendations();
    } on DioException catch (e) {
      debugPrint('Hotel details load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.previewLoadFailed;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Hotel details load failed (non-Dio): $e');
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.previewLoadFailed;
        _loading = false;
      });
    }
  }

  Future<void> _recordRecentlyViewed(HotelDetailsDto details) async {
    final auth = context.read<AuthState>();
    final email = auth.email;
    if (!auth.isLoggedIn || email == null || email.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'recently_viewed_${email.toLowerCase()}';
    final existing = prefs.getStringList(key) ?? const [];
    final id = details.id.toString();

    final next = <String>[id, ...existing.where((e) => e != id)];
    if (next.length > 10) {
      next.removeRange(10, next.length);
    }

    await prefs.setStringList(key, next);
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

    _prepareSelection().then((selection) async {
      if (selection == null) return;
      if (!mounted) return;
      setState(() {
        _activeRange = selection.range;
        _activeGuests = selection.guests;
      });

      final api = context.read<RoomWiseApiClient>();
      HotelDetailsDto? pricedHotel;
      AvailableRoomTypeDto pricedRoom = roomType;

      try {
        pricedHotel = await api.getHotelDetails(
          hotelId: widget.hotelId,
          checkIn: selection.range.start,
          checkOut: selection.range.end,
          guests: selection.guests,
        );
        final match = pricedHotel.availableRoomTypes.firstWhere(
          (rt) => rt.id == roomType.id,
          orElse: () => roomType,
        );
        pricedRoom = match;
        if (!mounted) return;
        setState(() {
          _hotel = pricedHotel;
        });
      } catch (e) {
        debugPrint('Hotel details price refresh failed: $e');
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuestReservationDetailsScreen(
            hotel: pricedHotel ?? hotel,
            roomType: pricedRoom,
            dateRange: selection.range,
            guests: selection.guests,
          ),
        ),
      );
    });
  }

  Future<_BookingSelection?> _prepareSelection({
    bool requireLogin = true,
  }) async {
    final auth = context.read<AuthState>();
    if (requireLogin && !auth.isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
      );
      if (!context.mounted || !context.read<AuthState>().isLoggedIn) {
        return null;
      }
    }

    final search = context.read<SearchState>();
    DateTimeRange? dateRange =
        _activeRange ??
        (search.checkIn != null && search.checkOut != null
            ? DateTimeRange(start: search.checkIn!, end: search.checkOut!)
            : null);
    int? guests = _activeGuests ?? search.guests;

    if (dateRange != null && guests != null) {
      return _BookingSelection(dateRange, guests);
    }

    final result = await showModalBottomSheet<_BookingSelection>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final t = AppLocalizations.of(ctx)!;
        DateTimeRange? localRange = dateRange;
        int localGuests = guests ?? 2;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickRange() async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                  initialDateRange:
                      localRange ??
                      DateTimeRange(
                        start: now,
                        end: now.add(const Duration(days: 1)),
                      ),
                );
                if (picked != null) {
                  setModalState(() => localRange = picked);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.previewSelectionTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.date_range_outlined),
                    title: Text(
                      localRange == null
                          ? t.landingSelectDatesLabel
                          : '${_formatDate(localRange!.start)} → ${_formatDate(localRange!.end)}',
                    ),
                    onTap: pickRange,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.landingGuestsLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setModalState(
                                () => localGuests = (localGuests - 1).clamp(
                                  1,
                                  10,
                                ),
                              );
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$localGuests',
                            style: const TextStyle(fontSize: 16),
                          ),
                          IconButton(
                            onPressed: () {
                              setModalState(
                                () => localGuests = (localGuests + 1).clamp(
                                  1,
                                  10,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: localRange == null
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                                _BookingSelection(localRange!, localGuests),
                              );
                            },
                      child: Text(t.previewContinue),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      context.read<SearchState>().update(
        checkIn: result.range.start,
        checkOut: result.range.end,
        guests: result.guests,
      );
    }

    return result;
  }

  Future<void> _promptStaySelection() async {
    final selection = await _prepareSelection(requireLogin: false);
    if (selection == null || !mounted) return;
    setState(() {
      _activeRange = selection.range;
      _activeGuests = selection.guests;
    });
    await _loadDetails();
  }

  Future<void> _toggleWishlist() async {
    if (_wishlistUpdating) return;

    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.wishlistUpdateLogin),
        ),
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
    Future<bool> syncAndCheck() async {
      await _syncWishlistStatus();
      return (_isWishlisted ?? false) != currentlyWishlisted;
    }

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
            currentlyWishlisted
                ? AppLocalizations.of(context)!.wishlistRemoved
                : AppLocalizations.of(context)!.previewWishlistAdded,
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.wishlistUpdateLogin),
          ),
        );
      } else {
        final synced = await syncAndCheck();
        if (synced && mounted) {
          _wishlistChanged = true;
          context.read<WishlistSync>().notifyChanged();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentlyWishlisted
                    ? AppLocalizations.of(context)!.wishlistRemoved
                    : AppLocalizations.of(context)!.previewWishlistAdded,
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.wishlistUpdateFailed),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Wishlist update failed (non-Dio): $e');
      final synced = await syncAndCheck();
      if (!mounted) return;
      if (synced) {
        _wishlistChanged = true;
        context.read<WishlistSync>().notifyChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyWishlisted
                  ? AppLocalizations.of(context)!.wishlistRemoved
                  : AppLocalizations.of(context)!.previewWishlistAdded,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.wishlistUpdateFailed),
          ),
        );
      }
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
        _reviewsError = AppLocalizations.of(context)!.previewReviewsLoadFailed;
      });
    }
  }

  Future<void> _loadRecommendations() async {
    final auth = context.read<AuthState>();
    if (_recommendedLoading) return;

    if (!auth.isLoggedIn) {
      debugPrint('[Preview] recommendations skipped – not logged in');
      if (!mounted) return;
      setState(() {
        _recommended.clear();
        _recommendedError = null;
        _recommendedLoading = false;
        _recommendedFallback = false;
      });
      return;
    }

    setState(() {
      _recommendedLoading = true;
      _recommendedError = null;
      _recommendedFallback = false;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      var items = await api.getRecommendations(top: 5);

      items = items.where((h) => h.id != widget.hotelId).toList();
      debugPrint('[Preview] recommendations loaded: ${items.length}');

      if (items.length > 5) {
        items = items.take(5).toList();
      }

      if (!mounted) return;
      setState(() {
        _recommended
          ..clear()
          ..addAll(items);
        _recommendedLoading = false;
      });
    } catch (e) {
      debugPrint('Recommendations load failed: $e');
      if (!mounted) return;
      setState(() {
        _recommendedLoading = false;
        _recommendedError = AppLocalizations.of(
          context,
        )!.landingRecommendationsFailed;
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
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, size: 48),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final galleryHeight = (screenWidth * 0.6).clamp(180.0, 260.0) as double;

    return Column(
      children: [
        GestureDetector(
          onTap: () => _openFullScreenGallery(hotel),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: galleryHeight,
              child: PageView.builder(
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() => _currentImageIndex = index);
                },
                itemBuilder: (context, index) {
                  final img = images[index];
                  return Hero(
                    tag: 'hotel-${hotel.id}-image-$index',
                    child: _smartImage(
                      img.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
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
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              width: isActive ? 22 : 8,
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
                                child: _smartImage(
                                  img.url,
                                  fit: BoxFit.contain,
                                  showLoading: false,
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
    final currency = hotel.currency.isNotEmpty ? hotel.currency : '€';
    final t = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Stack(
                  children: [
                    _buildImageGallery(hotel),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _buildWishlistButton(),
                    ),
                  ],
                ),
              ),

              // HOTEL INFO CARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + rating
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              hotel.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final reviewAvg = _reviewsAverage();
                              if (reviewAvg <= 0) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
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
                                  const SizedBox(height: 4),
                                  Text(
                                    t.previewReviewsCount(_reviews.length),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _textMuted,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hotel.city,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_activeRange != null || _activeGuests != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (_activeRange != null)
                              _InfoPill(
                                icon: Icons.calendar_month_outlined,
                                label:
                                    '${_shortDate(_activeRange!.start)} – ${_shortDate(_activeRange!.end)}',
                              ),
                            if (_activeGuests != null)
                              _InfoPill(
                                icon: Icons.person_outline,
                                label: t.previewGuestsCount(_activeGuests!),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // About
                      if (hotel.description != null &&
                          hotel.description!.trim().isNotEmpty) ...[
                        _SectionTitle(t.previewSectionAbout),
                        const SizedBox(height: 6),
                        Text(
                          hotel.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Facilities
                      if (hotel.facilities.isNotEmpty) ...[
                        _SectionTitle(t.previewSectionFacilities),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: hotel.facilities.map((f) {
                            return Chip(
                              label: Text(
                                f.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: _primaryGreen.withOpacity(0.04),
                              labelStyle: const TextStyle(
                                color: _textPrimary,
                                fontSize: 12,
                              ),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Add-ons
                      if (hotel.addOns.isNotEmpty) ...[
                        _SectionTitle(t.previewSectionAddOns),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: hotel.addOns.map((a) {
                            return Chip(
                              label: Text(
                                a.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.blueGrey.withOpacity(
                                0.05,
                              ),
                              labelStyle: const TextStyle(
                                color: _textPrimary,
                                fontSize: 12,
                              ),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // CARD 2: Rooms
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(t.previewRoomsTitle),
                      const SizedBox(height: 8),
                      if (_activeRange == null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.landingSelectDatesLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _promptStaySelection,
                                child: Text(t.landingSelectDatesLabel),
                              ),
                            ),
                          ],
                        )
                      else if (rooms.isEmpty)
                        Text(
                          t.previewNoRooms,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textMuted,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rooms.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
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
              ),

              const SizedBox(height: 18),

              // CARD 3: Reviews (BOTTOM)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _buildReviewsSection(t),
                ),
              ),

              const SizedBox(height: 18),

              // CARD 4: Recommendations
              if (_recommendedLoading ||
                  _recommendedError != null ||
                  _recommended.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _buildRecommendedSection(),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(t.previewReviewsTitle),
        const SizedBox(height: 8),
        if (_reviewsLoading && _reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reviewsError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _reviewsError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => _loadReviews(reset: true),
                child: Text(t.retry),
              ),
            ],
          )
        else if (_reviews.isEmpty)
          Text(
            t.previewReviewsEmpty,
            style: const TextStyle(fontSize: 13, color: _textMuted),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final r = _reviews[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _bgColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildStars(r.rating),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(r.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textMuted,
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
                          color: _textPrimary,
                        ),
                      ),
                    ],
                    if (r.body?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        r.body!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (_reviewsHasMore)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton(
                onPressed: _reviewsLoading ? null : _loadReviews,
                child: _reviewsLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.previewLoadMore),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildRecommendedSection() {
    if (!context.watch<AuthState>().isLoggedIn) {
      return const SizedBox.shrink();
    }

    if (_recommendedLoading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_recommendedError != null || _recommended.isEmpty) {
      return const SizedBox.shrink();
    }

    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(t.landingRecommendedTitle),
        const SizedBox(height: 8),
        SizedBox(
          height: 215,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recommended.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final h = _recommended[index];
              final price = h.promotionPrice ?? h.fromPrice;
              final hasPromo = h.promotionPrice != null;
              final currency = h.currency.isNotEmpty ? h.currency : '€';
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuestHotelPreviewScreen(
                        hotelId: h.id,
                        dateRange: _activeRange,
                        guests: _activeGuests,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child:
                              h.thumbnailUrl == null || h.thumbnailUrl!.isEmpty
                              ? Container(color: Colors.grey.shade200)
                              : _smartImage(
                                  h.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  showLoading: false,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
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
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    h.city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          t.landingFromPrice(
                                            currency,
                                            price.toStringAsFixed(0),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _accentOrange,
                                          ),
                                        ),
                                        if (hasPromo) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            t.landingFromPrice(
                                              currency,
                                              h.fromPrice.toStringAsFixed(0),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: _textMuted,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t.landingPerNight,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                if (h.reviewCount > 0)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        h.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _textPrimary,
                                        ),
                                      ),
                                    ],
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
            },
          ),
        ),
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

  static String _shortDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d.$m';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
            TextButton(onPressed: _loadDetails, child: Text(t.retry)),
          ],
        ),
      );
    } else if (_hotel == null) {
      body = Center(child: Text(t.previewHotelNotFound));
    } else {
      body = RefreshIndicator(
        onRefresh: _loadDetails,
        child: _buildContent(_hotel!),
      );
    }

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          leading: BackButton(
            color: _textPrimary,
            onPressed: () => Navigator.of(context).pop(_wishlistChanged),
          ),
          title: Text(
            _hotel?.name ?? t.previewHeaderFallback,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: body,
      ),
    );
  }
}

Widget _smartImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  bool showLoading = true,
}) {
  final provider = _resolveImageProvider(url);
  final fallback = Container(
    width: width,
    height: height,
    color: Colors.grey.shade200,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );

  if (provider == null) return fallback;

  return Image(
    image: provider,
    width: width,
    height: height,
    fit: fit,
    loadingBuilder: showLoading
        ? (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
              ),
            );
          }
        : null,
    errorBuilder: (context, error, stackTrace) => fallback,
  );
}

ImageProvider? _resolveImageProvider(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http')) return NetworkImage(trimmed);

  final pureBase64 = trimmed.contains(',')
      ? trimmed.split(',').last.trim()
      : trimmed;
  try {
    return MemoryImage(base64Decode(pureBase64));
  } catch (_) {
    return NetworkImage(trimmed);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  static const _textPrimary = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
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
  static const _primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Material(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: room.roomsLeft == 0 ? null : onSelect,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
                child: SizedBox(
                  width: 120,
                  height: 112,
                  child: _buildRoomImage(),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        room.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Capacity + bed
                      Row(
                        children: [
                          ..._buildCapacityIcons(),
                          if (room.bedType != null &&
                              room.bedType!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.bed_outlined,
                              size: 14,
                              color: _textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                room.bedType!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Tags
                      Row(
                        children: [
                          if (room.isSmokingAllowed == false)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _primaryGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                t.previewNonSmoking,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryGreen,
                                ),
                              ),
                            ),
                          if (room.roomsLeft > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              room.roomsLeft <= 3
                                  ? t.previewRoomsLeftFew(room.roomsLeft)
                                  : t.previewRoomsLeft(room.roomsLeft),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: room.roomsLeft <= 3
                                    ? Colors.redAccent
                                    : _textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Price + button
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '$currency ${room.priceFromPerNight.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: _accentOrange,
                                      ),
                                    ),
                                    if (room.originalNightlyPrice != null &&
                                        room.originalNightlyPrice! >
                                            room.priceFromPerNight)
                                      Text(
                                        '$currency ${room.originalNightlyPrice!.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _textMuted,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.landingPerNight,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                  ),
                                ),
                                if (room.promotionTitle != null &&
                                    room.promotionTitle!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      room.promotionTitle!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: room.roomsLeft == 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        t.previewRoomUnavailable,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _textMuted,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      onPressed: onSelect,
                                      child: Text(
                                        t.previewSelect,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomImage() {
    final url =
        room.thumbnailUrl ??
        (room.imageUrls.isNotEmpty ? room.imageUrls.first : null);
    if (url == null || url.isEmpty) {
      return Container(color: Colors.grey.shade200);
    }
    return _smartImage(url, fit: BoxFit.cover, showLoading: false);
  }

  List<Widget> _buildCapacityIcons() {
    final count = room.capacity.clamp(1, 6);
    return List.generate(
      count,
      (_) => const Padding(
        padding: EdgeInsets.only(right: 2),
        child: Icon(Icons.person, size: 14, color: _textMuted),
      ),
    );
  }
}

class _BookingSelection {
  final DateTimeRange range;
  final int guests;
  _BookingSelection(this.range, this.guests);
}
