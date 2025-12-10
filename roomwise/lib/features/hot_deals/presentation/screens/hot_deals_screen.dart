import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/hotel_search_item_dto.dart';
import 'package:roomwise/features/guest_hotel/presentation/screens/guest_hotel_preview_screen.dart';

class HotDealsScreen extends StatefulWidget {
  const HotDealsScreen({super.key});

  @override
  State<HotDealsScreen> createState() => _HotDealsScreenState();
}

enum HotDealSort { lowestPrice, highestPrice }

class _HotDealsScreenState extends State<HotDealsScreen> {
  static const _primaryGreen = Color(0xFF05A87A);

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  List<HotelSearchItemDto> _allDeals = [];
  List<HotelSearchItemDto> _visibleDeals = [];

  HotDealSort _sort = HotDealSort.lowestPrice;

  @override
  void initState() {
    super.initState();
    _loadDeals();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDeals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();

      final deals = await api.getHotDeals();

      if (!mounted) return;

      _allDeals = deals;
      _applyFilters();
      setState(() {
        _loading = false;
      });
    } on DioException catch (e) {
      debugPrint('Load hot deals failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load hot deals.';
      });
    } catch (e) {
      debugPrint('Load hot deals failed (non-Dio): $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load hot deals.';
      });
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();

    List<HotelSearchItemDto> filtered = List.of(_allDeals);

    if (query.isNotEmpty) {
      filtered = filtered.where((h) {
        final name = h.name.toLowerCase();
        final city = h.city.toLowerCase();
        return name.contains(query) || city.contains(query);
      }).toList();
    }

    filtered.sort((a, b) {
      final pa = a.effectivePrice;
      final pb = b.effectivePrice;

      if (_sort == HotDealSort.lowestPrice) {
        return pa.compareTo(pb);
      } else {
        return pb.compareTo(pa);
      }
    });

    setState(() {
      _visibleDeals = filtered;
    });
  }

  void _onSortChanged(HotDealSort sort) {
    if (_sort == sort) return;
    setState(() {
      _sort = sort;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hot deals')),
      body: RefreshIndicator(
        onRefresh: _loadDeals,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadDeals,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildTopBar(),
                  const Divider(height: 1),
                  Expanded(
                    child: _visibleDeals.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No hot deals found for your search.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _visibleDeals.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final hotel = _visibleDeals[index];
                              return _HotDealCard(hotel: hotel);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(top: 12, bottom: 8),
      child: Column(
        children: [
          // Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by hotel or city',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  if (_searchCtrl.text.isEmpty) return;
                  _searchCtrl.clear();
                  _applyFilters();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Sort chips
          Row(
            children: [
              const Text(
                'Sort by:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text(
                  'Lowest price',
                  style: TextStyle(fontSize: 12),
                ),
                selected: _sort == HotDealSort.lowestPrice,
                onSelected: (_) => _onSortChanged(HotDealSort.lowestPrice),
                selectedColor: _primaryGreen.withOpacity(0.12),
                labelStyle: TextStyle(
                  color: _sort == HotDealSort.lowestPrice
                      ? _primaryGreen
                      : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text(
                  'Highest price',
                  style: TextStyle(fontSize: 12),
                ),
                selected: _sort == HotDealSort.highestPrice,
                onSelected: (_) => _onSortChanged(HotDealSort.highestPrice),
                selectedColor: _primaryGreen.withOpacity(0.12),
                labelStyle: TextStyle(
                  color: _sort == HotDealSort.highestPrice
                      ? _primaryGreen
                      : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card used in the "See all hot deals" screen.
class _HotDealCard extends StatelessWidget {
  final HotelSearchItemDto hotel;

  const _HotDealCard({required this.hotel});

  static const _accentOrange = Color(0xFFFF7A3C);

  @override
  Widget build(BuildContext context) {
    final thumb = hotel.thumbnailUrl;
    final imageUrl =
        thumb == null || thumb.trim().isEmpty ? null : thumb.trim();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestHotelPreviewScreen(
              hotelId: hotel.id, // adjust parameter if needed
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
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
              child: SizedBox(
                width: 110,
                height: 110,
                child: imageUrl == null
                    ? Container(color: Colors.grey.shade200)
                    : Image.network(imageUrl, fit: BoxFit.cover),
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
                      hotel.name ?? 'Hotel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // City
                    if (hotel.city.isNotEmpty)
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
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    // Rating (if available)
                    if (hotel.reviewCount > 0)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            hotel.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
                        ],
                      ),
                    const SizedBox(height: 6),
                    // Price row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'From',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${hotel.currencyCode} '
                          '${hotel.effectivePrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _accentOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'per night',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _HotelPriceExtension on HotelSearchItemDto {
  double get effectivePrice => fromPrice;
  String get currencyCode => '€';
}
