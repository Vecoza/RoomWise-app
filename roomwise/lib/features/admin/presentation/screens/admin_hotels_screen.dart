import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/admin_room_type_dto.dart';
import 'package:roomwise/core/models/admin_room_rate_dto.dart';
import 'package:roomwise/core/models/admin_room_availability_dto.dart';
import 'package:roomwise/core/models/admin_hotel_image_dto.dart';
import 'package:roomwise/core/models/admin_room_type_image_dto.dart';

class AdminHotelsScreen extends StatefulWidget {
  const AdminHotelsScreen({super.key});

  @override
  State<AdminHotelsScreen> createState() => _AdminHotelsScreenState();
}

class _AdminHotelsScreenState extends State<AdminHotelsScreen> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _primaryGreen = Color(0xFF05A87A);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _hotel;
  List<AdminRoomTypeDto> _roomTypes = const [];
  List<AdminRoomRateDto> _roomRates = const [];
  List<AdminRoomAvailabilityDto> _roomAvailability = const [];
  List<AdminHotelImageDto> _images = const [];
  List<AdminRoomTypeImageDto> _roomImages = const [];

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

    final api = context.read<RoomWiseApiClient>();
    try {
      final roomTypes = await api.getAdminRoomTypes();
      int? hotelId;
      if (roomTypes.isNotEmpty) {
        hotelId = roomTypes.first.hotelId;
      }

      Map<String, dynamic>? hotel;
      if (hotelId != null && hotelId > 0) {
        hotel = await api.getAdminHotel(hotelId);
      }

      final rates = await api.getAdminRoomRates();
      final availability = await api.getAdminRoomAvailabilities();
      final images = await api.getAdminHotelImages();
      final roomImages = await api.getAdminRoomTypeImages();

      if (!mounted) return;
      setState(() {
        _roomTypes = roomTypes;
        _hotel = hotel;
        _roomRates = rates;
        _roomAvailability = availability;
        _images = images;
        _roomImages = roomImages;
        _loading = false;
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await context.read<AuthState>().logout();
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = code == 401 || code == 403
            ? 'Not authorized. Please log in again.'
            : 'Failed to load hotel data.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load hotel data.';
      });
    }
  }

  Future<void> _editRoomType([AdminRoomTypeDto? rt]) async {
    final result = await showModalBottomSheet<AdminRoomTypeUpsertRequest>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _RoomTypeForm(existing: rt),
        );
      },
    );

    if (result == null) return;
    final api = context.read<RoomWiseApiClient>();
    try {
      if (rt == null) {
        await api.createAdminRoomType(result);
      } else {
        await api.updateAdminRoomType(rt.id, result);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Hotel & rooms',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: _loading ? null : () => _editRoomType(),
                icon: const Icon(Icons.add),
                label: const Text('Room type'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else ...[
            if (_hotel != null) _HotelCard(hotel: _hotel!),
            const SizedBox(height: 12),
            _RoomTypesSection(
              items: _roomTypes,
              onEdit: _editRoomType,
            ),
            const SizedBox(height: 12),
            _RatesSection(
              roomTypes: _roomTypes,
              rates: _roomRates,
              onSaved: _load,
            ),
            const SizedBox(height: 12),
            _AvailabilitySection(
              roomTypes: _roomTypes,
              availability: _roomAvailability,
              onSaved: _load,
            ),
            const SizedBox(height: 12),
            _ImagesSection(
              images: _images,
              onChanged: _load,
            ),
            const SizedBox(height: 12),
            _RoomImagesSection(
              roomTypes: _roomTypes,
              images: _roomImages,
              onChanged: _load,
            ),
          ],
        ],
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final Map<String, dynamic> hotel;

  const _HotelCard({required this.hotel});

  @override
  Widget build(BuildContext context) {
    final createdAt = hotel['createdAt'] != null
        ? DateTime.tryParse(hotel['createdAt'].toString())
        : null;
    final updatedAt = hotel['updatedAt'] != null
        ? DateTime.tryParse(hotel['updatedAt'].toString())
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment, color: _textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (hotel['name'] ?? 'Hotel').toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (hotel['description'] ?? 'No description').toString(),
            style: const TextStyle(color: _textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            (hotel['addressLine'] ?? '').toString(),
            style: const TextStyle(color: _textMuted),
          ),
          if (hotel['website'] != null && (hotel['website'] as String).isNotEmpty)
            Text(
              (hotel['website'] ?? '').toString(),
              style: const TextStyle(color: _textMuted),
            ),
          if (hotel['email'] != null && (hotel['email'] as String).isNotEmpty)
            Text(
              (hotel['email'] ?? '').toString(),
              style: const TextStyle(color: _textMuted),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (createdAt != null)
                Text(
                  'Created ${DateFormat('dd MMM yyyy').format(createdAt)}',
                  style: const TextStyle(color: _textMuted, fontSize: 12),
                ),
              if (updatedAt != null) ...[
                const SizedBox(width: 10),
                Text(
                  'Updated ${DateFormat('dd MMM yyyy').format(updatedAt)}',
                  style: const TextStyle(color: _textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomTypesSection extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminRoomTypeDto> items;
  final void Function(AdminRoomTypeDto?) onEdit;

  const _RoomTypesSection({required this.items, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Room types',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onEdit(null),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'No room types yet.',
              style: TextStyle(color: _textMuted),
            )
          else
            Column(
              children: items
                  .map(
                    (rt) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(rt.name),
                      subtitle: Text(
                        '${rt.capacity} guests • ${rt.bedType ?? 'Bed'}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${rt.currency} ${rt.basePrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            'Stock ${rt.stock}',
                            style: const TextStyle(color: _textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      onTap: () => onEdit(rt),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _RoomTypeForm extends StatefulWidget {
  final AdminRoomTypeDto? existing;

  const _RoomTypeForm({required this.existing});

  @override
  State<_RoomTypeForm> createState() => _RoomTypeFormState();
}

class _RoomTypeFormState extends State<_RoomTypeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _capacity;
  late final TextEditingController _basePrice;
  late final TextEditingController _stock;
  late final TextEditingController _bedType;
  String _currency = 'EUR';
  bool _smoking = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _name = TextEditingController(text: ex?.name ?? '');
    _capacity = TextEditingController(text: ex?.capacity.toString() ?? '2');
    _basePrice = TextEditingController(text: ex?.basePrice.toString() ?? '0');
    _stock = TextEditingController(text: ex?.stock.toString() ?? '1');
    _bedType = TextEditingController(text: ex?.bedType ?? '');
    _currency = ex?.currency ?? 'EUR';
    _smoking = ex?.isSmokingAllowed ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _basePrice.dispose();
    _stock.dispose();
    _bedType.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final req = AdminRoomTypeUpsertRequest(
      name: _name.text.trim(),
      capacity: int.tryParse(_capacity.text) ?? 1,
      basePrice: double.tryParse(_basePrice.text) ?? 0,
      stock: int.tryParse(_stock.text) ?? 1,
      bedType: _bedType.text.trim().isEmpty ? null : _bedType.text.trim(),
      currency: _currency,
      isSmokingAllowed: _smoking,
    );
    Navigator.of(context).pop(req);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              widget.existing == null ? 'New room type' : 'Edit room type',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _capacity,
              decoration: const InputDecoration(labelText: 'Capacity'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _basePrice,
              decoration: const InputDecoration(labelText: 'Base price'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: _stock,
              decoration: const InputDecoration(labelText: 'Stock'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _bedType,
              decoration: const InputDecoration(labelText: 'Bed type'),
            ),
            DropdownButtonFormField<String>(
              value: _currency,
              items: const [
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
              ],
              onChanged: (v) => setState(() => _currency = v ?? 'EUR'),
              decoration: const InputDecoration(labelText: 'Currency'),
            ),
            SwitchListTile(
              value: _smoking,
              onChanged: (v) => setState(() => _smoking = v),
              title: const Text('Smoking allowed'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _RatesSection extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminRoomTypeDto> roomTypes;
  final List<AdminRoomRateDto> rates;
  final Future<void> Function() onSaved;

  const _RatesSection({
    required this.roomTypes,
    required this.rates,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Rates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: roomTypes.isEmpty
                    ? null
                    : () => _openRateForm(context, roomTypes, onSaved),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rates.isEmpty)
            const Text('No rates yet.', style: TextStyle(color: _textMuted))
          else
            Column(
              children: rates
                  .map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${dateFmt.format(r.startDate)} - ${dateFmt.format(r.endDate)}',
                      ),
                      subtitle: Text(
                        roomTypes
                                .firstWhere(
                                  (rt) => rt.id == r.roomTypeId,
                                  orElse: () => roomTypes.first,
                                )
                                .name +
                            ' • ${r.currency} ${r.price.toStringAsFixed(0)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _openRateForm(
                              context,
                              roomTypes,
                              onSaved,
                              existing: r,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                            onPressed: () => _deleteRate(context, r, onSaved),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _openRateForm(
    BuildContext context,
    List<AdminRoomTypeDto> roomTypes,
    Future<void> Function() onSaved,
    {AdminRoomRateDto? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _RateForm(
            roomTypes: roomTypes,
            onSaved: onSaved,
            existing: existing,
          ),
        );
      },
    );
  }

  Future<void> _deleteRate(
    BuildContext context,
    AdminRoomRateDto rate,
    Future<void> Function() onSaved,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rate'),
        content: const Text('Are you sure you want to delete this rate?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final api = context.read<RoomWiseApiClient>();
    try {
      await api.deleteAdminRoomRate(rate.id);
      await onSaved();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}

class _RateForm extends StatefulWidget {
  final List<AdminRoomTypeDto> roomTypes;
  final Future<void> Function() onSaved;
  final AdminRoomRateDto? existing;

  const _RateForm({
    required this.roomTypes,
    required this.onSaved,
    this.existing,
  });

  @override
  State<_RateForm> createState() => _RateFormState();
}

class _RateFormState extends State<_RateForm> {
  final _formKey = GlobalKey<FormState>();
  int? _roomTypeId;
  DateTime? _start;
  DateTime? _end;
  final _price = TextEditingController(text: '0');
  String _currency = 'EUR';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _roomTypeId = widget.existing!.roomTypeId;
      _currency = widget.existing!.currency;
      _start = widget.existing!.startDate;
      _end = widget.existing!.endDate;
      _price.text = widget.existing!.price.toString();
    } else if (widget.roomTypes.isNotEmpty) {
      _roomTypeId = widget.roomTypes.first.id;
      _currency = widget.roomTypes.first.currency;
    }
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _start != null && _end != null
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
    );
    if (res != null) {
      setState(() {
        _start = res.start;
        _end = res.end;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roomTypeId == null || _start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select room type and dates')),
      );
      return;
    }
    setState(() => _saving = true);
    final api = context.read<RoomWiseApiClient>();
    try {
      final req = AdminRoomRateUpsertRequest(
        roomTypeId: _roomTypeId!,
        startDate: _start!,
        endDate: _end!,
        price: double.tryParse(_price.text) ?? 0,
        currency: _currency,
      );
      if (widget.existing != null) {
        await api.updateAdminRoomRate(widget.existing!.id, req);
      } else {
        await api.createAdminRoomRate(req);
      }
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final dateText = (_start != null && _end != null)
        ? '${DateFormat('dd MMM').format(_start!)} - ${DateFormat('dd MMM yyyy').format(_end!)}'
        : 'Select dates';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              isEdit ? 'Edit rate' : 'New rate',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _roomTypeId,
              items: widget.roomTypes
                  .map(
                    (rt) => DropdownMenuItem(
                      value: rt.id,
                      child: Text(rt.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _roomTypeId = v),
              decoration: const InputDecoration(labelText: 'Room type'),
            ),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            DropdownButtonFormField<String>(
              value: _currency,
              items: const [
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
              ],
              onChanged: (v) => setState(() => _currency = v ?? 'EUR'),
              decoration: const InputDecoration(labelText: 'Currency'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range),
              label: Text(dateText),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminRoomTypeDto> roomTypes;
  final List<AdminRoomAvailabilityDto> availability;
  final Future<void> Function() onSaved;

  const _AvailabilitySection({
    required this.roomTypes,
    required this.availability,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Availability',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: roomTypes.isEmpty
                    ? null
                    : () => _openAvailabilityForm(context, roomTypes, onSaved),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (availability.isEmpty)
            const Text('No availability records yet.',
                style: TextStyle(color: _textMuted))
          else
            Column(
              children: availability
                  .map(
                    (a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dateFmt.format(a.date)),
                      subtitle: Text(
                        roomTypes
                                .firstWhere(
                                  (rt) => rt.id == a.roomTypeId,
                                  orElse: () => roomTypes.first,
                                )
                                .name +
                            ' • ${a.available} available',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _openAvailabilityForm(
                              context,
                              roomTypes,
                              onSaved,
                              existing: a,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 18, color: Colors.redAccent),
                            onPressed: () => _deleteAvailability(context, a, onSaved),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _openAvailabilityForm(
    BuildContext context,
    List<AdminRoomTypeDto> roomTypes,
    Future<void> Function() onSaved,
    {AdminRoomAvailabilityDto? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _AvailabilityForm(
            roomTypes: roomTypes,
            onSaved: onSaved,
            existing: existing,
          ),
        );
      },
    );
  }

  Future<void> _deleteAvailability(
    BuildContext context,
    AdminRoomAvailabilityDto availability,
    Future<void> Function() onSaved,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete availability'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final api = context.read<RoomWiseApiClient>();
    try {
      await api.deleteAdminRoomAvailability(availability.id);
      await onSaved();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}

class _AvailabilityForm extends StatefulWidget {
  final List<AdminRoomTypeDto> roomTypes;
  final Future<void> Function() onSaved;
  final AdminRoomAvailabilityDto? existing;

  const _AvailabilityForm({
    required this.roomTypes,
    required this.onSaved,
    this.existing,
  });

  @override
  State<_AvailabilityForm> createState() => _AvailabilityFormState();
}

class _AvailabilityFormState extends State<_AvailabilityForm> {
  final _formKey = GlobalKey<FormState>();
  int? _roomTypeId;
  DateTime? _date;
  final _available = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _roomTypeId = widget.existing!.roomTypeId;
      _date = widget.existing!.date;
      _available.text = widget.existing!.available.toString();
    } else if (widget.roomTypes.isNotEmpty) {
      _roomTypeId = widget.roomTypes.first.id;
    }
  }

  @override
  void dispose() {
    _available.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (res != null) setState(() => _date = res);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roomTypeId == null || _date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select room type and date')),
      );
      return;
    }
    setState(() => _saving = true);
    final api = context.read<RoomWiseApiClient>();
    try {
      final req = AdminRoomAvailabilityUpsertRequest(
        roomTypeId: _roomTypeId!,
        date: _date!,
        available: int.tryParse(_available.text) ?? 0,
      );
      if (widget.existing != null) {
        await api.updateAdminRoomAvailability(widget.existing!.id, req);
      } else {
        await api.createAdminRoomAvailability(req);
      }
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final dateText =
        _date == null ? 'Select date' : DateFormat('dd MMM yyyy').format(_date!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              isEdit ? 'Edit availability' : 'New availability',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _roomTypeId,
              items: widget.roomTypes
                  .map(
                    (rt) => DropdownMenuItem(
                      value: rt.id,
                      child: Text(rt.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _roomTypeId = v),
              decoration: const InputDecoration(labelText: 'Room type'),
            ),
            TextFormField(
              controller: _available,
              decoration: const InputDecoration(labelText: 'Available rooms'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.date_range),
              label: Text(dateText),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagesSection extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminHotelImageDto> images;
  final Future<void> Function() onChanged;

  const _ImagesSection({required this.images, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openImageForm(context),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (images.isEmpty)
            const Text('No images yet.', style: TextStyle(color: _textMuted))
          else
            Column(
              children: images
                  .map(
                    (img) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          img.url,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                      title: Text(img.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Order ${img.sortOrder}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _delete(context, img),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _openImageForm(BuildContext context) {
    showModalBottomSheet<AdminHotelImageUpsertRequest>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: const _ImageForm(),
        );
      },
    ).then((req) async {
      if (req == null) return;
      final api = context.read<RoomWiseApiClient>();
      try {
        await api.createAdminHotelImage(req);
        await onChanged();
      } catch (e) {
        if (!context.mounted) return;
        final msg = _formatError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $msg')),
        );
      }
    });
  }

  Future<void> _delete(BuildContext context, AdminHotelImageDto img) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final api = context.read<RoomWiseApiClient>();
    try {
      await api.deleteAdminHotelImage(img.id);
      await onChanged();
    } catch (e) {
      if (!context.mounted) return;
      final msg = _formatError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $msg')),
      );
    }
  }

  String _formatError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      return 'HTTP ${code ?? '?'} ${data ?? ''}'.trim();
    }
    return e.toString();
  }
}

class _RoomImagesSection extends StatefulWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminRoomTypeDto> roomTypes;
  final List<AdminRoomTypeImageDto> images;
  final Future<void> Function() onChanged;

  const _RoomImagesSection({
    required this.roomTypes,
    required this.images,
    required this.onChanged,
  });

  @override
  State<_RoomImagesSection> createState() => _RoomImagesSectionState();
}

class _RoomImagesSectionState extends State<_RoomImagesSection> {
  int? _selectedRoomTypeId;

  @override
  void initState() {
    super.initState();
    if (widget.roomTypes.isNotEmpty) {
      _selectedRoomTypeId = widget.roomTypes.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.images
        .where((img) => _selectedRoomTypeId == null || img.roomTypeId == _selectedRoomTypeId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Room images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ImagesSection._textPrimary,
                ),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: _selectedRoomTypeId,
                items: widget.roomTypes
                    .map(
                      (rt) => DropdownMenuItem(
                        value: rt.id,
                        child: Text(rt.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedRoomTypeId = v),
                hint: const Text('Room type'),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: _selectedRoomTypeId == null
                    ? null
                    : () => _openForm(context, roomTypeId: _selectedRoomTypeId!),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Text('No images yet.', style: TextStyle(color: _ImagesSection._textMuted))
          else
            Column(
              children: filtered
                  .map(
                    (img) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          img.url,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                      title: Text(img.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Order ${img.sortOrder}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: () => _move(img, -1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: () => _move(img, 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _openForm(
                              context,
                              roomTypeId: img.roomTypeId,
                              existing: img,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                            onPressed: () => _delete(context, img),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _move(AdminRoomTypeImageDto img, int delta) async {
    if (_selectedRoomTypeId == null) return;
    final list = widget.images
        .where((i) => i.roomTypeId == _selectedRoomTypeId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = list.indexWhere((i) => i.id == img.id);
    final newIdx = idx + delta;
    if (idx < 0 || newIdx < 0 || newIdx >= list.length) return;
    final item = list.removeAt(idx);
    list.insert(newIdx, item);
    final payload = list
        .asMap()
        .entries
        .map((e) => AdminRoomTypeImageReorderItem(id: e.value.id, sortOrder: e.key + 1))
        .toList();
    final api = context.read<RoomWiseApiClient>();
    try {
      await api.reorderAdminRoomTypeImages(payload);
      await widget.onChanged();
    } catch (e) {
      if (!context.mounted) return;
      final msg = _formatError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reorder failed: $msg')),
      );
    }
  }

  void _openForm(
    BuildContext context, {
    required int roomTypeId,
    AdminRoomTypeImageDto? existing,
  }) {
    showModalBottomSheet<AdminRoomTypeImageUpsertRequest>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _RoomImageForm(
            roomTypeId: roomTypeId,
            existing: existing,
          ),
        );
      },
    ).then((req) async {
      if (req == null) return;
      final api = context.read<RoomWiseApiClient>();
      try {
        if (existing == null) {
          await api.createAdminRoomTypeImage(req);
        } else {
          await api.updateAdminRoomTypeImage(existing.id, req);
        }
        await widget.onChanged();
      } catch (e) {
        if (!context.mounted) return;
        final msg = _formatError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $msg')),
        );
      }
    });
  }

  Future<void> _delete(
    BuildContext context,
    AdminRoomTypeImageDto img,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete room image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final api = context.read<RoomWiseApiClient>();
    try {
      await api.deleteAdminRoomTypeImage(img.id);
      await widget.onChanged();
    } catch (e) {
      if (!context.mounted) return;
      final msg = _formatError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $msg')),
      );
    }
  }

  String _formatError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      return 'HTTP ${code ?? '?'} ${data ?? ''}'.trim();
    }
    return e.toString();
  }
}

class _RoomImageForm extends StatefulWidget {
  final int roomTypeId;
  final AdminRoomTypeImageDto? existing;

  const _RoomImageForm({required this.roomTypeId, this.existing});

  @override
  State<_RoomImageForm> createState() => _RoomImageFormState();
}

class _RoomImageFormState extends State<_RoomImageForm> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _order = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _url.text = widget.existing!.url;
      _order.text = widget.existing!.sortOrder.toString();
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              widget.existing == null ? 'Add room image' : 'Edit room image',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'Image URL'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _order,
              decoration: const InputDecoration(labelText: 'Sort order'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final req = AdminRoomTypeImageUpsertRequest(
      roomTypeId: widget.roomTypeId,
      url: _url.text.trim(),
      sortOrder: int.tryParse(_order.text) ?? 1,
    );
    Navigator.of(context).pop(req);
  }
}

class _ImageForm extends StatefulWidget {
  const _ImageForm();

  @override
  State<_ImageForm> createState() => _ImageFormState();
}

class _ImageFormState extends State<_ImageForm> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _order = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void dispose() {
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final req = AdminHotelImageUpsertRequest(
      url: _url.text.trim(),
      sortOrder: int.tryParse(_order.text) ?? 1,
    );
    Navigator.of(context).pop(req);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Text(
              'Add image',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'Image URL'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _order,
              decoration: const InputDecoration(labelText: 'Sort order'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
