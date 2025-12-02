import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/features/guest_hotel/presentation/screens/guest_hotel_preview_screen.dart';
import 'package:roomwise/features/guest_search/domain/guest_search_filters.dart';
import 'package:roomwise/features/guest_search/presentation/screens/guest_filters_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String? query;
  final DateTimeRange? dateRange;
  final int? guests;
  final GuestSearchFilters? initialFilters;

  const SearchResultsScreen({
    super.key,
    this.query,
    this.dateRange,
    this.guests,
    this.initialFilters,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  static const _primaryGreen = Color(0xFF05A87A);

  bool _loading = true;
  String? _error;
  List<HotelSearchItemDto> _results = [];

  late final TextEditingController _searchCtrl;

  /// Always non-null; holds the last used filters (including date & guests).
  GuestSearchFilters _currentFilters = const GuestSearchFilters();

  String? _sortOption;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.query ?? '');

    // Normalize initial filters coming from landing / filters screen
    _currentFilters = _normalizeFilters(widget.initialFilters);

    _loadResults();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    // Make sure filters are always in a consistent state
    _currentFilters = _normalizeFilters(_currentFilters);
    final f = _currentFilters;
    final trimmedQuery = _searchCtrl.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      List<HotelSearchItemDto> hotels;

      // If we don't have a stay period or guests, fall back to "all hotels"
      if (f.dateRange == null || (f.guests == null && widget.guests == null)) {
        hotels = await api.getAllHotels();
      } else {
        final dateRange = f.dateRange!;
        final guests = f.guests ?? widget.guests ?? 1;

        hotels = await api.searchHotelsAdvanced(
          checkIn: dateRange.start,
          checkOut: dateRange.end,
          guests: guests,
          query: trimmedQuery.isEmpty ? null : trimmedQuery,
          cityId: f.cityId,
          minPrice: f.minPrice,
          maxPrice: f.maxPrice,
          addonIds: f.addonIds,
          facilityIds: f.facilityIds,
          sort: _sortOption,
        );

        if (f.minRating != null) {
          hotels = hotels.where((h) => h.rating >= (f.minRating ?? 0)).toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _results = hotels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load search results. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _openFilters() async {
    final f = _currentFilters;

    final result = await Navigator.push<GuestSearchFilters>(
      context,
      MaterialPageRoute(
        builder: (_) => GuestFiltersScreen(
          initialFilters: f,
          baseDateRange: f.dateRange ?? widget.dateRange,
          baseGuests: (f.dateRange ?? widget.dateRange) == null
              ? null
              : f.guests ?? widget.guests,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentFilters = _normalizeFilters(result);
      });
      await _loadResults();
    }
  }

  List<HotelSearchItemDto> _applyClientSort(List<HotelSearchItemDto> list) {
    switch (_sortOption) {
      case 'priceAsc':
        list.sort((a, b) => a.fromPrice.compareTo(b.fromPrice));
        break;
      case 'priceDesc':
        list.sort((a, b) => b.fromPrice.compareTo(a.fromPrice));
        break;
      case 'ratingDesc':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    return list;
  }

  GuestSearchFilters _normalizeFilters(GuestSearchFilters? filters) {
    // Start from incoming filters or create a default one based on widget params
    final incoming =
        filters ??
        GuestSearchFilters(
          dateRange: widget.dateRange,
          guests: widget.dateRange != null ? widget.guests : null,
        );

    final dateRange = incoming.dateRange ?? widget.dateRange;
    final guests = dateRange == null
        ? null
        : (incoming.guests ?? widget.guests);

    return GuestSearchFilters(
      cityId: incoming.cityId,
      minPrice: incoming.minPrice,
      maxPrice: incoming.maxPrice,
      minRating: incoming.minRating,
      addonIds: incoming.addonIds,
      facilityIds: incoming.facilityIds,
      dateRange: dateRange,
      guests: guests,
    );
  }

  bool _hasAnyFilter(GuestSearchFilters? f) {
    if (f == null) return false;
    return f.cityId != null ||
        f.minPrice != null ||
        f.maxPrice != null ||
        f.dateRange != null ||
        f.guests != null ||
        f.addonIds.isNotEmpty ||
        f.facilityIds.isNotEmpty;
  }

  /// Small row under the search bar showing the selected dates & guests.
  Widget _buildActiveFiltersSummary() {
    final dateRange = _currentFilters.dateRange ?? widget.dateRange;
    final guests = _currentFilters.guests ?? widget.guests;

    if (dateRange == null && guests == null) {
      return const SizedBox.shrink();
    }

    final textParts = <String>[];
    if (dateRange != null) {
      textParts.add(
        '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
      );
    }
    if (guests != null) {
      textParts.add('$guests guest${guests == 1 ? '' : 's'}');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              textParts.join(' • '),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_hasAnyFilter(_currentFilters))
            TextButton(
              onPressed: _openFilters,
              child: const Text('Refine', style: TextStyle(fontSize: 12)),
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
            TextButton(onPressed: _loadResults, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_results.isEmpty) {
      body = const Center(
        child: Text(
          'No hotels found.\nTry adjusting your search or filters.',
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final hotel = _results[index];
          final f = _currentFilters;

          return _HotelResultCard(
            hotel: hotel,
            dateRange: f.dateRange ?? widget.dateRange,
            guests: f.guests ?? widget.guests,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search results'),
        actions: [
          // 🔍 Filters button restored
          IconButton(icon: const Icon(Icons.tune), onPressed: _openFilters),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _sortOption = value);
              _loadResults();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'priceAsc',
                child: Text('Price: Low to High'),
              ),
              PopupMenuItem(
                value: 'priceDesc',
                child: Text('Price: High to Low'),
              ),
              PopupMenuItem(
                value: 'ratingDesc',
                child: Text('Rating: Highest First'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          // mini search bar on top
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
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
                    onSubmitted: (_) => _loadResults(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadResults,
                  icon: const Icon(Icons.search),
                  color: _primaryGreen,
                ),
              ],
            ),
          ),

          // NEW: summary of date range + guests + quick refine
          _buildActiveFiltersSummary(),

          const Divider(height: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _HotelResultCard extends StatelessWidget {
  final HotelSearchItemDto hotel;
  final DateTimeRange? dateRange;
  final int? guests;
  static const _accentOrange = Color(0xFFFF7A3C);

  const _HotelResultCard({required this.hotel, this.dateRange, this.guests});

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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            fontSize: 12,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _accentOrange,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            hotel.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
  }
}
