import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/admin_user_dto.dart';
import 'package:roomwise/core/models/loyalty_dtos.dart';
import 'package:roomwise/core/models/review_dto.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
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
  final NumberFormat _compact = NumberFormat.compact();

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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final history = loyalty?.history ?? const <LoyaltyHistoryItemDto>[];
        return _UserDetailsSheet(
          user: user,
          loyaltyBalance: loyalty?.balance ?? user.loyaltyBalance,
          history: history,
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _sortedUsers();
    final filteredReviews = _filteredReviews();

    final kpis = _UsersKpis.from(users: _users, reviews: _reviews);

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
          ? const _UsersSkeleton(key: ValueKey('loading'))
          : _error != null
          ? _ErrorCard(
              key: const ValueKey('error'),
              message: _error!,
              onRetry: _load,
            )
          : _UsersBody(
              key: const ValueKey('body'),
              users: filteredUsers,
              reviews: filteredReviews,
              compact: _compact,
              kpis: kpis,
              userSort: _userSort,
              searchController: _searchCtrl,
              onUserSearchChanged: (v) => setState(() => _search = v),
              onUserSortChanged: (v) => setState(() => _userSort = v),
              reviewFilter: _reviewFilter,
              reviewSort: _reviewSort,
              reviewSearchController: _reviewSearchCtrl,
              onReviewSearchChanged: (v) => setState(() => _reviewSearch = v),
              onReviewFilterChanged: (v) => setState(() => _reviewFilter = v),
              onReviewSortChanged: (v) => setState(() => _reviewSort = v),
              onTapUser: _showUser,
            ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UsersHeroHeader(
            title: 'Users & reviews',
            subtitle: 'Explore users and monitor hotel feedback.',
            loading: _loading,
            onRefresh: _load,
          ),
          const SizedBox(height: 14),
          content,
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
        list.sort(
          (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
            b.createdAt ?? DateTime(0),
          ),
        );
        break;
      case 'Newest':
      default:
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
    }
    return list;
  }
}

class _UsersHeroHeader extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onRefresh;

  const _UsersHeroHeader({
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
                  const Icon(Icons.people_alt_outlined, color: _textPrimary),
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

class _UsersKpis {
  final int totalUsers;
  final int newUsers30d;
  final int totalLoyalty;
  final int totalReviews;
  final double avgRating;

  const _UsersKpis({
    required this.totalUsers,
    required this.newUsers30d,
    required this.totalLoyalty,
    required this.totalReviews,
    required this.avgRating,
  });

  factory _UsersKpis.from({
    required List<AdminUserSummaryDto> users,
    required List<ReviewDto> reviews,
  }) {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 30));
    final newUsers = users.where((u) => u.createdAt.isAfter(since)).length;
    final loyalty = users.fold<int>(0, (p, u) => p + u.loyaltyBalance);
    final reviewCount = reviews.length;
    final avg = reviewCount == 0
        ? 0.0
        : reviews.fold<double>(0, (p, r) => p + r.rating) / reviewCount;
    return _UsersKpis(
      totalUsers: users.length,
      newUsers30d: newUsers,
      totalLoyalty: loyalty,
      totalReviews: reviewCount,
      avgRating: avg,
    );
  }
}

class _UsersBody extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);

  final List<AdminUserSummaryDto> users;
  final List<ReviewDto> reviews;
  final NumberFormat compact;
  final _UsersKpis kpis;
  final String userSort;
  final TextEditingController searchController;
  final ValueChanged<String> onUserSearchChanged;
  final ValueChanged<String> onUserSortChanged;
  final String reviewFilter;
  final String reviewSort;
  final TextEditingController reviewSearchController;
  final ValueChanged<String> onReviewSearchChanged;
  final ValueChanged<String> onReviewFilterChanged;
  final ValueChanged<String> onReviewSortChanged;
  final void Function(AdminUserSummaryDto) onTapUser;

  const _UsersBody({
    super.key,
    required this.users,
    required this.reviews,
    required this.compact,
    required this.kpis,
    required this.userSort,
    required this.searchController,
    required this.onUserSearchChanged,
    required this.onUserSortChanged,
    required this.reviewFilter,
    required this.reviewSort,
    required this.reviewSearchController,
    required this.onReviewSearchChanged,
    required this.onReviewFilterChanged,
    required this.onReviewSortChanged,
    required this.onTapUser,
  });

  @override
  Widget build(BuildContext context) {
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
                    icon: Icons.people_outline,
                    label: 'Users',
                    accent: const Color(0xFF3B82F6),
                    value: _CountUpText.int(value: kpis.totalUsers),
                    hint: '+${kpis.newUsers30d} last 30d',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.card_giftcard,
                    label: 'Loyalty',
                    accent: const Color(0xFF8B5CF6),
                    value: _CountUpText.int(value: kpis.totalLoyalty),
                    hint: 'Total points',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.rate_review_outlined,
                    label: 'Reviews',
                    accent: const Color(0xFFF59E0B),
                    value: _CountUpText.int(value: kpis.totalReviews),
                    hint: kpis.totalReviews == 0
                        ? 'No reviews yet'
                        : 'Avg ${kpis.avgRating.toStringAsFixed(1)} ★',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.insights_outlined,
                    label: 'Rating',
                    accent: const Color(0xFF05A87A),
                    value: Text(
                      kpis.totalReviews == 0
                          ? '—'
                          : kpis.avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                    hint: kpis.totalReviews == 0
                        ? 'No data'
                        : '${compact.format(kpis.totalReviews)} reviews',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _UsersFiltersCard(
          searchController: searchController,
          sortValue: userSort,
          onSearchChanged: onUserSearchChanged,
          onSortChanged: onUserSortChanged,
        ),
        const SizedBox(height: 12),
        _UsersCard(users: users, onTap: onTapUser),
        const SizedBox(height: 12),
        _ReviewsFiltersCard(
          searchController: reviewSearchController,
          rating: reviewFilter,
          sort: reviewSort,
          onSearchChanged: onReviewSearchChanged,
          onRatingChanged: onReviewFilterChanged,
          onSortChanged: onReviewSortChanged,
        ),
        const SizedBox(height: 12),
        _ReviewsCard(reviews: reviews),
      ],
    );
  }
}

