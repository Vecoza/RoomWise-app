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
  // Design tokens – aligned with the rest of your app
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF5F7FA);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

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
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _buildError()
        : _buildLoaded();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Hot deals'),
        backgroundColor: _bgColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _loadDeals, child: body),
      ),
    );
  }

  // ---------- STATES ----------

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadDeals, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoaded() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildControls(),
                  const SizedBox(height: 12),
                  if (_visibleDeals.isEmpty)
                    _buildEmptyState(constraints)
                  else
                    _buildDealsList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- HEADER ----------

  Widget _buildHeader() {
    final total = _allDeals.length;
    final visible = _visibleDeals.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A3C), Color(0xFFFF914D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.local_fire_department_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today’s hot deals',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'We’ll show limited time offers here.'
                        : visible == total
                        ? '$total deals available right now.'
                        : '$visible of $total deals match your filters.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- CONTROLS (SEARCH + SORT) ----------

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by hotel or city',
              hintStyle: const TextStyle(fontSize: 13, color: _textMuted),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _applyFilters();
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => _applyFilters(),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 10),
          // Sort chips row
          Row(
            children: [
              const Text(
                'Sort by',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Lowest price',
                isActive: _sort == HotDealSort.lowestPrice,
                onTap: () => _onSortChanged(HotDealSort.lowestPrice),
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Highest price',
                isActive: _sort == HotDealSort.highestPrice,
                onTap: () => _onSortChanged(HotDealSort.highestPrice),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- EMPTY & LIST ----------

  Widget _buildEmptyState(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
      child: SizedBox(
        height: constraints.maxHeight * 0.5,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.search_off_outlined, size: 56, color: _textMuted),
                SizedBox(height: 14),
                Text(
                  'No hot deals found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Try changing your search text or sort order to see more options.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDealsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _visibleDeals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final hotel = _visibleDeals[index];
        return _HotDealCard(hotel: hotel);
      },
    );
  }
}

// ---------- SORT CHIP ----------

class _SortChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF05A87A);
    const textMuted = Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? activeColor.withOpacity(0.7)
                : Colors.grey.withOpacity(0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? activeColor : textMuted,
          ),
        ),
      ),
    );
  }
}

// ---------- HOT DEAL CARD ----------

class _HotDealCard extends StatelessWidget {
  final HotelSearchItemDto hotel;

  const _HotDealCard({required this.hotel});

  static const _accentOrange = Color(0xFFFF7A3C);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final thumb = hotel.thumbnailUrl;
    final imageUrl = thumb == null || thumb.trim().isEmpty
        ? null
        : thumb.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GuestHotelPreviewScreen(hotelId: hotel.id),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl == null
                          ? Container(color: Colors.grey.shade200)
                          : Image.network(imageUrl, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hotel.promotionTitle?.isNotEmpty == true
                                    ? hotel.promotionTitle!
                                    : 'Hot deal',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
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
                          // City
                          if (hotel.city.isNotEmpty)
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
                                      fontSize: 11,
                                      color: _textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 6),
                          // Rating
                          if (hotel.reviewCount > 0)
                            Row(
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
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${hotel.reviewCount})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: _textMuted,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'From',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Row(
                                children: [
                                  Text(
                                    '${hotel.currencyCode} '
                                    '${hotel.effectivePrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _accentOrange,
                                    ),
                                  ),
                                  if (hotel.promotionPrice != null &&
                                      hotel.promotionPrice! > 0 &&
                                      hotel.promotionPrice! <
                                          hotel.fromPrice) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '${hotel.currencyCode} ${hotel.fromPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _textMuted,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'per night',
                            style: TextStyle(fontSize: 10, color: _textMuted),
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
      ),
    );
  }
}

// Small helpers to keep your old logic intact
extension _HotelPriceExtension on HotelSearchItemDto {
  double get effectivePrice =>
      (promotionPrice != null && promotionPrice! > 0)
          ? promotionPrice!
          : fromPrice;
  String get currencyCode => currency.isNotEmpty ? currency : '€';
}
