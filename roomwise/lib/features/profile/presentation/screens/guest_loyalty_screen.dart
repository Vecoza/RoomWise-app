import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/loyalty_dtos.dart';

class GuestLoyaltyScreen extends StatefulWidget {
  const GuestLoyaltyScreen({super.key});

  @override
  State<GuestLoyaltyScreen> createState() => _GuestLoyaltyScreenState();
}

class _GuestLoyaltyScreenState extends State<GuestLoyaltyScreen> {
  // --- DESIGN TOKENS (keep in sync with Profile/Support screens) ---
  static const _primaryGreen = Color(0xFF05A87A);
  static const _bgColor = Color(0xFFF5F7FA);
  static const _cardColor = Colors.white;
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const double _cardRadius = 18;
  static const double _cardPadding = 16;

  bool _loading = true;
  String? _error;
  LoyaltyBalanceDto? _balance;
  LoyaltyHistoryPageDto? _historyPage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      setState(() {
        _loading = false;
        _error = 'You must be logged in to view loyalty points.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();
      final balance = await api.getLoyaltyBalance();
      final historyPage = await api.getLoyaltyHistoryPage(
        page: 1,
        pageSize: 50,
      );

      if (!mounted) return;
      setState(() {
        _balance = balance;
        _historyPage = historyPage;
        _loading = false;
      });
    } on DioException catch (e) {
      debugPrint('Load loyalty failed: $e');
      if (!mounted) return;
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await context.read<AuthState>().logout();
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
          ),
        );
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load loyalty data.';
        });
      }
    } catch (e) {
      debugPrint('Load loyalty failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load loyalty data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Loyalty'),
        backgroundColor: _bgColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: auth.isLoggedIn ? _buildLoggedIn() : _buildLoggedOut(),
      ),
    );
  }

  // ---------- LOGGED OUT ----------

  Widget _buildLoggedOut() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.card_giftcard, size: 64, color: _textMuted),
              SizedBox(height: 16),
              Text(
                'Loyalty points',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Sign in to start earning and tracking your loyalty points on every stay.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- LOGGED IN ----------

  Widget _buildLoggedIn() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildContent(),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildContent() {
    final balance = _balance?.balance ?? 0;
    final history = _historyPage?.items ?? const <LoyaltyHistoryItemDto>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryCard(balance),
        const SizedBox(height: 16),
        _buildHowItWorksCard(),
        const SizedBox(height: 16),
        _buildHistoryCard(history),
      ],
    );
  }

  // ---------- CARDS ----------

  Widget _buildSummaryCard(int balance) {
    return _loyaltyCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F9F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard,
              color: _primaryGreen,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your loyalty balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$balance pts',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Use your points to get instant discounts on future stays.',
                  style: TextStyle(fontSize: 12, color: _textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return _loyaltyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'How it works',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Earn 1 pt for every 10 € spent on eligible bookings.\n'
            '• Redeem points as a discount during checkout.\n'
            '• Points are added after your stay is completed.',
            style: TextStyle(fontSize: 12, color: _textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(List<LoyaltyHistoryItemDto> history) {
    return _loyaltyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'History',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Recent points you earned or used.',
            style: TextStyle(fontSize: 12, color: _textMuted),
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No loyalty activity yet.',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (_, index) {
                final item = history[index];
                final isEarn = item.delta > 0;
                final sign = item.delta > 0 ? '+' : '';
                final color = isEarn ? _primaryGreen : Colors.redAccent;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isEarn ? Icons.trending_up : Icons.trending_down,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$sign${item.delta} pts',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (item.reason?.isNotEmpty == true)
                            Text(
                              item.reason!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textPrimary,
                              ),
                            ),
                          if (item.reservationCode?.isNotEmpty == true)
                            Text(
                              'Reservation ${item.reservationCode}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                              ),
                            ),
                          Text(
                            _formatDateTime(item.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0xFFE5E7EB)),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- HELPERS ----------

  Widget _loyaltyCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }
}
