import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/admin_promotion_dto.dart';
import 'package:roomwise/core/models/admin_stats_dto.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

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
      final results = await Future.wait([
        api.getAdminStatsOverview(),
        api.getAdminRevenueByMonth(year: currentYear),
        api.getAdminPromotions(),
        api.getAdminTopUsers(),
      ]);
      var revenue = results[1] as List<MonthlyRevenuePointDto>;
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
      setState(() {
        _overview = results[0] as AdminOverviewStatsDto;
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

    Widget body;
    if (_error != null) {
      body = _ErrorCard(message: _error!, onRetry: _load);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8ECFF), Color(0xFFEFFBF6)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(width: 10),
                    _PillChip(label: 'Live', active: true),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Overview of your hotel performance.',
                  style: TextStyle(color: _textMuted),
                ),
                const SizedBox(height: 14),
                _StatGrid(
                  overview: _overview,
                  currency: _currency,
                  loading: _loading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (isWide)
            Row(
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
          else ...[
            _ProfitMarginCard(revenue: _revenue, loading: _loading),
            const SizedBox(height: 16),
            _TopPackagesCard(promotions: _promotions, loading: _loading),
          ],
          const SizedBox(height: 16),
          if (twoCol)
            Row(
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
          else ...[
            _TopUsersTableCard(users: _topUsers, loading: _loading),
            const SizedBox(height: 16),
            _TotalIncomeCard(
              netIncome: _netIncome,
              commission: _commission,
              currency: _currency,
              loading: _loading,
            ),
          ],
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 60),
        child: body,
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
    final maxWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = maxWidth >= 1200 ? 4 : (maxWidth >= 880 ? 2 : 1);
    final spacing = 12.0;

    final items = [
      _StatCardData(
        title: 'Total revenue',
        value: currency.format(overview.totalRevenue),
        icon: Icons.show_chart,
        colorA: const Color(0xFF7C5CFC),
        colorB: const Color(0xFF9B8CFF),
      ),
      _StatCardData(
        title: 'Total reservations',
        value: overview.totalReservations.toString(),
        icon: Icons.home_outlined,
        colorA: const Color(0xFFFF7A3C),
        colorB: const Color(0xFFFFA169),
      ),
      _StatCardData(
        title: 'Total users',
        value: overview.totalUsers.toString(),
        icon: Icons.group_outlined,
        colorA: const Color(0xFF05A87A),
        colorB: const Color(0xFF38D39F),
      ),
      _StatCardData(
        title: 'Earnings',
        value: currency.format(overview.earnings),
        icon: Icons.account_balance_wallet_outlined,
        colorA: const Color(0xFF1D4ED8),
        colorB: const Color(0xFF3B82F6),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: loading
                    ? const _StatCardLoading()
                    : _StatCard(data: item),
              ),
          ],
        );
      },
    );
  }
}

class _StatCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color colorA;
  final Color colorB;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.colorA,
    required this.colorB,
  });
}

class _StatCard extends StatelessWidget {
  static const _textMuted = Color(0xFFEEF2FF);

  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [data.colorA, data.colorB],
        ),
        boxShadow: [
          BoxShadow(
            color: data.colorA.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardLoading extends StatelessWidget {
  const _StatCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ProfitMarginCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

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
                  ? CustomPaint(
                      foregroundPainter: _AreaChartPainter(values: normalized),
                      child: Container(
                        color: const Color(0xFFF9FAFB),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  const _AreaChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = h * i / 5;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final path = _smoothPath(size, values);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7C5CFC), Color(0xFF38BDF8)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(_closeToBottom(path, size), fill);

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
    final n = ys01.length;
    final dx = w / (n - 1);
    final points = List<Offset>.generate(
      n,
      (i) => Offset(i * dx, (1 - ys01[i]) * (h - 36)),
      growable: false,
    );

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
    final total = (netIncome + commission).clamp(1, double.infinity);
    final a = netIncome / total;
    final b = commission / total;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Income',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '↑ compared to last period',
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            _DonutChart(
              valueA: a,
              valueB: b,
              labelA: 'Net income',
              labelB: 'Commission',
              colorA: const Color(0xFF05A87A),
              colorB: const Color(0xFFFF7A3C),
              centerText: currency.format(netIncome),
            ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final double valueA;
  final double valueB;
  final String labelA;
  final String labelB;
  final Color colorA;
  final Color colorB;
  final String centerText;

  const _DonutChart({
    required this.valueA,
    required this.valueB,
    required this.labelA,
    required this.labelB,
    required this.colorA,
    required this.colorB,
    required this.centerText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _DonutPainter(
                  valueA: valueA,
                  valueB: valueB,
                  colorA: colorA,
                  colorB: colorB,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Income',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        centerText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: colorA, label: labelA),
            const SizedBox(width: 12),
            _LegendDot(color: colorB, label: labelB),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double valueA;
  final double valueB;
  final Color colorA;
  final Color colorB;

  const _DonutPainter({
    required this.valueA,
    required this.valueB,
    required this.colorA,
    required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.26;

    final bg = Paint()
      ..color = const Color(0xFFE5E7EB)
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

    final paintA = Paint()
      ..color = colorA
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final paintB = Paint()
      ..color = colorB
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - stroke / 2),
      start,
      sweepA,
      false,
      paintA,
    );
    start += sweepA + 0.08;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - stroke / 2),
      start,
      sweepB - 0.08,
      false,
      paintB,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
