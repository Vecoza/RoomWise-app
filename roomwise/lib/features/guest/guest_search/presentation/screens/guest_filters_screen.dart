import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/city_dto.dart';
import 'package:roomwise/core/models/addon_dto.dart';
import 'package:roomwise/core/models/facility_dto.dart';
import 'package:roomwise/features/guest/guest_search/domain/guest_search_filters.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestFiltersScreen extends StatefulWidget {
  final GuestSearchFilters? initialFilters;
  final DateTimeRange? baseDateRange;
  final int? baseGuests;

  const GuestFiltersScreen({
    super.key,
    this.initialFilters,
    this.baseDateRange,
    this.baseGuests,
  });

  @override
  State<GuestFiltersScreen> createState() => _GuestFiltersScreenState();
}

class _GuestFiltersScreenState extends State<GuestFiltersScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _cardColor = Colors.white;
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _loading = true;
  String? _warning;

  List<CityDto> _cities = [];
  List<AddonDto> _addons = [];
  List<FacilityDto> _facilities = [];

  int? _selectedCityId;
  RangeValues _priceRange = const RangeValues(0, 500);
  double _minRating = 0;
  DateTimeRange? _dateRange;
  int _guests = 2;

  final Set<int> _selectedAddonIds = {};
  final Set<int> _selectedFacilityIds = {};

  @override
  void initState() {
    super.initState();
    _initFromInitialFilters();
    _loadData();
  }

  void _initFromInitialFilters() {
    final f = widget.initialFilters;

    _selectedCityId = f?.cityId;
    if (f?.minPrice != null || f?.maxPrice != null) {
      _priceRange = RangeValues(
        (f?.minPrice ?? 0).toDouble(),
        (f?.maxPrice ?? 500).toDouble(),
      );
    }

    _minRating = (f?.minRating ?? 0).toDouble();
    _dateRange = f?.dateRange ?? widget.baseDateRange;
    _guests = f?.guests ?? widget.baseGuests ?? 2;

    _selectedAddonIds.addAll(f?.addonIds ?? []);
    _selectedFacilityIds.addAll(f?.facilityIds ?? []);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _warning = null;
    });

    var hadFailure = false;
    final api = context.read<RoomWiseApiClient>();
    var cities = <CityDto>[];
    var addons = <AddonDto>[];
    var facilities = <FacilityDto>[];

    try {
      cities = await api.getCities();
    } catch (e) {
      debugPrint('Load cities failed: $e');
      hadFailure = true;
    }

    try {
      addons = await api.getAddOns();
    } catch (e) {
      debugPrint('Load add-ons failed: $e');
      hadFailure = true;
    }

    try {
      facilities = await api.getFacilities();
    } catch (e) {
      debugPrint('Load facilities failed: $e');
      hadFailure = true;
    }

    if (!mounted) return;
    setState(() {
      _cities = cities;
      _addons = addons;
      _facilities = facilities;
      _loading = false;
      _warning = hadFailure
          ? 'Some filters could not load. Showing available options.'
          : null;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial =
        _dateRange ??
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
        _dateRange = picked;
      });
    }
  }

  void _changeGuests(int delta) {
    setState(() {
      _guests = (_guests + delta).clamp(1, 10);
    });
  }

  void _resetFilters({bool closeAndReturn = false}) {
    _selectedAddonIds.clear();
    _selectedFacilityIds.clear();

    setState(() {
      _selectedCityId = null;
      _priceRange = const RangeValues(0, 500);
      _minRating = 0;
      _dateRange = widget.baseDateRange;
      _guests = widget.baseGuests ?? 2;
    });

    if (closeAndReturn) {
      _onApply();
    }
  }

  void _onApply() {
    final guests = _dateRange == null ? null : _guests;
    final filters = GuestSearchFilters(
      cityId: _selectedCityId,
      minPrice: _priceRange.start > 0 ? _priceRange.start : null,
      maxPrice: _priceRange.end < 500 ? _priceRange.end : null,
      minRating: _minRating > 0 ? _minRating : null,
      addonIds: _selectedAddonIds.toList(),
      facilityIds: _selectedFacilityIds.toList(),
      dateRange: _dateRange,
      guests: guests,
    );

    Navigator.pop(context, filters);
  }

  int get _selectedCount {
    int count = 0;
    if (_selectedCityId != null) count++;
    if (_priceRange.start > 0 || _priceRange.end < 500) count++;
    if (_minRating > 0) count++;
    if (_dateRange != null) count++;
    if (_selectedAddonIds.isNotEmpty) count++;
    if (_selectedFacilityIds.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(t);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        titleSpacing: 16,
        title: Text(
          t.filtersTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: Text(
              t.filtersClearAll,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textMuted,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_warning != null)
              Container(
                width: double.infinity,
                color: Colors.orange.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _warning!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    TextButton(onPressed: _loadData, child: Text(t.retry)),
                  ],
                ),
              ),
            Expanded(child: body),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: _cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade800,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _resetFilters,
                          child: Text(
                            t.filtersReset,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _onApply,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.filtersApply,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_selectedCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$_selectedCount',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCityCard(t),
                  const SizedBox(height: 12),
                  _buildPriceCard(t),
                  const SizedBox(height: 12),
                  _buildRatingCard(t),
                  const SizedBox(height: 12),
                  _buildDatesAndGuestsCard(t),
                  const SizedBox(height: 12),
                  if (_addons.isNotEmpty) _buildAddOnsCard(t),
                  if (_addons.isNotEmpty) const SizedBox(height: 12),
                  if (_facilities.isNotEmpty) _buildFacilitiesCard(t),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- CARDS ---

  Widget _buildCityCard(AppLocalizations t) {
    return _FilterCard(
      title: t.filtersCityTitle,
      subtitle: t.filtersCitySubtitle,
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        value: _selectedCityId,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
        ),
        hint: Text(t.filtersCityAny),
        items: _cities
            .map(
              (c) => DropdownMenuItem<int>(
                value: c.id,
                child: Text('${c.name}, ${c.countryName}'),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedCityId = value;
          });
        },
      ),
    );
  }

  Widget _buildPriceCard(AppLocalizations t) {
    return _FilterCard(
      title: t.filtersPriceTitle,
      subtitle: t.filtersPriceSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PricePill(
                label: t.filtersPriceMin,
                value: '€${_priceRange.start.toStringAsFixed(0)}',
              ),
              const SizedBox(width: 8),
              _PricePill(
                label: t.filtersPriceMax,
                value: '€${_priceRange.end.toStringAsFixed(0)}',
              ),
              const Spacer(),
              const Icon(Icons.euro_symbol, size: 18, color: _textMuted),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 500,
            divisions: 50,
            labels: RangeLabels(
              '€${_priceRange.start.toStringAsFixed(0)}',
              '€${_priceRange.end.toStringAsFixed(0)}',
            ),
            onChanged: (values) {
              setState(() {
                _priceRange = values;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(AppLocalizations t) {
    return _FilterCard(
      title: t.filtersRatingTitle,
      subtitle: t.filtersRatingSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStarsPreview(_minRating),
              const SizedBox(width: 8),
              Text(
                _minRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          Slider(
            value: _minRating,
            min: 0,
            max: 5,
            divisions: 10,
            label: _minRating.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _minRating = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatesAndGuestsCard(AppLocalizations t) {
    return _FilterCard(
      title: t.filtersTripTitle,
      subtitle: t.filtersTripSubtitle,
      child: Column(
        children: [
          // Dates row
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_outlined,
                    size: 18,
                    color: _textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dateRange == null
                          ? t.landingSelectDatesLabel
                          : '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Guests row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 18, color: _textMuted),
                const SizedBox(width: 8),
                Text(
                  t.guestsLabel(_guests),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const Spacer(),
                _RoundIconButton(
                  icon: Icons.remove,
                  onTap: () => _changeGuests(-1),
                  enabled: _guests > 1,
                ),
                const SizedBox(width: 6),
                _RoundIconButton(
                  icon: Icons.add,
                  onTap: () => _changeGuests(1),
                  enabled: _guests < 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOnsCard(AppLocalizations t) {
    return _FilterCard(
      title: t.reservationAddOnsTitle,
      subtitle: t.filtersAddOnsSubtitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _addons.map((a) {
          final selected = _selectedAddonIds.contains(a.id);
          return FilterChip(
            label: Text(a.name),
            selected: selected,
            onSelected: (value) {
              setState(() {
                if (value) {
                  _selectedAddonIds.add(a.id);
                } else {
                  _selectedAddonIds.remove(a.id);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFacilitiesCard(AppLocalizations t) {
    return _FilterCard(
      title: t.filtersFacilitiesTitle,
      subtitle: t.filtersFacilitiesSubtitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _facilities.map((f) {
          final selected = _selectedFacilityIds.contains(f.id);
          return FilterChip(
            label: Text(f.name),
            selected: selected,
            onSelected: (value) {
              setState(() {
                if (value) {
                  _selectedFacilityIds.add(f.id);
                } else {
                  _selectedFacilityIds.remove(f.id);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStarsPreview(double rating) {
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.25 && (rating - fullStars) < 0.75;
    final totalStars = 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalStars, (index) {
        IconData icon;
        if (index < fullStars) {
          icon = Icons.star;
        } else if (index == fullStars && hasHalf) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: 18, color: Colors.amber);
      }),
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
}

// --- Small reusable widgets ---

class _FilterCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _FilterCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _GuestFiltersScreenState._cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _GuestFiltersScreenState._textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: _GuestFiltersScreenState._textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final String label;
  final String value;

  const _PricePill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 11,
              color: _GuestFiltersScreenState._textMuted,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.black87 : Colors.grey,
        ),
      ),
    );
  }
}
