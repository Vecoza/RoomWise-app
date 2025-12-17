import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/city_dto.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/core/models/tag_dto.dart';
import 'package:roomwise/core/search/search_state.dart';
import 'package:roomwise/features/guest_hotel/presentation/screens/guest_hotel_preview_screen.dart';
import 'package:roomwise/features/guest_search/domain/guest_search_filters.dart';
import 'package:roomwise/features/guest_search/presentation/screens/guest_filters_screen.dart';
import 'package:roomwise/features/guest_search/presentation/screens/hotel_search_screen.dart';
import 'package:roomwise/features/guest_search/presentation/screens/search_results_screen.dart';
import 'package:roomwise/features/hot_deals/presentation/screens/hot_deals_screen.dart';

class GuestLandingScreen extends StatefulWidget {
  const GuestLandingScreen({super.key});

  @override
  State<GuestLandingScreen> createState() => _GuestLandingScreenState();
}

class _GuestLandingScreenState extends State<GuestLandingScreen> {
  // --- DESIGN TOKENS ---
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
  List<TagDto> _tags = [];
  bool _tagsLoading = false;
  bool _recommendedLoading = false;
  String? _recommendedError;

  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _selectedRange;
  int _guests = 2;

  @override
  void initState() {
    super.initState();
    _loadLandingData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLandingData() async {
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

      // Recommendations only for logged-in users
      await _loadRecommendations();
    } catch (e) {
      debugPrint('Landing data load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadRecommendations() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      if (_recommended.isNotEmpty || _recommendedError != null) {
        setState(() {
          _recommended = [];
          _recommendedError = null;
          _recommendedLoading = false;
        });
      }
      return;
    }

    setState(() {
      _recommendedLoading = true;
      _recommendedError = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      final items = await api.getRecommendations(top: 5);
      if (!mounted) return;
      setState(() {
        _recommended = items;
        _recommendedLoading = false;
      });
    } catch (e) {
      debugPrint('Recommendations load failed: $e');
      if (!mounted) return;
      setState(() {
        _recommendedLoading = false;
        _recommendedError = 'Could not load recommendations.';
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial =
        _selectedRange ??
        DateTimeRange(start: now, end: now.add(const Duration(days: 1)));

    final picked = await showDateRangePicker(
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

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  void _changeGuests(int delta) {
    setState(() {
      _guests = (_guests + delta).clamp(1, 10);
    });
  }

  void _onSearchPressed() {
    debugPrint(
      '[Landing] search pressed, range=$_selectedRange, guests=$_guests',
    );

    if (_selectedRange == null) {
      debugPrint('[Landing] search aborted – no date range selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select dates first.')),
      );
      return;
    }

    if (_guests <= 0) {
      debugPrint('[Landing] search aborted – invalid guests: $_guests');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set number of guests.')),
      );
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
            TextButton(onPressed: _loadLandingData, child: const Text('Retry')),
          ],
        ),
      );
    } else {
      body = _buildContent();
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(child: body),
    );
  }

  // ---------- MAIN CONTENT WITH HERO ----------

