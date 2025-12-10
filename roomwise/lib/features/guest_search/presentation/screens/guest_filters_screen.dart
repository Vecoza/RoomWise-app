import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/city_dto.dart';
import 'package:roomwise/core/models/addon_dto.dart';
import 'package:roomwise/core/models/facility_dto.dart';
import 'package:roomwise/features/guest_search/domain/guest_search_filters.dart';

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

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildContent();

    return Scaffold(
      appBar: AppBar(title: const Text('Filters')),
      body: SafeArea(
        child: Column(
          children: [
            if (_warning != null)
              Container(
                width: double.infinity,
                color: Colors.orange.withOpacity(0.12),
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
                    TextButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(child: body),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
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
                      child: const Text(
                        'Reset',
                        style: TextStyle(
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
                      child: const Text(
                        'Apply filters',
                        style:
                            TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
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

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City
          const Text(
            'City',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: _selectedCityId,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
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
          const SizedBox(height: 16),

          // Price
          const Text(
            'Price per night (approx)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
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
          const SizedBox(height: 16),

          // Rating
          const Text(
            'Minimum rating',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
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
              ),
              const SizedBox(width: 8),
              Text(
                _minRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date range
          const Text(
            'Stay dates',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
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
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dateRange == null
                          ? 'Select date range'
                          : '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Guests
          const Text(
            'Guests',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => _changeGuests(-1),
                  icon: const Icon(Icons.remove),
                  splashRadius: 18,
                ),
                Text(
                  '$_guests',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeGuests(1),
                  icon: const Icon(Icons.add),
                  splashRadius: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // AddOns
          if (_addons.isNotEmpty) ...[
            const Text(
              'Add-ons',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
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
            const SizedBox(height: 16),
          ],

          // Facilities
          if (_facilities.isNotEmpty) ...[
            const Text(
              'Facilities',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
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
          ],
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
}
