import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/admin_room_type_dto.dart';
import 'package:roomwise/core/models/admin_user_dto.dart';
import 'package:roomwise/core/models/review_dto.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _loading = true;
  String? _error;
  List<AdminUserSummaryDto> _users = const [];
  List<ReviewDto> _reviews = const [];
  String _userSort = 'Joined newest';
  String _search = '';
  String _reviewFilter = 'All';
  String _reviewSort = 'Newest';
  String _reviewSearch = '';

  final _searchCtrl = TextEditingController();
  final _reviewSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reviewSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = context.read<RoomWiseApiClient>();
    try {
      int? hotelId;
      try {
        final roomTypes = await api.getAdminRoomTypes();
        if (roomTypes.isNotEmpty) hotelId = roomTypes.first.hotelId;
      } catch (_) {}

      final users = await api.getAdminUsers();
      final reviews = hotelId != null
          ? await api.getAdminHotelReviews(hotelId)
          : const <ReviewDto>[];

      if (!mounted) return;
      setState(() {
        _users = users;
        _reviews = reviews;
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
            : 'Failed to load users.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load users.';
      });
    }
  }

  Future<void> _showUser(AdminUserSummaryDto user) async {
    final api = context.read<RoomWiseApiClient>();
    AdminUserLoyaltyDto? loyalty;
    try {
      loyalty = await api.getAdminUserLoyalty(user.userId);
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final history = loyalty?.history ?? const [];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                user.email,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${user.firstName} ${user.lastName}'.trim(),
                style: const TextStyle(color: _textMuted),
              ),
              const SizedBox(height: 6),
              Text(
                'Loyalty balance: ${loyalty?.balance ?? user.loyaltyBalance}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Loyalty history',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              if (history.isEmpty)
                const Text(
                  'No history',
                  style: TextStyle(color: _textMuted),
                )
              else
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (_, i) {
                      final h = history[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          h.reason ?? 'Loyalty change',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(h.createdAt)),
                        trailing: Text(
                          h.delta >= 0 ? '+${h.delta}' : h.delta.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: h.delta >= 0
                                ? const Color(0xFF05A87A)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _sortedUsers();
    final filteredReviews = _filteredReviews();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Users & reviews',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 10),
          _UserFilters(
            searchController: _searchCtrl,
            userSort: _userSort,
            onSearchChanged: (v) => setState(() => _search = v),
            onSortChanged: (v) => setState(() => _userSort = v),
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
            _UsersCard(users: filteredUsers, onTap: _showUser),
            const SizedBox(height: 12),
            _ReviewFilters(
              rating: _reviewFilter,
              sort: _reviewSort,
              searchController: _reviewSearchCtrl,
              onSearchChanged: (v) => setState(() => _reviewSearch = v),
              onRatingChanged: (v) => setState(() => _reviewFilter = v),
              onSortChanged: (v) => setState(() => _reviewSort = v),
            ),
            const SizedBox(height: 8),
            _ReviewsCard(reviews: filteredReviews),
          ],
        ],
      ),
    );
  }

  List<AdminUserSummaryDto> _sortedUsers() {
    final q = _search.toLowerCase();
    var list = _users.where((u) {
      if (q.isEmpty) return true;
      return u.email.toLowerCase().contains(q) ||
          u.firstName.toLowerCase().contains(q) ||
          u.lastName.toLowerCase().contains(q);
    }).toList();

    switch (_userSort) {
      case 'Joined oldest':
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Loyalty high':
        list.sort((a, b) => b.loyaltyBalance.compareTo(a.loyaltyBalance));
        break;
      case 'Loyalty low':
        list.sort((a, b) => a.loyaltyBalance.compareTo(b.loyaltyBalance));
        break;
      case 'Joined newest':
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  List<ReviewDto> _filteredReviews() {
    final minRating = switch (_reviewFilter) {
      '4+' => 4.0,
      '3+' => 3.0,
      _ => 0.0,
    };

    final q = _reviewSearch.toLowerCase();
    var list = _reviews.where((r) {
      final passesRating = (r.rating) >= minRating;
      if (!passesRating) return false;
      if (q.isEmpty) return true;
      final title = (r.title ?? '').toLowerCase();
      final body = (r.body ?? '').toLowerCase();
      return title.contains(q) || body.contains(q);
    }).toList();
    switch (_reviewSort) {
      case 'Rating high':
        list.sort((a, b) => (b.rating).compareTo(a.rating));
        break;
      case 'Rating low':
        list.sort((a, b) => (a.rating).compareTo(b.rating));
        break;
      case 'Oldest':
        list.sort((a, b) => (a.createdAt ?? DateTime(0))
            .compareTo(b.createdAt ?? DateTime(0)));
        break;
      case 'Newest':
      default:
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
    }
    return list;
  }
}

class _UserFilters extends StatelessWidget {
  final TextEditingController searchController;
  final String userSort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortChanged;

  const _UserFilters({
    required this.searchController,
    required this.userSort,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by email or name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        DropdownButton<String>(
          value: userSort,
          items: const [
            DropdownMenuItem(value: 'Joined newest', child: Text('Joined newest')),
            DropdownMenuItem(value: 'Joined oldest', child: Text('Joined oldest')),
            DropdownMenuItem(value: 'Loyalty high', child: Text('Loyalty high → low')),
            DropdownMenuItem(value: 'Loyalty low', child: Text('Loyalty low → high')),
          ],
          onChanged: (v) {
            if (v != null) onSortChanged(v);
          },
        ),
      ],
    );
  }
}

