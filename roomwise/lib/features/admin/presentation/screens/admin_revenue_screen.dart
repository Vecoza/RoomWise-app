import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/addon_dto.dart';
import 'package:roomwise/core/models/admin_addon_upsert.dart';
import 'package:roomwise/core/models/admin_promotion_dto.dart';
import 'package:roomwise/core/models/admin_reservation_summary_dto.dart';
import 'package:roomwise/core/models/admin_stats_dto.dart';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _loading = true;
  String? _error;
  int _year = DateTime.now().year;
  List<MonthlyRevenuePointDto> _revenue = const [];
  AdminReservationSummaryDto? _summary;
  List<AddonDto> _addons = const [];
  List<AdminPromotionDto> _promotions = const [];

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
      debugPrint('[AdminRevenue] load year=$_year');
      final results = await Future.wait([
        api.getAdminRevenueByMonth(year: _year),
        api.getAdminReservationSummary(),
        api.getAdminAddOns(),
        api.getAdminPromotions(),
      ]);
      final revenue = results[0] as List<MonthlyRevenuePointDto>;
      debugPrint(
        '[AdminRevenue] revenue points: '
        '${revenue.map((e) => '${e.month}:${e.revenue}').toList()}',
      );
      debugPrint(
        '[AdminRevenue] summary=${(results[1] as AdminReservationSummaryDto).totalRevenue} '
        'addons=${(results[2] as List<AddonDto>).length} '
        'promotions=${(results[3] as List<AdminPromotionDto>).length}',
      );
      if (!mounted) return;
      setState(() {
        _revenue = revenue;
        _summary = results[1] as AdminReservationSummaryDto;
        _addons = results[2] as List<AddonDto>;
        _promotions = results[3] as List<AdminPromotionDto>;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      final msg = (code == 401 || code == 403)
          ? 'Not authorized to view revenue/offers. Please log in with a hotel administrator account.'
          : 'Failed to load data (HTTP ${code ?? '??'}).';
      setState(() {
        _loading = false;
        _error = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load data.';
      });
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
                'Revenue & offers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: _year,
                items: List.generate(
                  5,
                  (i) => DateTime.now().year - 2 + i,
                )
                    .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _year = v);
                  _load();
                },
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
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
            _RevenueChart(revenue: _revenue),
            const SizedBox(height: 12),
            if (_summary != null) _SummaryCard(summary: _summary!),
            const SizedBox(height: 12),
            _AddOnsCard(addons: _addons, onChanged: _load),
            const SizedBox(height: 12),
            _PromotionsCard(promotions: _promotions, onChanged: _load),
          ],
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<MonthlyRevenuePointDto> revenue;

  const _RevenueChart({required this.revenue});

  @override
  Widget build(BuildContext context) {
    final monthValues = List<double>.filled(12, 0);
    for (final p in revenue) {
      final idx = (p.month - 1).clamp(0, 11);
      monthValues[idx] = p.revenue;
    }
    final maxVal =
        monthValues.fold<double>(0, (prev, v) => v > prev ? v : prev);
    final normalized =
        monthValues.map((v) => maxVal == 0 ? 0.0 : v / maxVal).toList();
    debugPrint(
      '[AdminRevenue] chart values=$monthValues max=$maxVal '
      'normalized=${normalized.map((e) => e.toStringAsFixed(2)).toList()}',
    );
    final hasData = maxVal > 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue by month',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: revenue.isEmpty || !hasData
                ? const Center(
                    child: Text(
                      'No revenue data for this year.',
                      style: TextStyle(color: _textMuted),
                    ),
                  )
                : CustomPaint(
                    foregroundPainter: _BarsPainter(values: normalized),
                    child: Container(color: const Color(0xFFF9FAFB)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;

  const _BarsPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = h * i / 5;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final barCount = 12;
    final gap = 6.0;
    final barW = (w - gap * (barCount + 1)) / barCount;
    final maxBarH = h * 0.78;
    debugPrint('[AdminRevenue] painter values=$values');

    for (int i = 0; i < barCount; i++) {
      final v = i < values.length ? values[i] : 0.0;
      final barH = maxBarH * v;
      final x = gap + i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, h - barH - 12, barW, barH),
        const Radius.circular(6),
      );
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SummaryCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final AdminReservationSummaryDto summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reservation summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(label: 'Reservations', value: summary.totalReservations.toString()),
              _Chip(label: 'Nights', value: summary.totalNights.toString()),
              _Chip(
                label: 'Revenue',
                value: summary.totalRevenue.toStringAsFixed(0),
                color: const Color(0xFF05A87A),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Status breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (summary.statusBreakdown.isEmpty)
            const Text('No data', style: TextStyle(color: _textMuted))
          else
            Column(
              children: summary.statusBreakdown
                  .map(
                    (s) => Row(
                      children: [
                        Expanded(child: Text(s.status)),
                        Text(s.count.toString()),
                      ],
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AddOnsCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AddonDto> addons;
  final Future<void> Function() onChanged;

  const _AddOnsCard({required this.addons, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Add-ons',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (addons.isEmpty)
            const Text('No add-ons yet.', style: TextStyle(color: _textMuted))
          else
            Column(
              children: addons
                  .map(
                    (a) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: a.isActive,
                      onChanged: (v) => _save(
                        context,
                        a.id,
                        AdminAddonUpsertRequest(
                          name: a.name,
                          description: a.description,
                          pricingModel: a.pricingModel,
                          price: a.price,
                          currency: a.currency,
                          isActive: v,
                        ),
                      ),
                      title: Text(a.name),
                      subtitle: Text(
                        '${a.pricingModel} • ${a.currency} ${a.price.toStringAsFixed(0)}',
                      ),
                      secondary: const Icon(Icons.extension),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context) {
    showModalBottomSheet<AdminAddonUpsertRequest>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: const _AddonForm(),
        );
      },
    ).then((req) async {
      if (req == null) return;
      await _save(context, null, req);
    });
  }

  Future<void> _save(
    BuildContext context,
    int? id,
    AdminAddonUpsertRequest req,
  ) async {
    final api = context.read<RoomWiseApiClient>();
    try {
      if (id == null) {
        await api.createAdminAddOn(req);
      } else {
        await api.updateAdminAddOn(id, req);
      }
      await onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}

class _PromotionsCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminPromotionDto> promotions;
  final Future<void> Function() onChanged;

  const _PromotionsCard({
    required this.promotions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Promotions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.local_offer_outlined),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (promotions.isEmpty)
            const Text('No promotions yet.', style: TextStyle(color: _textMuted))
          else
            Column(
              children: promotions
                  .map(
                    (p) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: p.isActive,
                      onChanged: (v) => _save(
                        context,
                        p.id,
                        AdminPromotionUpsertRequest(
                          title: p.title,
                          description: p.description,
                          discountPercent: p.discountPercent,
                          discountFixed: p.discountFixed,
                          startDate: p.startDate,
                          endDate: p.endDate,
                          minNights: p.minNights,
                          isActive: v,
                        ),
                      ),
                      title: Text(p.title),
                      subtitle: Text(
                        _describePromo(p),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: const Icon(Icons.local_offer_outlined),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  String _describePromo(AdminPromotionDto p) {
    final parts = <String>[];
    if (p.discountPercent != null) {
      parts.add('${p.discountPercent!.toStringAsFixed(0)}% off');
    } else if (p.discountFixed != null) {
      parts.add('Discount ${p.discountFixed!.toStringAsFixed(0)}');
    }
    if (p.startDate != null && p.endDate != null) {
      parts.add(
        '${DateFormat('dd MMM').format(p.startDate!)} - ${DateFormat('dd MMM yyyy').format(p.endDate!)}',
      );
    }
    if (p.minNights != null) parts.add('Min nights: ${p.minNights}');
    return parts.isEmpty ? 'No details' : parts.join(' • ');
  }

  void _openForm(BuildContext context) {
    showModalBottomSheet<AdminPromotionUpsertRequest>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: const _PromotionForm(),
        );
      },
    ).then((req) async {
      if (req == null) return;
      await _save(context, null, req);
    });
  }

  Future<void> _save(
    BuildContext context,
    int? id,
    AdminPromotionUpsertRequest req,
  ) async {
    final api = context.read<RoomWiseApiClient>();
    try {
      if (id == null) {
        await api.createAdminPromotion(req);
      } else {
        await api.updateAdminPromotion(id, req);
      }
      await onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}

class _AddonForm extends StatefulWidget {
  const _AddonForm();

  @override
  State<_AddonForm> createState() => _AddonFormState();
}

class _AddonFormState extends State<_AddonForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController(text: '0');
  String _pricingModel = 'PerStay';
  String _currency = 'EUR';
  bool _active = true;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final req = AdminAddonUpsertRequest(
      name: _name.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      pricingModel: _pricingModel,
      price: double.tryParse(_price.text) ?? 0,
      currency: _currency,
      isActive: _active,
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
              'Add add-on',
              style: TextStyle(
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
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            DropdownButtonFormField<String>(
              value: _pricingModel,
              items: const [
                DropdownMenuItem(value: 'PerStay', child: Text('Per stay')),
                DropdownMenuItem(value: 'PerNight', child: Text('Per night')),
              ],
              onChanged: (v) => setState(() => _pricingModel = v ?? 'PerStay'),
              decoration: const InputDecoration(labelText: 'Pricing model'),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Active'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionForm extends StatefulWidget {
  const _PromotionForm();

  @override
  State<_PromotionForm> createState() => _PromotionFormState();
}

class _PromotionFormState extends State<_PromotionForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _discountPercent = TextEditingController();
  final _discountFixed = TextEditingController();
  final _minNights = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _active = true;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _discountPercent.dispose();
    _discountFixed.dispose();
    _minNights.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_discountPercent.text.isEmpty && _discountFixed.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter percent or fixed discount')),
      );
      return;
    }
    final req = AdminPromotionUpsertRequest(
      title: _title.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      discountPercent: _discountPercent.text.isEmpty
          ? null
          : double.tryParse(_discountPercent.text),
      discountFixed: _discountFixed.text.isEmpty
          ? null
          : double.tryParse(_discountFixed.text),
      startDate: _start,
      endDate: _end,
      minNights: _minNights.text.isEmpty ? null : int.tryParse(_minNights.text),
      isActive: _active,
    );
    Navigator.of(context).pop(req);
  }

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'Add promotion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextFormField(
              controller: _discountPercent,
              decoration: const InputDecoration(labelText: 'Discount percent'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: _discountFixed,
              decoration: const InputDecoration(labelText: 'Discount fixed'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: _minNights,
              decoration: const InputDecoration(labelText: 'Min nights'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range),
              label: Text(dateText),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Active'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Chip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color ?? const Color(0xFF111827),
            ),
          ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
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

  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

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
