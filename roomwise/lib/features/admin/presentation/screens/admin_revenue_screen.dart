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
  bool _loading = true;
  String? _error;
  int _year = DateTime.now().year;
  List<MonthlyRevenuePointDto> _revenue = const [];
  AdminReservationSummaryDto? _summary;
  List<AddonDto> _addons = const [];
  List<AdminPromotionDto> _promotions = const [];

  final NumberFormat _currency = NumberFormat.compactCurrency(
    symbol: '\$',
    decimalDigits: 1,
  );

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
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _loading
          ? const _RevenueSkeleton(key: ValueKey('loading'))
          : _error != null
          ? _ErrorCard(
              key: const ValueKey('error'),
              message: _error!,
              onRetry: _load,
            )
          : _RevenueBody(
              key: const ValueKey('body'),
              revenue: _revenue,
              summary: _summary,
              addons: _addons,
              promotions: _promotions,
              currency: _currency,
              onChanged: _load,
            ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RevenueHeroHeader(
            title: 'Revenue & offers',
            subtitle: 'Track income trends and manage add-ons & promotions.',
            loading: _loading,
            onRefresh: _load,
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }
}

class _RevenueHeroHeader extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onRefresh;

  const _RevenueHeroHeader({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8ECFF), Color(0xFFEFFBF6)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SoftCirclesPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart, color: _textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: _textMuted)),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading
                    ? const LinearProgressIndicator(
                        key: ValueKey('progress'),
                        minHeight: 3,
                      )
                    : const SizedBox(key: ValueKey('no-progress'), height: 3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftCirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF3B82F6).withOpacity(0.10);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.25), 70, paint);

    paint.color = const Color(0xFF05A87A).withOpacity(0.10);
    canvas.drawCircle(Offset(size.width * 0.20, size.height * 0.05), 55, paint);

    paint.color = Colors.white.withOpacity(0.35);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.95), 90, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<double> _monthValuesFromPoints(List<MonthlyRevenuePointDto> points) {
  final values = List<double>.filled(12, 0);
  for (final p in points) {
    assert(() {
      if (p.month < 1 || p.month > 12) {
        debugPrint(
          '[AdminRevenueChart] Unexpected month=${p.month} revenue=${p.revenue}',
        );
      }
      if (p.revenue.isNaN || p.revenue.isInfinite) {
        debugPrint(
          '[AdminRevenueChart] Invalid revenue month=${p.month} revenue=${p.revenue}',
        );
      }
      return true;
    }());
    final idx = (p.month - 1).clamp(0, 11);
    values[idx] = p.revenue;
  }
  return values;
}

double _maxValue(List<double> values) {
  return values.fold<double>(0, (prev, v) => v > prev ? v : prev);
}

class _RevenueSkeleton extends StatefulWidget {
  const _RevenueSkeleton({super.key});

  @override
  State<_RevenueSkeleton> createState() => _RevenueSkeletonState();
}

