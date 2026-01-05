import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/city_dto.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/core/search/search_state.dart';
import 'package:roomwise/features/guest/guest_hotel/presentation/screens/guest_hotel_preview_screen.dart';
import 'package:roomwise/l10n/app_localizations.dart';

// Design tokens for this screen
const _primaryGreen = Color(0xFF05A87A);
const _accentOrange = Color(0xFFFF7A3C);
const _bgColor = Color(0xFFF3F4F6);
const _cardColor = Colors.white;
const _textPrimary = Color(0xFF111827);
const _textMuted = Color(0xFF6B7280);

class HotelSearchScreen extends StatefulWidget {
  final CityDto city;
  final DateTimeRange? dateRange;
  final int? guests;

  const HotelSearchScreen({
    super.key,
    required this.city,
    this.dateRange,
    this.guests,
  });

  @override
  State<HotelSearchScreen> createState() => _HotelSearchScreenState();
}

class _HotelSearchScreenState extends State<HotelSearchScreen> {
  bool _loading = true;
  String? _error;
  List<HotelSearchItemDto> _hotels = [];

  @override
  void initState() {
    super.initState();
    _syncSearchState();
    _loadHotels();
  }

  void _syncSearchState() {
    final range = widget.dateRange;
    if (range == null) return;
    final guests = (widget.guests ?? 2).clamp(1, 10);
    try {
      context.read<SearchState>().update(
        checkIn: range.start,
        checkOut: range.end,
        guests: guests,
      );
    } catch (e) {
      debugPrint('[HotelSearch] SearchState update failed: $e');
    }
  }

  Future<void> _loadHotels() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      List<HotelSearchItemDto> result = [];

      if (widget.dateRange != null) {
        final range = widget.dateRange!;
        final guests = (widget.guests ?? 1).clamp(1, 10);
        try {
          result = await api.searchHotelsAdvanced(
            checkIn: range.start,
            checkOut: range.end,
            guests: guests,
            cityId: widget.city.id,
          );
        } catch (e) {
          debugPrint('Advanced city search failed, falling back: $e');
        }
      }

      if (result.isEmpty) {
        try {
          result = await api.searchHotelsByCity(cityId: widget.city.id);
        } catch (e) {
          debugPrint('City search fallback failed: $e');
        }
      }

      if (result.isEmpty) {
        try {
          final deals = await api.getHotDeals();
          final target = widget.city.name.toLowerCase().trim();
          result = deals
              .where(
                (h) =>
                    h.city.toLowerCase().trim() == target ||
                    h.name.toLowerCase().contains(target),
              )
              .toList();
        } catch (e) {
          debugPrint('Hot deals fallback failed: $e');
        }
      }

      setState(() {
        _hotels = result;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Hotel search failed: $e');
      setState(() {
        _error = AppLocalizations.of(
          context,
        )!.searchErrorCity(widget.city.name);
        _loading = false;
      });
    }
  }

  String _formatDates() {
    final t = AppLocalizations.of(context)!;
    if (widget.dateRange == null) return t.searchFlexibleDates;
    final start = widget.dateRange!.start;
    final end = widget.dateRange!.end;
    return '${start.day}.${start.month}.${start.year} – ${end.day}.${end.month}.${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    final t = AppLocalizations.of(context)!;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
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
              TextButton(onPressed: _loadHotels, child: Text(t.retry)),
            ],
          ),
        ),
      );
    } else if (_hotels.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.travel_explore_outlined,
                size: 40,
                color: _textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                t.searchEmptyTitle(widget.city.name),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                t.searchEmptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _textMuted),
              ),
            ],
          ),
        ),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: RefreshIndicator(
                onRefresh: _loadHotels,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _hotels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final h = _hotels[index];
                    return _AnimatedHotelCard(
                      index: index,
                      child: _HotelCard(
                        hotel: h,
                        dateRange: widget.dateRange,
                        guests: widget.guests,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.city.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDates(),
              style: const TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(38),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hotel_outlined,
                        size: 16,
                        color: _textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.searchCount(_hotels.length),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
      body: body,
    );
  }
}

class _AnimatedHotelCard extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedHotelCard({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.97, end: 1.0),
      duration: Duration(milliseconds: 200 + index * 40),
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

class _HotelCard extends StatelessWidget {
  final HotelSearchItemDto hotel;
  final DateTimeRange? dateRange;
  final int? guests;

  const _HotelCard({required this.hotel, this.dateRange, this.guests});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasRating = hotel.reviewCount > 0;
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
          color: _cardColor,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: hotel.thumbnailUrl == null || hotel.thumbnailUrl!.isEmpty
                    ? Container(color: Colors.grey.shade200)
                    : Hero(
                        tag: 'hotel-thumb-${hotel.id}',
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
                          errorBuilder: (context, error, stack) =>
                              Container(color: Colors.grey.shade200),
                        ),
                      ),
              ),
            ),
            // CONTENT
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                              '${hotel.reviewCount} review${hotel.reviewCount == 1 ? '' : 's'}',
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
                  // City
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
                            t.searchPerNightTaxes,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textMuted,
                            ),
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
                              Icons.hotel_class_outlined,
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