class _UsersFiltersCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);

  final TextEditingController searchController;
  final String sortValue;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortChanged;

  const _UsersFiltersCard({
    required this.searchController,
    required this.sortValue,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

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
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear',
                          ),
                    hintText: 'Search by email or name',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              _PillSelect<String>(
                value: sortValue,
                items: const [
                  'Joined newest',
                  'Joined oldest',
                  'Loyalty high',
                  'Loyalty low',
                ],
                onChanged: onSortChanged,
                icon: Icons.sort,
                labelBuilder: (v) => switch (v) {
                  'Joined newest' => 'Joined newest',
                  'Joined oldest' => 'Joined oldest',
                  'Loyalty high' => 'Loyalty high → low',
                  'Loyalty low' => 'Loyalty low → high',
                  _ => v,
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewsFiltersCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);

  final TextEditingController searchController;
  final String rating;
  final String sort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRatingChanged;
  final ValueChanged<String> onSortChanged;

  const _ReviewsFiltersCard({
    required this.searchController,
    required this.rating,
    required this.sort,
    required this.onSearchChanged,
    required this.onRatingChanged,
    required this.onSortChanged,
  });

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
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear',
                          ),
                    hintText: 'Search reviews',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'All', label: Text('All')),
                  ButtonSegment(value: '4+', label: Text('4+')),
                  ButtonSegment(value: '3+', label: Text('3+')),
                ],
                selected: {rating},
                onSelectionChanged: (s) => onRatingChanged(s.first),
              ),
              _PillSelect<String>(
                value: sort,
                items: const ['Newest', 'Oldest', 'Rating high', 'Rating low'],
                onChanged: onSortChanged,
                icon: Icons.swap_vert,
                labelBuilder: (v) => switch (v) {
                  'Newest' => 'Newest',
                  'Oldest' => 'Oldest',
                  'Rating high' => 'Rating high → low',
                  'Rating low' => 'Rating low → high',
                  _ => v,
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillSelect<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final IconData icon;
  final String Function(T)? labelBuilder;

  const _PillSelect({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: Icon(icon, size: 18),
          items: items
              .map(
                (s) => DropdownMenuItem<T>(
                  value: s,
                  child: Text(labelBuilder?.call(s) ?? '$s'),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _UsersCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final List<AdminUserSummaryDto> users;
  final void Function(AdminUserSummaryDto) onTap;

  const _UsersCard({required this.users, required this.onTap});

  String _initials(AdminUserSummaryDto u) {
    final name = '${u.firstName} ${u.lastName}'.trim();
    if (name.isNotEmpty) {
      final parts = name
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        final first = parts.first.isNotEmpty ? parts.first[0] : '';
        final last = parts.length > 1 && parts.last.isNotEmpty
            ? parts.last[0]
            : '';
        final out = (first + last).toUpperCase();
        return out.isEmpty ? 'U' : out;
      }
    }
    final email = u.email.trim();
    return email.isEmpty ? 'U' : email[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Users',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${users.length}',
                style: const TextStyle(
                  color: _textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (users.isEmpty)
            const Text('No users yet.', style: TextStyle(color: _textMuted))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 18, color: Colors.black.withOpacity(0.06)),
              itemBuilder: (_, i) {
                final u = users[i];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(
                    milliseconds: 260 + (i * 28).clamp(0, 200),
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) {
                    return Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * 10),
                        child: child,
                      ),
                    );
                  },
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onTap(u),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.06),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials(u),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${u.firstName} ${u.lastName}'.trim().isEmpty
                                      ? 'Joined ${DateFormat('dd MMM yyyy').format(u.createdAt)}'
                                      : '${u.firstName} ${u.lastName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _Badge(
                            label: 'Loyalty',
                            value: u.loyaltyBalance.toString(),
                            accent: const Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _textMuted.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String label;
  final String value;
  final Color accent;

  const _Badge({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w900,
            ),
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
    final avg = reviews.isEmpty
        ? 0.0
        : reviews.fold<double>(0, (p, r) => p + r.rating) / reviews.length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              if (reviews.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${reviews.length}',
                      style: const TextStyle(
                        color: _textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  '0',
                  style: TextStyle(
                    color: _textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (reviews.isEmpty)
            const Text('No reviews yet.', style: TextStyle(color: _textMuted))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 18, color: Colors.black.withOpacity(0.06)),
              itemBuilder: (_, i) {
                final r = reviews[i];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(
                    milliseconds: 260 + (i * 28).clamp(0, 200),
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) {
                    return Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * 10),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Icon(
                          Icons.star,
                          color: Colors.amber.shade700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  r.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r.title ?? 'Review',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  r.createdAt != null
                                      ? DateFormat(
                                          'dd MMM',
                                        ).format(r.createdAt!)
                                      : '',
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (r.body ?? '').trim().isEmpty
                                  ? '—'
                                  : (r.body ?? ''),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _UsersSkeleton extends StatefulWidget {
  const _UsersSkeleton({super.key});

  @override
  State<_UsersSkeleton> createState() => _UsersSkeletonState();
}

class _UsersSkeletonState extends State<_UsersSkeleton>
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(width: 90, height: 14, r: BorderRadius.circular(8)),
                  const SizedBox(height: 10),
                  box(height: 42),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(width: 90, height: 14, r: BorderRadius.circular(8)),
                  const SizedBox(height: 10),
                  ...List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: box(height: 70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(width: 90, height: 14, r: BorderRadius.circular(8)),
                  const SizedBox(height: 10),
                  ...List.generate(
                    2,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: box(height: 78),
                    ),
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

class _UserDetailsSheet extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final AdminUserSummaryDto user;
  final int loyaltyBalance;
  final List<LoyaltyHistoryItemDto> history;
  final VoidCallback onClose;

  const _UserDetailsSheet({
    required this.user,
    required this.loyaltyBalance,
    required this.history,
    required this.onClose,
  });

  String _initials(AdminUserSummaryDto u) {
    final name = '${u.firstName} ${u.lastName}'.trim();
    if (name.isNotEmpty) {
      final parts = name
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        final first = parts.first.isNotEmpty ? parts.first[0] : '';
        final last = parts.length > 1 && parts.last.isNotEmpty
            ? parts.last[0]
            : '';
        final out = (first + last).toUpperCase();
        return out.isEmpty ? 'U' : out;
      }
    }
    final email = u.email.trim();
    return email.isEmpty ? 'U' : email[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final items = history;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Material(
            color: const Color(0xFFF8FAFC),
            child: CustomScrollView(
              controller: controller,
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE8ECFF), Color(0xFFEFFBF6)],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ),
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
                            Center(
                              child: Container(
                                width: 44,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF3B82F6,
                                    ).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.06),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _initials(user),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: _textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${user.firstName} ${user.lastName}'
                                            .trim(),
                                        style: const TextStyle(
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: onClose,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(
                                      0.75,
                                    ),
                                  ),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _Badge(
                              label: 'Loyalty balance',
                              value: loyaltyBalance.toString(),
                              accent: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Loyalty history',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (items.isEmpty)
                            const Text(
                              'No history',
                              style: TextStyle(color: _textMuted),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 18,
                                color: Colors.black.withOpacity(0.06),
                              ),
                              itemBuilder: (_, i) {
                                final h = items[i];
                                final reason = (h.reason ?? 'Loyalty change')
                                    .toString();
                                final createdAt = h.createdAt;
                                final delta = h.delta;
                                final isPos = delta >= 0;
                                return Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            (isPos
                                                    ? const Color(0xFF05A87A)
                                                    : const Color(0xFFEF4444))
                                                .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.black.withOpacity(0.06),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        isPos ? Icons.add : Icons.remove,
                                        color: isPos
                                            ? const Color(0xFF05A87A)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reason,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: _textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat(
                                              'dd MMM yyyy',
                                            ).format(createdAt),
                                            style: const TextStyle(
                                              color: _textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isPos ? '+$delta' : '$delta',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: isPos
                                            ? const Color(0xFF05A87A)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: onClose,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
