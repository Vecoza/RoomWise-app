import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/city_dto.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/core/models/tag_dto.dart';
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
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);

  bool _loading = true;
  String? _error;

  List<CityDto> _cities = [];
  List<HotelSearchItemDto> _hotDeals = [];
  List<TagDto> _tags = [];
  bool _tagsLoading = false;

  // --- search state (top of Explore) ---
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
    } catch (e) {
      debugPrint('Landing data load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data. Please try again.';
        _loading = false;
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
    if (_selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select dates first.')),
      );
      return;
    }

    if (_guests <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set number of guests.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          query: _searchCtrl.text,
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
      backgroundColor: Colors.white,
      body: SafeArea(child: body),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 🔍 TOP SEARCH + FILTER BAR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // search field
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by hotel or city',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
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
              Row(
                children: [
                  // date picker
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.date_range_outlined,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedRange == null
                                    ? 'Select dates'
                                    : '${_formatDate(_selectedRange!.start)} - ${_formatDate(_selectedRange!.end)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // guest selector
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _changeGuests(-1),
                            child: const Icon(Icons.remove, size: 18),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_guests',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _changeGuests(1),
                            child: const Icon(Icons.add, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // search + filter row
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _onSearchPressed,
                        child: const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final filters = await Navigator.push<GuestSearchFilters>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GuestFiltersScreen(
                            baseDateRange: _selectedRange,
                            baseGuests: _selectedRange == null ? null : _guests,
                          ),
                        ),
                      );

                      if (filters != null) {
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

                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: _primaryGreen,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // BODY
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 0, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // EXPLORE PLACES
                const Text(
                  'Explore places',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _orderedCities().length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final city = _orderedCities()[index];
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
                          width: 120,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                city.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                city.countryName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // HOT DEALS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hot deals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 25),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HotDealsScreen(),
                            ),
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
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 230,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _hotDeals.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
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
                const SizedBox(height: 20),

                if (_tags.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Theme hotels',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: 30.0),
                        child: Text(
                          'Quick picks',
                          style: TextStyle(
                            fontSize: 12,
                            color: _accentOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final tag = _tags[index];
                              return _TagCard(
                                tag: tag,
                                onTap: () => _openTag(tag),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    // jednostavan format: 12 Mar
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

class _HotDealCard extends StatelessWidget {
  final HotelSearchItemDto hotel;
  final DateTimeRange? dateRange;
  final int? guests;

  const _HotDealCard({required this.hotel, this.dateRange, this.guests});

  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
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
        width: 180,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: hotel.thumbnailUrl == null || hotel.thumbnailUrl!.isEmpty
                    ? Container(color: Colors.grey.shade200)
                    : Image.network(hotel.thumbnailUrl!, fit: BoxFit.cover),
              ),
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
                      const SizedBox(width: 3),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'From €${hotel.fromPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _accentOrange,
                        ),
                      ),
                      if (hotel.reviewCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
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
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${hotel.reviewCount})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
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

class _TagCard extends StatelessWidget {
  final TagDto tag;
  final VoidCallback onTap;

  const _TagCard({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF05A87A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: primaryGreen.withOpacity(0.12),
              foregroundColor: primaryGreen,
              child: Icon(_iconFor(tag.name)),
            ),
            const SizedBox(height: 10),
            Text(
              tag.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to view hotels',
              style: TextStyle(fontSize: 11, color: Colors.black54),
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

class _TagHotelsScreen extends StatefulWidget {
  final TagDto tag;

  const _TagHotelsScreen({required this.tag});

  @override
  State<_TagHotelsScreen> createState() => _TagHotelsScreenState();
}

class _TagHotelsScreenState extends State<_TagHotelsScreen> {
  static const _accentOrange = Color(0xFFFF7A3C);
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
      body = const Center(child: Text('No hotels found for this category.'));
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _hotels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final hotel = _hotels[index];
          final thumb = hotel.thumbnailUrl;
          return ListTile(
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
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(thumb, fit: BoxFit.cover),
                    ),
            ),
            title: Text(
              hotel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              hotel.city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                      Text(hotel.rating.toStringAsFixed(1)),
                      const SizedBox(width: 4),
                      Text(
                        '(${hotel.reviewCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.tag.name)),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