class _RevenueSkeletonState extends State<_RevenueSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final base =
            Color.lerp(Colors.grey.shade200, Colors.grey.shade100, t) ??
            Colors.grey.shade200;

        Widget box({double? width, required double height, BorderRadius? r}) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: base,
              borderRadius: r ?? BorderRadius.circular(16),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cols = w >= 980 ? 4 : (w >= 640 ? 2 : 1);
                final tileW = (w - (cols - 1) * 12) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(
                    4,
                    (i) => SizedBox(width: tileW, child: box(height: 74)),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _Card(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(width: 160, height: 14, r: BorderRadius.circular(8)),
                  const SizedBox(height: 10),
                  box(height: 240),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(width: 190, height: 14, r: BorderRadius.circular(8)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      box(width: 140, height: 54),
                      box(width: 120, height: 54),
                      box(width: 150, height: 54),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RevenueBody extends StatelessWidget {
  final List<MonthlyRevenuePointDto> revenue;
  final AdminReservationSummaryDto? summary;
  final List<AddonDto> addons;
  final List<AdminPromotionDto> promotions;
  final NumberFormat currency;
  final Future<void> Function() onChanged;

  const _RevenueBody({
    super.key,
    required this.revenue,
    required this.summary,
    required this.addons,
    required this.promotions,
    required this.currency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final monthValues = _monthValuesFromPoints(revenue);
    final maxVal = _maxValue(monthValues);
    final ytdRevenue = monthValues.fold<double>(0, (p, v) => p + v);

    final bestMonthIdx = monthValues.indexWhere(
      (v) => v == maxVal && maxVal > 0,
    );
    final bestMonthLabel = bestMonthIdx < 0
        ? '—'
        : DateFormat('MMM').format(DateTime(2000, bestMonthIdx + 1, 1));

    final activeAddons = addons.where((a) => a.isActive).length;
    final activePromotions = promotions.where((p) => p.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w >= 980 ? 4 : (w >= 640 ? 2 : 1);
            final tileW = (w - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.payments_outlined,
                    label: 'Year-to-date',
                    accent: const Color(0xFF05A87A),
                    value: _CountUpText.currency(
                      value: ytdRevenue,
                      currency: currency,
                    ),
                    hint: bestMonthIdx < 0
                        ? 'No revenue yet'
                        : 'Best: $bestMonthLabel',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.auto_graph,
                    label: 'Best month',
                    accent: const Color(0xFF3B82F6),
                    value: Text(
                      bestMonthLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    hint: bestMonthIdx < 0
                        ? '—'
                        : currency.format(monthValues[bestMonthIdx]),
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.extension,
                    label: 'Active add-ons',
                    accent: const Color(0xFF8B5CF6),
                    value: _CountUpText.int(value: activeAddons),
                    hint: '${addons.length} total',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.local_offer_outlined,
                    label: 'Active promotions',
                    accent: const Color(0xFFF59E0B),
                    value: _CountUpText.int(value: activePromotions),
                    hint: '${promotions.length} total',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _RevenueChartCard(revenue: revenue, currency: currency),
        const SizedBox(height: 12),
        if (summary != null)
          _SummaryCard(summary: summary!, currency: currency),
        const SizedBox(height: 12),
        _AddOnsCard(addons: addons, onChanged: onChanged),
        const SizedBox(height: 12),
        _PromotionsCard(promotions: promotions, onChanged: onChanged),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final IconData icon;
  final String label;
  final Widget value;
  final String? hint;
  final Color accent;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                  child: value,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _textMuted.withOpacity(0.95),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountUpText extends StatefulWidget {
  final double value;
  final String Function(double) format;

  const _CountUpText._({required this.value, required this.format});

  factory _CountUpText.int({required int value}) {
    return _CountUpText._(
      value: value.toDouble(),
      format: (v) => v.round().toString(),
    );
  }

  factory _CountUpText.currency({
    required double value,
    required NumberFormat currency,
  }) {
    return _CountUpText._(value: value, format: (v) => currency.format(v));
  }

  @override
  State<_CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<_CountUpText> {
  late double _from;

  @override
  void initState() {
    super.initState();
    _from = 0;
  }

  @override
  void didUpdateWidget(covariant _CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(widget.format(v)),
    );
  }
}

enum _RevenueChartMode { monthly, cumulative }

class _RevenueChartCard extends StatefulWidget {
  final List<MonthlyRevenuePointDto> revenue;
  final NumberFormat currency;

  const _RevenueChartCard({required this.revenue, required this.currency});

  @override
  State<_RevenueChartCard> createState() => _RevenueChartCardState();
}

class _RevenueChartCardState extends State<_RevenueChartCard>
    with SingleTickerProviderStateMixin {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  static const _barCount = 12;
  static const _hPadding = 12.0;
  static const _gap = 8.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  _RevenueChartMode _mode = _RevenueChartMode.monthly;
  int? _selectedIdx;
  String? _lastLogSignature;

  @override
  void initState() {
    super.initState();
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _RevenueChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revenue != widget.revenue) {
      _controller.forward(from: 0);
      _selectedIdx = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexForX(double x, double width) {
    final availableW = (width - _hPadding * 2).clamp(0, double.infinity);
    final barW = (availableW - _gap * (_barCount - 1)) / _barCount;
    final localX = (x - _hPadding).clamp(0, availableW);
    final i = (localX / (barW + _gap)).floor();
    return i.clamp(0, _barCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _monthValuesFromPoints(widget.revenue);
    final values = _mode == _RevenueChartMode.monthly
        ? monthly
        : List<double>.generate(
            monthly.length,
            (i) => monthly.take(i + 1).fold<double>(0, (p, v) => p + v),
          );
    final maxVal = _maxValue(values);
    final hasData = maxVal > 0;
    final normalized = values
        .map((v) => maxVal == 0 ? 0.0 : v / maxVal)
        .toList();

    assert(() {
      final sig =
          '${_mode.name}:${monthly.map((e) => e.toStringAsFixed(2)).join(',')}';
      if (sig != _lastLogSignature) {
        _lastLogSignature = sig;
        debugPrint('[AdminRevenueChart] mode=${_mode.name}');
        debugPrint('[AdminRevenueChart] monthly=$monthly');
        debugPrint('[AdminRevenueChart] values=$values');
        debugPrint(
          '[AdminRevenueChart] max=$maxVal hasData=$hasData '
          'normalized=${normalized.map((e) => e.toStringAsFixed(3)).toList()}',
        );
      }
      return true;
    }());

    final selected = (_selectedIdx != null)
        ? (
            index: _selectedIdx!,
            value: values[_selectedIdx!],
            month: DateFormat(
              'MMM',
            ).format(DateTime(2000, _selectedIdx! + 1, 1)),
          )
        : null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Revenue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              SegmentedButton<_RevenueChartMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _RevenueChartMode.monthly,
                    label: Text('Monthly'),
                  ),
                  ButtonSegment(
                    value: _RevenueChartMode.cumulative,
                    label: Text('Cumulative'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) {
                  setState(() => _mode = s.first);
                  _controller.forward(from: 0);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: selected == null
                ? const Text(
                    'Tap a bar to inspect a month.',
                    key: ValueKey('hint'),
                    style: TextStyle(color: _textMuted),
                  )
                : Text(
                    '${selected.month} • ${widget.currency.format(selected.value)}',
                    key: ValueKey('sel-${selected.index}'),
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 250,
              color: const Color(0xFFF9FAFB),
              child: !hasData
                  ? const Center(
                      child: Text(
                        'No revenue data for this year.',
                        style: TextStyle(color: _textMuted),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, c) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => setState(() {
                            _selectedIdx = _indexForX(
                              d.localPosition.dx,
                              c.maxWidth,
                            );
                          }),
                          onPanUpdate: (d) => setState(() {
                            _selectedIdx = _indexForX(
                              d.localPosition.dx,
                              c.maxWidth,
                            );
                          }),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _RevenueBarsPainter(
                                  values: normalized,
                                  progress: Curves.easeOutCubic.transform(
                                    _controller.value,
                                  ),
                                  selectedIndex: _selectedIdx,
                                ),
                                child: const SizedBox.expand(),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _MonthTick(label: 'Jan'),
              _MonthTick(label: 'Apr'),
              _MonthTick(label: 'Jul'),
              _MonthTick(label: 'Oct'),
              _MonthTick(label: 'Dec'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthTick extends StatelessWidget {
  static const _textMuted = Color(0xFF6B7280);
  final String label;

  const _MonthTick({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textMuted,
      ),
    );
  }
}

class _RevenueBarsPainter extends CustomPainter {
  static const _barCount = 12;
  static const _hPadding = 12.0;
  static const _gap = 8.0;

  final List<double> values;
  final double progress;
  final int? selectedIndex;

  const _RevenueBarsPainter({
    required this.values,
    required this.progress,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    assert(() {
      if (size.isEmpty) {
        debugPrint('[AdminRevenueChart] paint size=$size (EMPTY)');
      }
      if (values.any((v) => v.isNaN || v.isInfinite)) {
        debugPrint('[AdminRevenueChart] paint invalid values=$values');
      }
      return true;
    }());
    final w = size.width;
    final h = size.height;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = h * i / 5;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final availableW = (w - _hPadding * 2).clamp(0, double.infinity);
    final barW = (availableW - _gap * (_barCount - 1)) / _barCount;
    final maxBarH = h * 0.80;

    for (int i = 0; i < _barCount; i++) {
      final v = i < values.length ? values[i] : 0.0;
      final barH = maxBarH * v * progress;
      final x = _hPadding + i * (barW + _gap);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, h - barH - 10, barW, barH),
        const Radius.circular(10),
      );

      final isSelected = selectedIndex == i;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isSelected
              ? const [Color(0xFF1D4ED8), Color(0xFF60A5FA)]
              : const [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      if (isSelected) {
        final stroke = Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRRect(rect.inflate(1), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueBarsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.values != values;
  }
}

class _SummaryCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final AdminReservationSummaryDto summary;
  final NumberFormat currency;

  const _SummaryCard({required this.summary, required this.currency});

  @override
  Widget build(BuildContext context) {
    final totalStatusCount = summary.statusBreakdown.fold<int>(
      0,
      (p, v) => p + v.count,
    );

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
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w >= 640 ? 3 : 1;
              final tileW = cols == 1 ? w : (w - (cols - 1) * 10) / cols;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: tileW,
                    child: _SummaryMetricTile(
                      icon: Icons.event_available,
                      label: 'Reservations',
                      value: _CountUpText.int(value: summary.totalReservations),
                    ),
                  ),
                  SizedBox(
                    width: tileW,
                    child: _SummaryMetricTile(
                      icon: Icons.bedtime_outlined,
                      label: 'Nights',
                      value: _CountUpText.int(value: summary.totalNights),
                    ),
                  ),
                  SizedBox(
                    width: tileW,
                    child: _SummaryMetricTile(
                      icon: Icons.payments_outlined,
                      label: 'Revenue',
                      value: _CountUpText.currency(
                        value: summary.totalRevenue,
                        currency: currency,
                      ),
                      valueColor: const Color(0xFF05A87A),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Status breakdown',
            style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
          ),
          const SizedBox(height: 6),
          if (summary.statusBreakdown.isEmpty || totalStatusCount == 0)
            const Text('No data', style: TextStyle(color: _textMuted))
          else
            Column(
              children: summary.statusBreakdown.map((s) {
                final pct = totalStatusCount == 0
                    ? 0.0
                    : s.count / totalStatusCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.status,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            s.count.toString(),
                            style: const TextStyle(
                              color: _textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _AnimatedProgressBar(value: pct),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final IconData icon;
  final String label;
  final Widget value;
  final Color? valueColor;

  const _SummaryMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? _textPrimary,
                  ),
                  child: value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  final double value;

  const _AnimatedProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: v,
            minHeight: 7,
            backgroundColor: Colors.black.withOpacity(0.05),
          ),
        );
      },
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }
}

class _PromotionsCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminPromotionDto> promotions;
  final Future<void> Function() onChanged;

  const _PromotionsCard({required this.promotions, required this.onChanged});

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
            const Text(
              'No promotions yet.',
              style: TextStyle(color: _textMuted),
            )
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextFormField(
              controller: _discountFixed,
              decoration: const InputDecoration(labelText: 'Discount fixed'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({super.key, required this.message, required this.onRetry});

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
