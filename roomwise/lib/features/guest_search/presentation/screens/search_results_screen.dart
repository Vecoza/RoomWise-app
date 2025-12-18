import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/features/guest_hotel/presentation/screens/guest_hotel_preview_screen.dart';
import 'package:roomwise/features/guest_search/domain/guest_search_filters.dart';
import 'package:roomwise/features/guest_search/presentation/screens/guest_filters_screen.dart';
import 'package:roomwise/l10n/app_localizations.dart';

const _primaryGreen = Color(0xFF05A87A);
const _accentOrange = Color(0xFFFF7A3C);
const _bgColor = Color(0xFFF3F4F6);
const _textPrimary = Color(0xFF111827);
const _textMuted = Color(0xFF6B7280);

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

      hotels = _applyClientSort(hotels);

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
    final sorted = List<HotelSearchItemDto>.from(list);
    switch (_sortOption) {
      case 'priceAsc':
        sorted.sort((a, b) => a.fromPrice.compareTo(b.fromPrice));
        break;
      case 'priceDesc':
        sorted.sort((a, b) => b.fromPrice.compareTo(a.fromPrice));
        break;
      case 'ratingDesc':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    return sorted;
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
    final t = AppLocalizations.of(context)!;
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
      textParts.add(t.guestsLabel(guests));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 16, color: _textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              textParts.join(' • '),
              style: const TextStyle(
                fontSize: 12,
                color: _textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_hasAnyFilter(_currentFilters))
            TextButton(
              onPressed: _openFilters,
              child: Text(t.searchRefine, style: const TextStyle(fontSize: 12)),
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
    final t = AppLocalizations.of(context)!;
    Widget listBody;

    if (_loading) {
      listBody = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      listBody = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadResults, child: Text(t.retry)),
            ],
          ),
        ),
      );
    } else if (_results.isEmpty) {
      listBody = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.travel_explore_outlined, size: 40, color: _textMuted),
              const SizedBox(height: 12),
              Text(
                t.searchNoResultsTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
              ),
            ],
          ),
        ),
      );
    } else {
      listBody = LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: RefreshIndicator(
                onRefresh: _loadResults,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final hotel = _results[index];
                    final f = _currentFilters;

                    return _AnimatedResultCard(
                      index: index,
                      child: _HotelResultCard(
                        hotel: hotel,
                        dateRange: f.dateRange ?? widget.dateRange,
                        guests: f.guests ?? widget.guests,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          t.searchTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: t.landingSearchHint,
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
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
                // Filters button
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune, size: 20, color: _textMuted),
                ),
                const SizedBox(width: 4),
                // Sort popup
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
                  icon: const Icon(Icons.sort, size: 20, color: _textMuted),
                  tooltip: 'Sort',
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildActiveFiltersSummary(),
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${_results.length} stay${_results.length == 1 ? '' : 's'} found',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          Expanded(child: listBody),
        ],
      ),
    );
  }
}

/// Small scale animation when list items appear
class _AnimatedResultCard extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedResultCard({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.97, end: 1.0),
      duration: Duration(milliseconds: 220 + index * 40),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _HotelResultCard extends StatelessWidget {
  final HotelSearchItemDto hotel;
  final DateTimeRange? dateRange;
  final int? guests;

  const _HotelResultCard({required this.hotel, this.dateRange, this.guests});

  @override
  Widget build(BuildContext context) {
    final hasRating = hotel.reviewCount > 0;
    final t = AppLocalizations.of(context)!;
    final currency = hotel.currency.isNotEmpty ? hotel.currency : '€';
    final priceText = t.landingFromPrice(
      currency,
      hotel.fromPrice.toStringAsFixed(0),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
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
                    : Hero(
                        tag: 'result-thumb-${hotel.id}',
                        child: Image.network(
                          hotel.thumbnailUrl!,
                          fit: BoxFit.cover,
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
                            return Container(color: Colors.grey.shade200);
                          },
                        ),
                      ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          hotel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (hasRating) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.12),
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.searchReviewsCount(hotel.reviewCount),
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            priceText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _accentOrange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.searchPerNightEstimate,
                            style: const TextStyle(fontSize: 11, color: _textMuted),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: _primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t.searchViewDetails,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _primaryGreen,
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
