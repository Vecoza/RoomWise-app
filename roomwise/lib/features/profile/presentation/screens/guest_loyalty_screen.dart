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
  static const _primaryGreen = Color(0xFF05A87A);

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
      final historyPage = await api.getLoyaltyHistoryPage(page: 1, pageSize: 50);

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

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loyalty')),
        body: const Center(
          child: Text('You must be logged in to view loyalty points.'),
        ),
      );
    }

    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      final balance = _balance?.balance ?? 0;
      final history = _historyPage?.items ?? const <LoyaltyHistoryItemDto>[];

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, size: 32, color: _primaryGreen),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your loyalty balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$balance pts',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '1 pt = 1 € discount, earn 1 pt per 10 € spent.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'History',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'No loyalty activity yet.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (_, index) {
                      final item = history[index];
                      final isEarn = item.delta > 0;
                      final sign = item.delta > 0 ? '+' : '';
                      final color = isEarn ? Colors.green : Colors.redAccent;

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isEarn
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: color,
                        ),
                        title: Text(
                          '$sign${item.delta} pts',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.reason?.isNotEmpty == true)
                              Text(
                                item.reason!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            if (item.reservationCode?.isNotEmpty == true)
                              Text(
                                'Reservation ${item.reservationCode}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            Text(
                              _formatDateTime(item.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemCount: history.length,
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty')),
      body: body,
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
