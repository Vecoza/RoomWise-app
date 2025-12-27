import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/admin_promotion_dto.dart';
import 'package:roomwise/core/models/admin_reservation_summary_dto.dart';
import 'package:roomwise/core/models/admin_stats_dto.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _error;
  AdminOverviewStatsDto _overview = AdminOverviewStatsDto.empty;
  List<MonthlyRevenuePointDto> _revenue = const [];
  List<AdminPromotionDto> _promotions = const [];
  List<AdminTopUserDto> _topUsers = const [];
  int _year = DateTime.now().year;

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
      final currentYear = _year;
      final summaryFuture = api
          .getAdminReservationSummary()
          .then<AdminReservationSummaryDto?>((value) => value)
          .catchError((_) => null);
      final results = await Future.wait<Object?>([
        api.getAdminStatsOverview(),
        api.getAdminRevenueByMonth(year: currentYear),
        api.getAdminPromotions(),
        api.getAdminTopUsers(),
        summaryFuture,
      ]);
      final overview = results[0] as AdminOverviewStatsDto;
      var revenue = results[1] as List<MonthlyRevenuePointDto>;
      final summary = results[4] as AdminReservationSummaryDto?;
      if (revenue.every((p) => p.revenue == 0) && currentYear > 2000) {
        final prevYear = currentYear - 1;
        try {
          final prev = await api.getAdminRevenueByMonth(year: prevYear);
          if (prev.any((p) => p.revenue > 0)) {
            revenue = prev;
            _year = prevYear;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      final mergedOverview = summary == null
          ? overview
          : AdminOverviewStatsDto(
              totalRevenue: summary.totalRevenue,
              totalReservations: summary.totalReservations,
              totalUsers: overview.totalUsers,
              avgStayLengthNights: overview.avgStayLengthNights,
              occupancyRateLast30Days: overview.occupancyRateLast30Days,
            );
      setState(() {
        _overview = mergedOverview;
        _revenue = revenue;
        _promotions =
            (results[2] as List<AdminPromotionDto>)
                .where((p) => p.isActive)
                .toList()
              ..sort((a, b) {
                double va = (a.discountPercent ?? 0) + (a.discountFixed ?? 0);
                double vb = (b.discountPercent ?? 0) + (b.discountFixed ?? 0);
                return vb.compareTo(va);
              });
        _topUsers = results[3] as List<AdminTopUserDto>;
        _loading = false;
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await context.read<AuthState>().logout();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Session expired. Please log in again.';
        });
        return;
      }

      debugPrint('Admin stats load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load admin stats. Please try again.';
      });
    } catch (e) {
      debugPrint('Admin stats load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load admin stats. Please try again.';
      });
    }
  }

  double get _netIncome {
    return _overview.earnings;
  }

  double get _commission {
    final commission = _overview.totalRevenue - _netIncome;
    return commission < 0 ? 0 : commission;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 1100;
    final twoCol = w >= 980;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StaggeredIn(
              index: 0,
              child: _DashboardHeroHeader(
                title: 'Dashboard',
                subtitle: 'Overview of your hotel performance.',
                loading: _loading,
                onRefresh: _load,
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              _StaggeredIn(
                index: 1,
                child: _ErrorCard(message: _error!, onRetry: _load),
              )
            else ...[
              _StaggeredIn(
                index: 1,
                child: _StatGrid(
                  overview: _overview,
                  currency: _currency,
                  loading: _loading,
                ),
              ),
              const SizedBox(height: 16),
              _StaggeredIn(
                index: 2,
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _ProfitMarginCard(
                              revenue: _revenue,
                              loading: _loading,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _TopPackagesCard(
                              promotions: _promotions,
                              loading: _loading,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _ProfitMarginCard(
                            revenue: _revenue,
                            loading: _loading,
                          ),
                          const SizedBox(height: 16),
                          _TopPackagesCard(
                            promotions: _promotions,
                            loading: _loading,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _StaggeredIn(
                index: 3,
                child: twoCol
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _TopUsersTableCard(
                              users: _topUsers,
                              loading: _loading,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _TotalIncomeCard(
                              netIncome: _netIncome,
                              commission: _commission,
                              currency: _currency,
                              loading: _loading,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _TopUsersTableCard(
                            users: _topUsers,
                            loading: _loading,
                          ),
                          const SizedBox(height: 16),
                          _TotalIncomeCard(
                            netIncome: _netIncome,
                            commission: _commission,
                            currency: _currency,
                            loading: _loading,
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardHeroHeader extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onRefresh;

  const _DashboardHeroHeader({
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
                  const Icon(Icons.dashboard_outlined, color: _textPrimary),
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
                  const _PillChip(label: 'Live', active: true),
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatGrid extends StatelessWidget {
  final AdminOverviewStatsDto overview;
  final NumberFormat currency;
  final bool loading;

  const _StatGrid({
    required this.overview,
    required this.currency,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final revenueValue = loading
        ? const _SkeletonBar(width: 96, height: 18)
        : _CountUpText.currency(
            value: overview.totalRevenue,
            currency: currency,
          );
    final reservationsValue = loading
        ? const _SkeletonBar(width: 56, height: 18)
        : _CountUpText.int(value: overview.totalReservations);
    final usersValue = loading
        ? const _SkeletonBar(width: 56, height: 18)
        : _CountUpText.int(value: overview.totalUsers);
    final earningsValue = loading
        ? const _SkeletonBar(width: 88, height: 18)
        : _CountUpText.currency(value: overview.earnings, currency: currency);

    final tiles = [
      _KpiTile(
        icon: Icons.show_chart,
        label: 'Total revenue',
        value: revenueValue,
        hint: loading ? null : 'Gross for the period',
        accent: const Color(0xFF7C5CFC),
      ),
      _KpiTile(
        icon: Icons.home_outlined,
        label: 'Reservations',
        value: reservationsValue,
        hint: loading ? null : 'Total bookings',
        accent: const Color(0xFFFF7A3C),
      ),
      _KpiTile(
        icon: Icons.group_outlined,
        label: 'Users',
        value: usersValue,
        hint: loading ? null : 'Registered guests',
        accent: const Color(0xFF05A87A),
      ),
      _KpiTile(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Earnings',
        value: earningsValue,
        hint: loading ? null : 'Net after commission',
        accent: const Color(0xFF1D4ED8),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final fourCol = c.maxWidth >= 1100;
        final twoCol = c.maxWidth >= 560;

        if (fourCol) {
          return Row(
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 10),
              Expanded(child: tiles[1]),
              const SizedBox(width: 10),
              Expanded(child: tiles[2]),
              const SizedBox(width: 10),
              Expanded(child: tiles[3]),
            ],
          );
        }

        if (twoCol) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: tiles[0]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[1]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: tiles[2]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[3]),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            tiles[0],
            const SizedBox(height: 10),
            tiles[1],
            const SizedBox(height: 10),
            tiles[2],
            const SizedBox(height: 10),
            tiles[3],
          ],
        );
      },
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

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
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

class _StaggeredIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = 40 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

class _ProfitMarginCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _chartBottomInset = 36.0;

  final List<MonthlyRevenuePointDto> revenue;
  final bool loading;

  const _ProfitMarginCard({required this.revenue, required this.loading});

  @override
  Widget build(BuildContext context) {
    final values = List<double>.generate(12, (i) {
      final month = i + 1;
      final v = revenue.firstWhere(
        (p) => p.month == month,
        orElse: () => MonthlyRevenuePointDto(month: month, revenue: 0),
      );
      return v.revenue;
    });

    final hasData = values.any((v) => v > 0);
    final maxVal = values.fold<double>(0, (prev, v) => math.max(prev, v));
    final normalized = maxVal <= 0
        ? List<double>.filled(12, 0)
        : values.map((v) => v / maxVal).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Profit margin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              SizedBox(width: 10),
              _PillChip(label: '12 months', active: true),
              Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: loading
                  ? Container(
                      color: const Color(0xFFF9FAFB),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : hasData
                  ? Container(
                      color: const Color(0xFFF9FAFB),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AreaChartPainter(
                                values: normalized,
                                bottomInset: _chartBottomInset,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: const [
                                  _MonthLabel('Jan'),
                                  _MonthLabel('Feb'),
                                  _MonthLabel('Mar'),
                                  _MonthLabel('Apr'),
                                  _MonthLabel('May'),
                                  _MonthLabel('Jun'),
                                  _MonthLabel('Jul'),
                                  _MonthLabel('Aug'),
                                  _MonthLabel('Sep'),
                                  _MonthLabel('Oct'),
                                  _MonthLabel('Nov'),
                                  _MonthLabel('Dec'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: const Color(0xFFF9FAFB),
                      alignment: Alignment.center,
                      child: const Text(
                        'No revenue yet for this period.',
                        style: TextStyle(
                          color: _textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool active;

  const _PillChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFFDF8) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFFB7F3DF) : Colors.transparent,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF05A87A) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _MonthLabel extends StatelessWidget {
  final String month;

  const _MonthLabel(this.month);

  @override
  Widget build(BuildContext context) {
    return Text(
      month,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF6B7280),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double> values; // normalized 0..1 length 12
  final double bottomInset;

  const _AreaChartPainter({required this.values, this.bottomInset = 36});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final chartH = (h - bottomInset).clamp(0.0, h);
    if (w <= 0 || chartH <= 0) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = chartH * i / 5;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final path = _smoothPath(Size(w, chartH), values);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7C5CFC), Color(0xFF38BDF8)],
      ).createShader(Rect.fromLTWH(0, 0, w, chartH));

    canvas.drawPath(_closeToBottom(path, Size(w, chartH)), fill);

    final line = Paint()
      ..color = const Color(0xFF7C5CFC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, line);
  }

  Path _smoothPath(Size size, List<double> ys01) {
    final w = size.width;
    final h = size.height;
    final topInset = 8.0;
    final n = ys01.length;
    final dx = n <= 1 ? 0.0 : w / (n - 1);
    final points = List<Offset>.generate(n, (i) {
      final v = ys01[i].clamp(0.0, 1.0);
      return Offset(i * dx, topInset + (1 - v) * (h - topInset));
    }, growable: false);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cp = Offset((p0.dx + p1.dx) / 2, p0.dy);
      final cp2 = Offset((p0.dx + p1.dx) / 2, p1.dy);
      path.cubicTo(cp.dx, cp.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }
    return path;
  }

  Path _closeToBottom(Path path, Size size) {
    final p = Path.from(path);
    p.lineTo(size.width, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TopPackagesCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminPromotionDto> promotions;
  final bool loading;

  const _TopPackagesCard({required this.promotions, required this.loading});

  @override
  Widget build(BuildContext context) {
    final values = promotions
        .map((p) => (p.discountPercent ?? p.discountFixed ?? 0).toDouble())
        .toList();
    final labels = promotions.map((p) => p.title).toList();
    final hasValue = values.any((v) => v > 0);
    final isEmpty = promotions.isEmpty || !hasValue;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top packages',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Top packages in your hotel',
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: loading
                  ? Container(
                      color: const Color(0xFFF9FAFB),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : isEmpty
                  ? Container(
                      color: const Color(0xFFF9FAFB),
                      alignment: Alignment.center,
                      child: const Text(
                        'No packages yet.',
                        style: TextStyle(
                          color: _textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : CustomPaint(
                      foregroundPainter: _BarsPainter(
                        labels: labels.take(6).toList(),
                        values: values.take(6).toList(),
                      ),
                      child: Container(color: const Color(0xFFF9FAFB)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;

  const _BarsPainter({required this.labels, required this.values});

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

    final colors = const [
      Color(0xFFFF7A3C),
      Color(0xFF7C5CFC),
      Color(0xFF1D4ED8),
      Color(0xFF05A87A),
      Color(0xFFFF7A3C),
      Color(0xFF7C5CFC),
      Color(0xFF05A87A),
    ];

    final barCount = values.isEmpty ? 5 : values.length.clamp(1, 7);
    final displayedValues = values.isEmpty
        ? List<double>.filled(barCount, 0)
        : values.take(barCount).toList();
    final labelsShown = labels.isEmpty
        ? List<String>.generate(barCount, (i) => 'Pkg ${i + 1}')
        : labels.take(barCount).toList();

    final gap = 10.0;
    final barW = (w - gap * (barCount + 1)) / barCount;
    final maxBarH = h * 0.78;
    final maxVal = displayedValues.fold<double>(
      0,
      (prev, v) => math.max(prev, v),
    );

    for (int i = 0; i < barCount; i++) {
      final x = gap + i * (barW + gap);
      final v = maxVal <= 0 ? 0 : displayedValues[i] / maxVal;
      final barH = maxBarH * v;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, h - barH - 12, barW, barH),
        const Radius.circular(8),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors[i % colors.length].withOpacity(0.95),
            colors[i % colors.length].withOpacity(0.75),
          ],
        ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);

      final label = labelsShown[i];
      final short = label.length <= 8
          ? label
          : '${label.substring(0, 8).trimRight()}…';
      final tp = TextPainter(
        text: TextSpan(
          text: short,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: barW + gap);

      final dx = math.max(
        0.0,
        math.min(w - tp.width, x + (barW - tp.width) / 2),
      );
      final dy = h - tp.height;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TopUsersTableCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminTopUserDto> users;
  final bool loading;

  const _TopUsersTableCard({required this.users, required this.loading});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Top booking users',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              Spacer(),
              Icon(Icons.more_horiz, color: _textMuted),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final showPhone = w >= 680;
              final showEmail = w >= 520;

              if (loading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final rows = users.isEmpty
                  ? const [
                      AdminTopUserDto(
                        userId: '',
                        email: '',
                        fullName: 'No data yet',
                        reservationsCount: 0,
                        revenue: 0,
                      ),
                    ]
                  : users;

              return Column(
                children: [
                  _TableHeader(showEmail: showEmail, showPhone: showPhone),
                  const SizedBox(height: 6),
                  for (final r in rows)
                    _TableRow(
                      row: r,
                      showEmail: showEmail,
                      showPhone: showPhone,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  static const _muted = Color(0xFF6B7280);

  final bool showEmail;
  final bool showPhone;

  const _TableHeader({required this.showEmail, required this.showPhone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 2,
            child: Text(
              'Users',
              style: TextStyle(fontWeight: FontWeight.w800, color: _muted),
            ),
          ),
          if (showEmail)
            const Expanded(
              flex: 3,
              child: Text(
                'Email Address',
                style: TextStyle(fontWeight: FontWeight.w800, color: _muted),
              ),
            ),
          if (showPhone)
            const Expanded(
              flex: 2,
              child: Text(
                'Phone number',
                style: TextStyle(fontWeight: FontWeight.w800, color: _muted),
              ),
            ),
          const Expanded(
            child: Text(
              'No. of booking',
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w800, color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final AdminTopUserDto row;
  final bool showEmail;
  final bool showPhone;

  const _TableRow({
    required this.row,
    required this.showEmail,
    required this.showPhone,
  });

  @override
  Widget build(BuildContext context) {
    final initials = row.fullName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFFDF8),
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: const TextStyle(
                      color: Color(0xFF05A87A),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.fullName.isEmpty ? 'Unknown user' : row.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showEmail)
            Expanded(
              flex: 3,
              child: Text(
                row.email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textMuted),
              ),
            ),
          if (showPhone)
            Expanded(
              flex: 2,
              child: Text(
                '', // phone not provided in admin top-users payload
                style: const TextStyle(color: _textMuted),
              ),
            ),
          Expanded(
            child: Text(
              row.reservationsCount.toString(),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalIncomeCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final double netIncome;
  final double commission;
  final NumberFormat currency;
  final bool loading;

  const _TotalIncomeCard({
    required this.netIncome,
    required this.commission,
    required this.currency,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final gross = netIncome + commission;

    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFC).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.pie_chart_outline,
                  color: Color(0xFF7C5CFC),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total income',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Net vs commission',
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _PillChip(
                label: loading ? 'Loading' : 'Gross ${currency.format(gross)}',
                active: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const _IncomeDonutSkeleton()
          else
            _DonutChart(
              labelA: 'Net income',
              labelB: 'Commission',
              netIncome: netIncome,
              commission: commission,
              currency: currency,
              colorA: const Color(0xFF05A87A),
              colorB: const Color(0xFFFF7A3C),
            ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatefulWidget {
  final String labelA;
  final String labelB;
  final double netIncome;
  final double commission;
  final NumberFormat currency;
  final Color colorA;
  final Color colorB;

  const _DonutChart({
    required this.labelA,
    required this.labelB,
    required this.netIncome,
    required this.commission,
    required this.currency,
    required this.colorA,
    required this.colorB,
  });

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void didUpdateWidget(covariant _DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.netIncome != widget.netIncome ||
        oldWidget.commission != widget.commission) {
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gross = widget.netIncome + widget.commission;
    final total = gross <= 0 ? 1.0 : gross;
    final a = (widget.netIncome / total).clamp(0.0, 1.0);
    final b = (widget.commission / total).clamp(0.0, 1.0);

    final percentA = (a * 100).round();
    final percentB = (b * 100).round();

    return Column(
      children: [
        SizedBox(
          height: 236,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _DonutPainter(
                      valueA: a,
                      valueB: b,
                      progress: _controller.value,
                      colorA: widget.colorA,
                      colorB: widget.colorB,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Gross',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DefaultTextStyle.merge(
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                              child: _CountUpText.currency(
                                value: gross,
                                currency: widget.currency,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: Text(
                                '${widget.labelA} $percentA% • ${widget.labelB} $percentB%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _IncomeBreakdownRow(
          color: widget.colorA,
          label: widget.labelA,
          percent: percentA,
          value: widget.netIncome,
          currency: widget.currency,
        ),
        const SizedBox(height: 10),
        _IncomeBreakdownRow(
          color: widget.colorB,
          label: widget.labelB,
          percent: percentB,
          value: widget.commission,
          currency: widget.currency,
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double valueA;
  final double valueB;
  final double progress;
  final Color colorA;
  final Color colorB;

  const _DonutPainter({
    required this.valueA,
    required this.valueB,
    required this.progress,
    required this.colorA,
    required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.22;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE5E7EB), Color(0xFFF3F4F6)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - stroke / 2, bg);

    final total = (valueA + valueB).clamp(0.0001, double.infinity);
    final a = valueA / total;
    final b = valueB / total;

    var start = -math.pi / 2;
    final sweepA = 2 * math.pi * a;
    final sweepB = 2 * math.pi * b;
    final gap = 0.10;

    final sweepTotal = (sweepA + sweepB) * progress.clamp(0.0, 1.0);
    final drawA = math.min(sweepA, sweepTotal);
    final drawB = math.min(sweepB, math.max(0.0, sweepTotal - sweepA));

    final arcRect = Rect.fromCircle(
      center: center,
      radius: radius - stroke / 2,
    );

    if (drawA > 0.0001) {
      final paintA = Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + drawA,
          colors: [colorA.withOpacity(0.95), colorA.withOpacity(0.65)],
        ).createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, start, drawA, false, paintA);
    }

    final startB = start + sweepA + gap;
    final visibleSweepB = math.max(0.0, drawB - gap);
    if (visibleSweepB > 0.0001) {
      final paintB = Paint()
        ..shader = SweepGradient(
          startAngle: startB,
          endAngle: startB + visibleSweepB,
          colors: [colorB.withOpacity(0.95), colorB.withOpacity(0.65)],
        ).createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, startB, visibleSweepB, false, paintB);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.valueA != valueA ||
        oldDelegate.valueB != valueB ||
        oldDelegate.progress != progress ||
        oldDelegate.colorA != colorA ||
        oldDelegate.colorB != colorB;
  }
}

class _IncomeBreakdownRow extends StatelessWidget {
  final Color color;
  final String label;
  final int percent;
  final double value;
  final NumberFormat currency;

  const _IncomeBreakdownRow({
    required this.color,
    required this.label,
    required this.percent,
    required this.value,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (percent / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
              child: _CountUpText.currency(value: value, currency: currency),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeDonutSkeleton extends StatelessWidget {
  const _IncomeDonutSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 236,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Container(
                    width: 110,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}