class _ReviewFilters extends StatelessWidget {
  final String rating;
  final String sort;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRatingChanged;
  final ValueChanged<String> onSortChanged;

  const _ReviewFilters({
    required this.rating,
    required this.sort,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRatingChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search reviews',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        DropdownButton<String>(
          value: rating,
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All ratings')),
            DropdownMenuItem(value: '4+', child: Text('4+ stars')),
            DropdownMenuItem(value: '3+', child: Text('3+ stars')),
          ],
          onChanged: (v) {
            if (v != null) onRatingChanged(v);
          },
        ),
        DropdownButton<String>(
          value: sort,
          items: const [
            DropdownMenuItem(value: 'Newest', child: Text('Newest')),
            DropdownMenuItem(value: 'Oldest', child: Text('Oldest')),
            DropdownMenuItem(
                value: 'Rating high', child: Text('Rating high → low')),
            DropdownMenuItem(
                value: 'Rating low', child: Text('Rating low → high')),
          ],
          onChanged: (v) {
            if (v != null) onSortChanged(v);
          },
        ),
      ],
    );
  }
}

class _UsersCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminUserSummaryDto> users;
  final void Function(AdminUserSummaryDto) onTap;

  const _UsersCard({required this.users, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Users',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (users.isEmpty)
            const Text('No users yet.', style: TextStyle(color: _textMuted))
          else
            Column(
              children: users
                  .map(
                    (u) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(u.email),
                      subtitle: Text(
                        '${u.firstName} ${u.lastName}'.trim().isEmpty
                            ? 'Joined ${DateFormat('dd MMM yyyy').format(u.createdAt)}'
                            : '${u.firstName} ${u.lastName}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Loyalty',
                            style: TextStyle(color: _textMuted, fontSize: 12),
                          ),
                          Text(
                            u.loyaltyBalance.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => onTap(u),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<ReviewDto> reviews;

  const _ReviewsCard({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (reviews.isEmpty)
            const Text('No reviews yet.', style: TextStyle(color: _textMuted))
          else
            Column(
              children: reviews
                  .map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                          const SizedBox(width: 4),
                          Text(r.rating?.toStringAsFixed(1) ?? '0'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.title ?? 'Review',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        r.body ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        r.createdAt != null
                            ? DateFormat('dd MMM').format(r.createdAt!)
                            : '',
                        style: const TextStyle(color: _textMuted, fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
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

  const _Card({required this.child});

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
      child: child,
    );
  }
}
