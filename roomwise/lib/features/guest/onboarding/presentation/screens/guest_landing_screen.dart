import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/app/roomwise_app.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/city_dto.dart';
import 'package:roomwise/core/models/hotel_details_dto.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/core/models/tag_dto.dart';
import 'package:roomwise/core/search/search_state.dart';
import 'package:roomwise/features/guest/guest_hotel/presentation/screens/guest_hotel_preview_screen.dart';
import 'package:roomwise/features/guest/guest_search/domain/guest_search_filters.dart';
import 'package:roomwise/features/guest/guest_search/presentation/screens/guest_filters_screen.dart';
import 'package:roomwise/features/guest/guest_search/presentation/screens/hotel_search_screen.dart';
import 'package:roomwise/features/guest/guest_search/presentation/screens/search_results_screen.dart';
import 'package:roomwise/features/guest/hot_deals/presentation/screens/hot_deals_screen.dart';
import 'package:roomwise/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class GuestLandingScreen extends StatefulWidget {
  const GuestLandingScreen({super.key});

  @override
  State<GuestLandingScreen> createState() => _GuestLandingScreenState();
}

class _GuestLandingScreenState extends State<GuestLandingScreen>
    with RouteAware {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _cardColor = Colors.white;
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const double _cardRadius = 18;
  static const double _cardPadding = 14;

  bool _loading = true;
  String? _error;

  List<CityDto> _cities = [];
  List<HotelSearchItemDto> _hotDeals = [];
  List<HotelSearchItemDto> _recommended = [];
  List<HotelSearchItemDto> _recentlyViewed = [];
  List<TagDto> _tags = [];
  bool _tagsLoading = false;
  bool _recommendedLoading = false;
  String? _recommendedError;
  bool _recentlyViewedLoading = false;
  String? _recentlyViewedError;
  String? _lastAuthToken;
  bool _routeSubscribed = false;
  bool _priceRefreshInFlight = false;

  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _selectedRange;
  int _guests = 2;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    roomWiseRouteObserver.unsubscribe(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeSubscribed && route is PageRoute) {
      roomWiseRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
    _syncSelectionFromSearchState();

    final authToken = context.read<AuthState>().token;
    if (authToken != _lastAuthToken) {
      _lastAuthToken = authToken;
      if (!_loading && _cities.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadRecommendations();
            _loadRecentlyViewed();
          }
        });
      }
    }

    if (!_loading && _cities.isNotEmpty) return;
    _loadLandingData();
  }

  @override
  void didPopNext() {
    _syncSelectionFromSearchState();
    _loadRecentlyViewed();
  }

  Future<void> _loadLandingData() async {
    final t = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();

      final results = await Future.wait<dynamic>([
        api.getCities(),
        api.getHotDeals(),
        api.getTags(),
      ]);

      if (!mounted) return;
      setState(() {
        _cities = results[0] as List<CityDto>;
        _hotDeals = results[1] as List<HotelSearchItemDto>;
        _tags = results[2] as List<TagDto>;
        _loading = false;
      });
      await _refreshLandingPrices();

      await _loadRecommendations();
      await _loadRecentlyViewed();
    } catch (e) {
      debugPrint('Landing data load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = t.landingLoadFailed;
        _loading = false;
      });
    }
  }

  Future<void> _loadRecentlyViewed() async {
    final auth = context.read<AuthState>();
    if (_recentlyViewedLoading) return;
    if (!auth.isLoggedIn || (auth.email == null || auth.email!.isEmpty)) {
      if (!mounted) return;
      setState(() {
        _recentlyViewed = [];
        _recentlyViewedError = null;
        _recentlyViewedLoading = false;
      });
      return;
    }

    setState(() {
      _recentlyViewedLoading = true;
      _recentlyViewedError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _recentlyViewedKey(auth.email!);
      final ids = prefs.getStringList(key) ?? const [];
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _recentlyViewed = [];
          _recentlyViewedLoading = false;
        });
        return;
      }

      final api = context.read<RoomWiseApiClient>();
      final parsed = ids.map(int.tryParse).whereType<int>().toList();
      final range = _currentRange();
      final guests = _currentGuests(range);
      final details = await Future.wait<HotelDetailsDto>(
        parsed.map(
          (id) => api.getHotelDetails(
            hotelId: id,
            checkIn: range?.start,
            checkOut: range?.end,
            guests: guests,
          ),
        ),
      );

      final useBasePrice = range == null;
      final items = details
          .map(
            (detail) =>
                _mapDetailsToSearchItem(detail, preferBasePrice: useBasePrice),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _recentlyViewed = items;
        _recentlyViewedLoading = false;
      });
    } catch (e) {
      debugPrint('Recently viewed load failed: $e');
      if (!mounted) return;
      setState(() {
        _recentlyViewedLoading = false;
        _recentlyViewedError = AppLocalizations.of(
          context,
        )!.landingRecentLoadFailed;
      });
    }
  }

  String _recentlyViewedKey(String email) {
    return 'recently_viewed_${email.toLowerCase()}';
  }

  HotelSearchItemDto _mapDetailsToSearchItem(
    HotelDetailsDto details, {
    bool preferBasePrice = false,
  }) {
    double minPrice = 0;
    if (details.availableRoomTypes.isNotEmpty) {
      minPrice = details.availableRoomTypes
          .map((r) {
            final base = r.basePrice;
            if (preferBasePrice && base != null && base > 0) return base;
            return r.priceFromPerNight;
          })
          .reduce(min);
    }

    final thumb =
        details.heroImageUrl ??
        (details.galleryUrls.isNotEmpty ? details.galleryUrls.first : null);

    return HotelSearchItemDto(
      id: details.id,
      name: details.name,
      city: details.city,
      fromPrice: minPrice,
      rating: details.rating,
      reviewCount: 0,
      thumbnailUrl: thumb,
      hasAvailability: details.availableRoomTypes.isNotEmpty,
      tags: details.tags,
      currency: details.currency,
    );
  }

  HotelSearchItemDto _copyWithPrice(HotelSearchItemDto hotel, double price) {
    return HotelSearchItemDto(
      id: hotel.id,
      name: hotel.name,
      city: hotel.city,
      fromPrice: price,
      rating: hotel.rating,
      hasAvailability: hotel.hasAvailability,
      reviewCount: hotel.reviewCount,
      promotionPrice: hotel.promotionPrice,
      promotionDiscountPercent: hotel.promotionDiscountPercent,
      promotionDiscountFixed: hotel.promotionDiscountFixed,
      promotionEndDate: hotel.promotionEndDate,
      promotionTitle: hotel.promotionTitle,
      currency: hotel.currency,
      thumbnailUrl: hotel.thumbnailUrl,
      tags: hotel.tags,
    );
  }

  Future<List<HotelSearchItemDto>> _applyDateAwarePrices(
    List<HotelSearchItemDto> hotels,
    DateTimeRange range,
    int guests,
  ) async {
    if (hotels.isEmpty) return hotels;
    final api = context.read<RoomWiseApiClient>();
    final tasks = hotels.map((hotel) async {
      try {
        final details = await api.getHotelDetails(
          hotelId: hotel.id,
          checkIn: range.start,
          checkOut: range.end,
          guests: guests,
        );
        if (details.availableRoomTypes.isEmpty) return hotel;
        final price = details.availableRoomTypes
            .map((r) => r.priceFromPerNight)
            .reduce(min);
        return _copyWithPrice(hotel, price);
      } catch (e) {
        debugPrint('Landing price refresh failed for ${hotel.id}: $e');
        return hotel;
      }
    }).toList();

    return Future.wait(tasks);
  }

  Future<List<HotelSearchItemDto>> _applyBasePrices(
    List<HotelSearchItemDto> hotels,
  ) async {
    if (hotels.isEmpty) return hotels;
    final api = context.read<RoomWiseApiClient>();
    final tasks = hotels.map((hotel) async {
      try {
        final details = await api.getHotelDetails(hotelId: hotel.id);
        if (details.availableRoomTypes.isEmpty) return hotel;
        final price = details.availableRoomTypes
            .map((r) {
              final base = r.basePrice;
              if (base != null && base > 0) return base;
              return r.priceFromPerNight;
            })
            .reduce(min);
        return _copyWithPrice(hotel, price);
      } catch (e) {
        debugPrint('Landing base price refresh failed for ${hotel.id}: $e');
        return hotel;
      }
    }).toList();

    return Future.wait(tasks);
  }

  Future<void> _refreshLandingPrices() async {
    if (_priceRefreshInFlight) return;
    _priceRefreshInFlight = true;
    final range = _currentRange();
    try {
      if (range == null) {
        final results = await Future.wait<List<HotelSearchItemDto>>([
          _applyBasePrices(_hotDeals),
          _applyBasePrices(_recommended),
        ]);

        if (!mounted) return;
        setState(() {
          _hotDeals = results[0];
          _recommended = results[1];
        });
        return;
      }

      final guests = _currentGuests(range) ?? 1;

      final results = await Future.wait<List<HotelSearchItemDto>>([
        _applyDateAwarePrices(_hotDeals, range, guests),
        _applyDateAwarePrices(_recommended, range, guests),
      ]);

      if (!mounted) return;
      setState(() {
        _hotDeals = results[0];
        _recommended = results[1];
      });
    } finally {
      _priceRefreshInFlight = false;
    }
  }

  Future<void> _loadRecommendations() async {
    final auth = context.read<AuthState>();
    if (_recommendedLoading) return;
    if (!auth.isLoggedIn) {
      debugPrint('[Landing] recommendations skipped – not logged in');
      if (!mounted) return;
      setState(() {
        _recommended = [];
        _recommendedError = null;
        _recommendedLoading = false;
      });
      return;
    }

    setState(() {
      _recommendedLoading = true;
      _recommendedError = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      final items = await api.getRecommendations(top: 5);
      debugPrint('[Landing] recommendations loaded: ${items.length}');
      if (!mounted) return;
      setState(() {
        _recommended = items;
        _recommendedLoading = false;
      });
      await _refreshLandingPrices();
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

  Future<DateTimeRange?> _selectDateRange() async {
    final now = DateTime.now();
    final initial =
        _selectedRange ??
        DateTimeRange(start: now, end: now.add(const Duration(days: 1)));

    return showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: _primaryGreen),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _applySelectedRange(DateTimeRange picked) async {
    setState(() {
      _selectedRange = picked;
    });
    try {
      context.read<SearchState>().update(
        checkIn: picked.start,
        checkOut: picked.end,
        guests: _guests,
      );
    } catch (e) {
      debugPrint('[Landing] SearchState update failed: $e');
    }
    await _refreshLandingPrices();
    await _loadRecentlyViewed();
  }

  Future<void> _pickDateRange() async {
    final picked = await _selectDateRange();
    if (picked == null) return;
    await _applySelectedRange(picked);
  }

  void _changeGuests(int delta) {
    setState(() {
      _guests = (_guests + delta).clamp(1, 10);
    });
    final range = _selectedRange;
    if (range == null) return;
    try {
      context.read<SearchState>().update(
        checkIn: range.start,
        checkOut: range.end,
        guests: _guests,
      );
    } catch (e) {
      debugPrint('[Landing] SearchState update failed: $e');
    }
  }

  void _syncSelectionFromSearchState() {
    final search = context.read<SearchState>();
    if (search.checkIn == null || search.checkOut == null) return;
    final nextRange = DateTimeRange(
      start: search.checkIn!,
      end: search.checkOut!,
    );
    final nextGuests = search.guests?.clamp(1, 10);

    if (_selectedRange == null ||
        _selectedRange!.start != nextRange.start ||
        _selectedRange!.end != nextRange.end ||
        (nextGuests != null && _guests != nextGuests)) {
      setState(() {
        _selectedRange = nextRange;
        if (nextGuests != null) {
          _guests = nextGuests;
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshLandingPrices();
        _loadRecentlyViewed();
      });
    }
  }

  DateTimeRange? _currentRange() {
    if (_selectedRange != null) return _selectedRange;
    final search = context.read<SearchState>();
    if (search.checkIn == null || search.checkOut == null) return null;
    return DateTimeRange(start: search.checkIn!, end: search.checkOut!);
  }

  int? _currentGuests(DateTimeRange? range) {
    if (range == null) return null;
    if (_selectedRange != null) return _guests;
    final search = context.read<SearchState>();
    return (search.guests ?? _guests).clamp(1, 10);
  }

  Future<void> _openHotelFromLanding(
    HotelSearchItemDto hotel, {
    VoidCallback? onReturn,
  }) async {
    var range = _currentRange();
    if (range == null) {
      final picked = await _selectDateRange();
      if (picked == null) return;
      await _applySelectedRange(picked);
      range = picked;
    }
    final guests = _currentGuests(range) ?? _guests;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestHotelPreviewScreen(
          hotelId: hotel.id,
          dateRange: range,
          guests: guests,
        ),
      ),
    );

    if (!mounted) return;
    onReturn?.call();
  }

  void _onSearchPressed() {
    final t = AppLocalizations.of(context)!;
    debugPrint(
      '[Landing] search pressed, range=$_selectedRange, guests=$_guests',
    );

    if (_selectedRange == null) {
      debugPrint('[Landing] search aborted – no date range selected');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.landingSnackSelectDates)));
      return;
    }

    if (_guests <= 0) {
      debugPrint('[Landing] search aborted – invalid guests: $_guests');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.landingSnackGuests)));
      return;
    }

    try {
      final searchState = context.read<SearchState>();
      searchState.update(
        checkIn: _selectedRange!.start,
        checkOut: _selectedRange!.end,
        guests: _guests,
      );
      debugPrint('[Landing] SearchState updated successfully');
    } catch (e, st) {
      debugPrint('[Landing] SearchState not available: $e\n$st');
    }

    debugPrint('[Landing] pushing SearchResultsScreen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          query: _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
          dateRange: _selectedRange,
          guests: _guests,
        ),
      ),
    );
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
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadLandingData, child: Text(t.retry)),
          ],
        ),
      );
    } else {
      body = _buildContent(t);
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(child: body),
    );
  }

  // ---------- MAIN CONTENT WITH HERO ----------

  Widget _buildContent(AppLocalizations t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final horizontalPadding = maxWidth > 600 ? 24.0 : 16.0;

        return RefreshIndicator(
          onRefresh: _loadLandingData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP HERO + SEARCH STACK
                    SizedBox(
                      height: 320,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                18,
                                horizontalPadding,
                                10,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF05A87A),
                                    Color(0xFF1FB59E),
                                  ],
                                ),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(28),
                                  bottomRight: Radius.circular(28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    t.appTitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    t.landingHeroTitle,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.landingHeroSubtitle,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            left: horizontalPadding,
                            right: horizontalPadding,
                            bottom: 15,
                            child: _buildSearchCard(t),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // BODY SECTIONS
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildExploreSection(t),
                          const SizedBox(height: 24),
                          _buildRecentlyViewedSection(t),
                          const SizedBox(height: 24),
                          _buildHotDealsSection(t),
                          const SizedBox(height: 24),
                          _buildRecommendedSection(t),
                          const SizedBox(height: 24),
                          if (_tags.isNotEmpty) _buildTagsSection(t),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- SEARCH CARD ----------

  Widget _buildSearchCard(AppLocalizations t) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(_cardRadius),
      color: _cardColor,
      child: Container(
        padding: const EdgeInsets.all(_cardPadding),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Column(
          children: [
            // search
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: t.landingSearchHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
              ),
              onSubmitted: (_) => _onSearchPressed(),
            ),
            const SizedBox(height: 10),

            // date & guests
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.date_range_outlined,
                              size: 18,
                              color: _textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedRange == null
                                  ? t.landingSelectDatesLabel
                                  : '${_formatDate(_selectedRange!.start)} - ${_formatDate(_selectedRange!.end)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _changeGuests(-1),
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.remove, size: 18),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_guests',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                t.landingGuestsLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _changeGuests(1),
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.add, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // search + filter
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _onSearchPressed,
                      child: Text(
                        t.landingSearchButton,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: InkWell(
                    onTap: () async {
                      debugPrint('[Landing] filter button tapped');
                      final range = _currentRange();
                      final guests = _currentGuests(range);

                      final filters = await Navigator.push<GuestSearchFilters>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GuestFiltersScreen(
                            baseDateRange: range,
                            baseGuests: guests,
                            baseCityName: _searchCtrl.text.trim().isEmpty
                                ? null
                                : _searchCtrl.text.trim(),
                          ),
                        ),
                      );

                      debugPrint('[Landing] filter result: $filters');

                      if (filters != null) {
                        debugPrint(
                          '[Landing] pushing SearchResultsScreen from filters',
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchResultsScreen(
                              query: _searchCtrl.text.trim().isEmpty
                                  ? null
                                  : _searchCtrl.text.trim(),
                              initialFilters: filters,
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: _primaryGreen,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- EXPLORE PLACES ----------

  Widget _buildExploreSection(AppLocalizations t) {
    final cities = _orderedCities();
    if (cities.isEmpty) return const SizedBox.shrink();
    final range = _currentRange();
    final guests = _currentGuests(range);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: t.landingExploreTitle,
          caption: t.landingExploreCaption,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final city = cities[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HotelSearchScreen(
                        city: city,
                        dateRange: range,
                        guests: guests,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: _primaryGreen,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        city.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        city.countryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _textMuted),
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

  // ---------- HOT DEALS ----------

  Widget _buildHotDealsSection(AppLocalizations t) {
    if (_hotDeals.isEmpty) return const SizedBox.shrink();
    final range = _currentRange();
    final guests = _currentGuests(range);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: t.landingHotDealsTitle,
          caption: t.landingHotDealsCaption,
          trailing: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HotDealsScreen()),
              );
            },
            child: Text(
              t.landingSeeAll,
              style: const TextStyle(
                fontSize: 12,
                color: _accentOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 245,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _hotDeals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final hotel = _hotDeals[index];
              return _HotDealCard(
                hotel: hotel,
                dateRange: range,
                guests: guests,
                onReturn: _loadRecentlyViewed,
                onOpen: () =>
                    _openHotelFromLanding(hotel, onReturn: _loadRecentlyViewed),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyViewedSection(AppLocalizations t) {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      return const SizedBox.shrink();
    }
    final range = _currentRange();
    final guests = _currentGuests(range);

    if (_recentlyViewedLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: t.landingRecentTitle,
            caption: t.landingRecentCaption,
          ),
          const SizedBox(height: 10),
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }

    if (_recentlyViewedError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: t.landingRecentTitle,
            caption: t.landingRecentCaption,
          ),
          const SizedBox(height: 8),
          Text(
            _recentlyViewedError!,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
      );
    }

    if (_recentlyViewed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: t.landingRecentTitle,
          caption: t.landingRecentCaption,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 245,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentlyViewed.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final hotel = _recentlyViewed[index];
              return _RecentlyViewedCard(
                hotel: hotel,
                dateRange: range,
                guests: guests,
                onReturn: _loadRecentlyViewed,
                onOpen: () =>
                    _openHotelFromLanding(hotel, onReturn: _loadRecentlyViewed),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedSection(AppLocalizations t) {
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;
    if (!isLoggedIn) return const SizedBox.shrink();
    final range = _currentRange();
    final guests = _currentGuests(range);

    final caption = t.landingRecommendedCaption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title: t.landingRecommendedTitle, caption: caption),
        const SizedBox(height: 10),
        if (_recommendedLoading)
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_recommendedError != null && _recommended.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _recommendedError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                TextButton(
                  onPressed: _loadRecommendations,
                  child: Text(t.retry),
                ),
              ],
            ),
          )
        else if (_recommended.isEmpty)
          Center(
            child: Text(
              t.landingRecommendedEmpty,
              style: const TextStyle(color: _textMuted),
            ),
          )
        else ...[
          SizedBox(
            height: 245,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recommended.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final hotel = _recommended[index];
                return _RecommendedCard(
                  hotel: hotel,
                  dateRange: range,
                  guests: guests,
                  onReturn: _loadRecentlyViewed,
                  onOpen: () => _openHotelFromLanding(
                    hotel,
                    onReturn: _loadRecentlyViewed,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ---------- TAGS / THEME HOTELS ----------

  Widget _buildTagsSection(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: t.landingThemeTitle,
          caption: t.landingThemeCaption,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              t.landingQuickPicks,
              style: const TextStyle(
                fontSize: 11,
                color: _accentOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: _tagsLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    return _TagCard(tag: tag, onTap: () => _openTag(tag));
                  },
                ),
        ),
      ],
    );
  }

  // ---------- HELPERS ----------

  Widget _sectionHeader({
    required String title,
    String? caption,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(fontSize: 11, color: _textMuted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  List<CityDto> _orderedCities() {
    const order = [
      'Sarajevo',
      'Banja Luka',
      'Tuzla',
      'Zenica',
      'Mostar',
      'Bijeljina',
      'Brcko',
    ];

    final map = {for (var c in _cities) c.name: c};
    final result = <CityDto>[];

    for (final name in order) {
      final city = map[name];
      if (city != null) result.add(city);
    }

    return result;
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

  void _openTag(TagDto tag) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TagHotelsScreen(tag: tag)),
    );
  }
}

// ---------- HOT DEAL CARD ----------

class _HotDealCard extends StatelessWidget {
  final HotelSearchItemDto hotel;
  final DateTimeRange? dateRange;
  final int? guests;
  final VoidCallback? onReturn;
  final Future<void> Function()? onOpen;

  const _HotDealCard({
    required this.hotel,
    this.dateRange,
    this.guests,
    this.onReturn,
    this.onOpen,
  });

  static const _accentOrange = Color(0xFFFF7A3C);
  static const _primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasPromo = hotel.promotionPrice != null && hotel.promotionPrice! > 0;
    final currency = hotel.currency.isNotEmpty ? hotel.currency : '€';
    final dealPrice = hasPromo ? hotel.promotionPrice! : hotel.fromPrice;
    final badgeText = hotel.promotionTitle?.isNotEmpty == true
        ? hotel.promotionTitle!
        : t.landingHotDealBadge;

    return GestureDetector(
      onTap: () async {
        if (onOpen != null) {
          await onOpen!.call();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestHotelPreviewScreen(
              hotelId: hotel.id,
              dateRange: dateRange,
              guests: guests,
            ),
          ),
        ).then((_) => onReturn?.call());
      },
      child: Container(
        width: 200,
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
            // image + badge
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
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _accentOrange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          hotel.city,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            t.landingFromPrice(
                              currency,
                              dealPrice.toStringAsFixed(0),
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
                              '$currency ${hotel.fromPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (hasPromo)
                        Text(
                          t.landingLimitedOffer,
                          style: const TextStyle(
                            fontSize: 10,
                            color: _textMuted,
                          ),
                        ),
                      const SizedBox(height: 6),
                      if (hotel.reviewCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F7F1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                hotel.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${hotel.reviewCount})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textMuted,
                                ),
                              ),
                            ],
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

class _RecommendedCard extends StatelessWidget {
  final HotelSearchItemDto hotel;
  final DateTimeRange? dateRange;
  final int? guests;
  final VoidCallback? onReturn;
  final Future<void> Function()? onOpen;

  const _RecommendedCard({
    required this.hotel,
    this.dateRange,
    this.guests,
    this.onReturn,
    this.onOpen,
  });

  static const _primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final price = hotel.promotionPrice ?? hotel.fromPrice;
    final hasPromo = hotel.promotionPrice != null;
    final currency = hotel.currency.isNotEmpty ? hotel.currency : '€';

    return GestureDetector(
      onTap: () async {
        if (onOpen != null) {
          await onOpen!.call();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestHotelPreviewScreen(
              hotelId: hotel.id,
              dateRange: dateRange,
              guests: guests,
            ),
          ),
        ).then((_) => onReturn?.call());
      },
      child: Container(
        width: 200,
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
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      t.landingForYouBadge,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          hotel.city,
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
                                    hotel.fromPrice.toStringAsFixed(0),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                    decoration: TextDecoration.lineThrough,
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
                      if (hotel.reviewCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F7F1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                hotel.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${hotel.reviewCount})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textMuted,
                                ),
                              ),
                            ],
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

class _RecentlyViewedCard extends StatelessWidget {
  final HotelSearchItemDto hotel;
  final DateTimeRange? dateRange;
  final int? guests;
  final VoidCallback? onReturn;
  final Future<void> Function()? onOpen;

  const _RecentlyViewedCard({
    required this.hotel,
    this.dateRange,
    this.guests,
    this.onReturn,
    this.onOpen,
  });

  static const _primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final price = hotel.promotionPrice ?? hotel.fromPrice;
    final hasPromo = hotel.promotionPrice != null;
    final currency = hotel.currency.isNotEmpty ? hotel.currency : '€';

    return GestureDetector(
      onTap: () async {
        if (onOpen != null) {
          await onOpen!.call();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestHotelPreviewScreen(
              hotelId: hotel.id,
              dateRange: dateRange,
              guests: guests,
            ),
          ),
        ).then((_) => onReturn?.call());
      },
      child: Container(
        width: 200,
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
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      t.landingRecentBadge,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          hotel.city,
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
                                    hotel.fromPrice.toStringAsFixed(0),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                    decoration: TextDecoration.lineThrough,
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
                      if (hotel.reviewCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F7F1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                hotel.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${hotel.reviewCount})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textMuted,
                                ),
                              ),
                            ],
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
// ---------- TAG CARD ----------

class _TagCard extends StatelessWidget {
  final TagDto tag;
  final VoidCallback onTap;

  const _TagCard({required this.tag, required this.onTap});

  static const primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: primaryGreen.withOpacity(0.12),
              foregroundColor: primaryGreen,
              child: Icon(_iconFor(tag.name), size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              tag.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.landingTagCTA,
              style: const TextStyle(fontSize: 11, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('business')) return Icons.business_center;
    if (lower.contains('family')) return Icons.family_restroom;
    if (lower.contains('spa')) return Icons.spa;
    if (lower.contains('beach')) return Icons.beach_access;
    if (lower.contains('romantic') || lower.contains('couple')) {
      return Icons.favorite_border;
    }
    return Icons.local_hotel_outlined;
  }
}

// ---------- TAG HOTELS SCREEN ----------

class _TagHotelsScreen extends StatefulWidget {
  final TagDto tag;

  const _TagHotelsScreen({required this.tag});

  @override
  State<_TagHotelsScreen> createState() => _TagHotelsScreenState();
}

class _TagHotelsScreenState extends State<_TagHotelsScreen> {
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF5F7FA);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _loading = true;
  String? _error;
  List<HotelSearchItemDto> _hotels = [];

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
    try {
      final api = context.read<RoomWiseApiClient>();
      final hotels = await api.getHotelsByTag(
        widget.tag.id,
        tagName: widget.tag.name,
      );
      if (!mounted) return;
      setState(() {
        _hotels = hotels;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Tag hotels load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.landingTagLoadFailed;
      });
    }
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
            TextButton(onPressed: _load, child: Text(t.retry)),
          ],
        ),
      );
    } else if (_hotels.isEmpty) {
      body = Center(
        child: Text(
          t.landingTagNoHotels,
          style: const TextStyle(color: _textMuted),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _hotels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final hotel = _hotels[index];
          final thumb = hotel.thumbnailUrl;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuestHotelPreviewScreen(hotelId: hotel.id),
                  ),
                );
              },
              leading: SizedBox(
                width: 64,
                height: 64,
                child: thumb == null || thumb.isEmpty
                    ? Container(color: Colors.grey.shade200)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(thumb, fit: BoxFit.cover),
                      ),
              ),
              title: Text(
                hotel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              subtitle: Text(
                hotel.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _textMuted),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '€${hotel.fromPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _accentOrange,
                    ),
                  ),
                  if (hotel.reviewCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          hotel.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${hotel.reviewCount})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(title: Text(widget.tag.name)),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