  Widget _buildContent() {
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
                      height: 320, // total area: hero + overlapping card
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Green hero background
                          Positioned.fill(
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                18,
                                horizontalPadding,
                                10, // enough bottom padding so text is fully visible
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
                                children: const [
                                  SizedBox(height: 4),
                                  Text(
                                    'Roomwise',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Find your next stay',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Smart search for hotels across Bosnia & Herzegovina.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Floating search card (overlaps bottom of hero + white background)
                          Positioned(
                            left: horizontalPadding,
                            right: horizontalPadding,
                            bottom: 15,
                            child: _buildSearchCard(),
                          ),
                        ],
                      ),
                    ),

                    // Small gap after the hero/card
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
                          _buildExploreSection(),
                          const SizedBox(height: 24),
                          _buildHotDealsSection(),
                          const SizedBox(height: 24),
                          _buildRecommendedSection(),
                          const SizedBox(height: 24),
                          if (_tags.isNotEmpty) _buildTagsSection(),
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

  Widget _buildSearchCard() {
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
                hintText: 'Search by hotel or city',
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
                                  ? 'Select dates'
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
                              const Text(
                                'Guests',
                                style: TextStyle(
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
                      child: const Text(
                        'Search stays',
                        style: TextStyle(
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

                      final filters = await Navigator.push<GuestSearchFilters>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GuestFiltersScreen(
                            baseDateRange: _selectedRange,
                            baseGuests: _selectedRange == null ? null : _guests,
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

  Widget _buildExploreSection() {
    final cities = _orderedCities();
    if (cities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Explore places',
          caption: 'Popular cities other guests are booking.',
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
                        dateRange: _selectedRange,
                        guests: _selectedRange == null ? null : _guests,
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

  Widget _buildHotDealsSection() {
    if (_hotDeals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Hot deals',
          caption: 'Limited-time discounts from top stays.',
          trailing: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HotDealsScreen()),
              );
            },
            child: const Text(
              'See all',
              style: TextStyle(
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
                dateRange: _selectedRange,
                guests: _selectedRange == null ? null : _guests,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedSection() {
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final fallback = _recommended.isEmpty ? _hotDeals : _recommended;
    final caption = isLoggedIn
        ? 'Based on your wishlist and bookings.'
        : 'Sign in to get personalized picks.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Recommended for you',
          caption: caption,
        ),
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
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (fallback.isEmpty)
          const Center(
            child: Text(
              'No picks yet. Try searching to get suggestions.',
              style: TextStyle(color: _textMuted),
            ),
          )
        else ...[
          if (_recommended.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Showing popular deals for now.',
                style: TextStyle(fontSize: 12, color: _textMuted),
              ),
            ),
          SizedBox(
            height: 245,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fallback.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final hotel = fallback[index];
                return _RecommendedCard(
                  hotel: hotel,
                  dateRange: _selectedRange,
                  guests: _selectedRange == null ? null : _guests,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ---------- TAGS / THEME HOTELS ----------

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Theme hotels',
          caption: 'Pick by vibe: business, spa, romantic...',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Quick picks',
              style: TextStyle(
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

    // If backend returns more cities, you can append them here if needed.
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

  const _HotDealCard({required this.hotel, this.dateRange, this.guests});

  static const _accentOrange = Color(0xFFFF7A3C);
  static const _primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final hasPromo = hotel.promotionPrice != null && hotel.promotionPrice! > 0;
    final currency = hotel.currency.isNotEmpty ? hotel.currency : '€';
    final dealPrice = hasPromo ? hotel.promotionPrice! : hotel.fromPrice;
    final badgeText = hotel.promotionTitle?.isNotEmpty == true
        ? hotel.promotionTitle!
        : 'Hot deal';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestHotelPreviewScreen(
              hotelId: hotel.id,
              dateRange: dateRange,
              guests: guests,
            ),
          ),
        );
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
                            'From $currency ${dealPrice.toStringAsFixed(0)}',
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
                        const Text(
                          'Limited offer',
                          style: TextStyle(fontSize: 10, color: _textMuted),
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

  const _RecommendedCard({required this.hotel, this.dateRange, this.guests});

  static const _primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    final price = hotel.promotionPrice ?? hotel.fromPrice;
    final hasPromo = hotel.promotionPrice != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestHotelPreviewScreen(
              hotelId: hotel.id,
              dateRange: dateRange,
              guests: guests,
            ),
          ),
        );
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
                    child: const Text(
                      'For you',
                      style: TextStyle(
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
                                'From €${price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _accentOrange,
                                ),
                              ),
                              if (hasPromo) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '€${hotel.fromPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'per night',
                            style: TextStyle(fontSize: 11, color: _textMuted),
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
            const Text(
              'Tap to view hotels',
              style: TextStyle(fontSize: 11, color: _textMuted),
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
        _error = 'Failed to load hotels for this category.';
      });
    }
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
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_hotels.isEmpty) {
      body = const Center(
        child: Text(
          'No hotels found for this category.',
          style: TextStyle(color: _textMuted),
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
