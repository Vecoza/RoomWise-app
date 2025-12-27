import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/admin_hotel_image_dto.dart';
import 'package:roomwise/core/models/admin_room_availability_dto.dart';
import 'package:roomwise/core/models/admin_room_rate_dto.dart';
import 'package:roomwise/core/models/admin_room_type_dto.dart';
import 'package:roomwise/core/models/admin_room_type_image_dto.dart';

class AdminHotelsScreen extends StatefulWidget {
  const AdminHotelsScreen({super.key});

  @override
  State<AdminHotelsScreen> createState() => _AdminHotelsScreenState();
}

class _AdminHotelsScreenState extends State<AdminHotelsScreen> {
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _RoomTypeForm(existing: rt);
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
      debugPrint('Save failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _HotelsKpis.from(
      roomTypes: _roomTypes,
      rates: _roomRates,
      availability: _roomAvailability,
      images: _images,
      roomImages: _roomImages,
    );

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
          ? const _HotelsSkeleton(key: ValueKey('loading'))
          : _error != null
          ? _ErrorCard(
              key: const ValueKey('error'),
              message: _error!,
              onRetry: _load,
            )
          : _HotelsBody(
              key: const ValueKey('body'),
              kpis: kpis,
              hotel: _hotel,
              roomTypes: _roomTypes,
              roomRates: _roomRates,
              roomAvailability: _roomAvailability,
              images: _images,
              roomImages: _roomImages,
              onEditRoomType: _editRoomType,
              onReload: _load,
            ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HotelsHeroHeader(
            title: 'Hotel & rooms',
            subtitle: 'Manage room types, rates, availability, and images.',
            loading: _loading,
            onRefresh: _load,
            onAddRoomType: () => _editRoomType(),
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }
}

class _HotelsHeroHeader extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onAddRoomType;

  const _HotelsHeroHeader({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onRefresh,
    required this.onAddRoomType,
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
                  const Icon(Icons.apartment_outlined, color: _textPrimary),
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
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: loading ? null : onAddRoomType,
                    icon: const Icon(Icons.add),
                    label: const Text('Room type'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF05A87A),
                      foregroundColor: Colors.white,
                    ),
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

class _HotelsKpis {
  final int roomTypes;
  final int totalStock;
  final int rates;
  final int availabilityRecords;
  final int images;

  const _HotelsKpis({
    required this.roomTypes,
    required this.totalStock,
    required this.rates,
    required this.availabilityRecords,
    required this.images,
  });

  factory _HotelsKpis.from({
    required List<AdminRoomTypeDto> roomTypes,
    required List<AdminRoomRateDto> rates,
    required List<AdminRoomAvailabilityDto> availability,
    required List<AdminHotelImageDto> images,
    required List<AdminRoomTypeImageDto> roomImages,
  }) {
    final stock = roomTypes.fold<int>(0, (p, rt) => p + rt.stock);
    return _HotelsKpis(
      roomTypes: roomTypes.length,
      totalStock: stock,
      rates: rates.length,
      availabilityRecords: availability.length,
      images: images.length + roomImages.length,
    );
  }
}

class _HotelsBody extends StatelessWidget {
  final _HotelsKpis kpis;
  final Map<String, dynamic>? hotel;
  final List<AdminRoomTypeDto> roomTypes;
  final List<AdminRoomRateDto> roomRates;
  final List<AdminRoomAvailabilityDto> roomAvailability;
  final List<AdminHotelImageDto> images;
  final List<AdminRoomTypeImageDto> roomImages;
  final Future<void> Function(AdminRoomTypeDto? rt) onEditRoomType;
  final Future<void> Function() onReload;

  const _HotelsBody({
    super.key,
    required this.kpis,
    required this.hotel,
    required this.roomTypes,
    required this.roomRates,
    required this.roomAvailability,
    required this.images,
    required this.roomImages,
    required this.onEditRoomType,
    required this.onReload,
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
                    icon: Icons.meeting_room_outlined,
                    label: 'Room types',
                    accent: const Color(0xFF3B82F6),
                    value: _CountUpText.int(value: kpis.roomTypes),
                    hint: roomTypes.isEmpty
                        ? 'Add your first type'
                        : 'Stock ${kpis.totalStock}',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.sell_outlined,
                    label: 'Rates',
                    accent: const Color(0xFFF59E0B),
                    value: _CountUpText.int(value: kpis.rates),
                    hint: 'Price rules',
                  ),
                ),
                SizedBox(
                  width: tileW,
                  child: _KpiTile(
                    icon: Icons.event_available_outlined,
                    label: 'Availability',
                    accent: const Color(0xFF05A87A),
                    value: _CountUpText.int(value: kpis.availabilityRecords),
                    hint: 'Overrides',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (hotel != null)
          _HotelCard(hotel: hotel!)
        else
          const _PlaceholderCard(
            title: 'Hotel',
            subtitle: 'No hotel found for this account yet.',
          ),
        const SizedBox(height: 12),
        _RoomTypesSection(items: roomTypes, onEdit: onEditRoomType),
        const SizedBox(height: 12),
        _RatesSection(
          roomTypes: roomTypes,
          rates: roomRates,
          onSaved: onReload,
        ),
        const SizedBox(height: 12),
        _AvailabilitySection(
          roomTypes: roomTypes,
          availability: roomAvailability,
          onSaved: onReload,
        ),
        const SizedBox(height: 12),
        _ImagesSection(images: images, onChanged: onReload),
        const SizedBox(height: 12),
        _RoomImagesSection(
          roomTypes: roomTypes,
          images: roomImages,
          onChanged: onReload,
        ),
      ],
    );
  }
}

class _HotelsSkeleton extends StatefulWidget {
  const _HotelsSkeleton({super.key});

  @override
  State<_HotelsSkeleton> createState() => _HotelsSkeletonState();
}

class _HotelsSkeletonState extends State<_HotelsSkeleton>
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
                  box(width: 140, height: 14, r: BorderRadius.circular(8)),
                  const SizedBox(height: 10),
                  box(height: 70),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: box(height: 130),
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

class _HotelCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final Map<String, dynamic> hotel;

  const _HotelCard({required this.hotel});

  String _nonEmpty(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = hotel['createdAt'] != null
        ? DateTime.tryParse(hotel['createdAt'].toString())
        : null;
    final updatedAt = hotel['updatedAt'] != null
        ? DateTime.tryParse(hotel['updatedAt'].toString())
        : null;

    final address = _nonEmpty(hotel['addressLine']);
    final website = _nonEmpty(hotel['website']);
    final email = _nonEmpty(hotel['email']);
    final phone = _nonEmpty(hotel['phone']);

    return _Card(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (address.isNotEmpty)
                _InfoPill(icon: Icons.location_on_outlined, text: address),
              if (website.isNotEmpty)
                _InfoPill(icon: Icons.public, text: website),
              if (email.isNotEmpty)
                _InfoPill(icon: Icons.alternate_email, text: email),
              if (phone.isNotEmpty)
                _InfoPill(icon: Icons.phone_outlined, text: phone),
            ],
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

class _InfoPill extends StatelessWidget {
  static const _textMuted = Color(0xFF6B7280);
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _textMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
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
  final Future<void> Function(AdminRoomTypeDto?) onEdit;

  const _RoomTypesSection({required this.items, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.meeting_room_outlined, color: _textPrimary),
              const SizedBox(width: 10),
              const Text(
                'Room types',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length}',
                style: const TextStyle(
                  color: _textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 18, color: Colors.black.withOpacity(0.06)),
              itemBuilder: (_, i) {
                final rt = items[i];
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
                    onTap: () => onEdit(rt),
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
                            child: const Icon(
                              Icons.bed_outlined,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rt.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${rt.capacity} guests • ${rt.bedType ?? 'Bed'}',
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${rt.currency} ${rt.basePrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Stock ${rt.stock}',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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

class _RoomTypeForm extends StatefulWidget {
  final AdminRoomTypeDto? existing;

  const _RoomTypeForm({required this.existing});

  @override
  State<_RoomTypeForm> createState() => _RoomTypeFormState();
}

class _RoomTypeFormState extends State<_RoomTypeForm> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _capacity;
  late final TextEditingController _basePrice;
  late final TextEditingController _stock;
  late final TextEditingController _bedType;
  String _currency = 'EUR';
  bool _smoking = false;
  bool _submitting = false;

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

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
    );
  }

  String? _requiredText(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _positiveInt(String? v) {
    final parsed = int.tryParse((v ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed <= 0) return 'Must be > 0';
    return null;
  }

  String? _nonNegativeInt(String? v) {
    final parsed = int.tryParse((v ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be ≥ 0';
    return null;
  }

  String? _nonNegativeDouble(String? v) {
    final parsed = double.tryParse((v ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be ≥ 0';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;
    setState(() => _submitting = true);
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
    final title = widget.existing == null ? 'New room type' : 'Edit room type';
    final subtitle = widget.existing == null
        ? 'Define a room template guests can book.'
        : 'Update pricing and capacity details.';

    Widget capacityStockFields(bool twoCol) {
      final capacityField = TextFormField(
        controller: _capacity,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.number,
        decoration: _decoration(
          label: 'Capacity',
          hint: 'Guests',
          icon: Icons.groups_outlined,
        ),
        validator: _positiveInt,
      );
      final stockField = TextFormField(
        controller: _stock,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.number,
        decoration: _decoration(
          label: 'Stock',
          hint: 'Rooms',
          icon: Icons.inventory_2_outlined,
        ),
        validator: _nonNegativeInt,
      );

      if (twoCol) {
        return Row(
          children: [
            Expanded(child: capacityField),
            const SizedBox(width: 10),
            Expanded(child: stockField),
          ],
        );
      }
      return Column(
        children: [capacityField, const SizedBox(height: 10), stockField],
      );
    }

    Widget priceCurrencyFields(bool twoCol) {
      final priceField = TextFormField(
        controller: _basePrice,
        textInputAction: TextInputAction.done,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _decoration(
          label: 'Base price',
          hint: 'Per night',
          icon: Icons.payments_outlined,
        ),
        validator: _nonNegativeDouble,
      );
      final currencyField = DropdownButtonFormField<String>(
        value: _currency,
        items: const [
          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
          DropdownMenuItem(value: 'USD', child: Text('USD')),
        ],
        onChanged: (v) => setState(() => _currency = v ?? 'EUR'),
        decoration: _decoration(
          label: 'Currency',
          icon: Icons.currency_exchange,
        ),
      );

      if (twoCol) {
        return Row(
          children: [
            Expanded(flex: 2, child: priceField),
            const SizedBox(width: 10),
            Expanded(child: currencyField),
          ],
        );
      }
      return Column(
        children: [priceField, const SizedBox(height: 10), currencyField],
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
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
                              child: CustomPaint(
                                painter: _SoftCirclesPainter(),
                              ),
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
                                  const Icon(
                                    Icons.meeting_room_outlined,
                                    color: _textPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(
                                        0.75,
                                      ),
                                    ),
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Close',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Basics'),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _name,
                                    textInputAction: TextInputAction.next,
                                    decoration: _decoration(
                                      label: 'Name',
                                      hint: 'e.g. Deluxe double',
                                      icon: Icons.label_outline,
                                    ),
                                    validator: _requiredText,
                                  ),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, c) =>
                                        capacityStockFields(c.maxWidth >= 520),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _bedType,
                                    textInputAction: TextInputAction.next,
                                    decoration: _decoration(
                                      label: 'Bed type',
                                      hint: 'e.g. King, Twin',
                                      icon: Icons.bed_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.black.withOpacity(0.06),
                                      ),
                                    ),
                                    child: SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: _smoking,
                                      onChanged: (v) =>
                                          setState(() => _smoking = v),
                                      title: const Text('Smoking allowed'),
                                      subtitle: const Text(
                                        'Allow smoking in this room type.',
                                      ),
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
                                  const _SectionTitle(title: 'Pricing'),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, c) =>
                                        priceCurrencyFields(c.maxWidth >= 520),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tip: rates and promotions can override this base price.',
                                    style: TextStyle(
                                      color: _textMuted.withOpacity(0.95),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF05A87A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(_submitting ? 'Saving…' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);

  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: _textPrimary,
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
                            icon: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.redAccent,
                            ),
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
    Future<void> Function() onSaved, {
    AdminRoomRateDto? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _RateForm(
          roomTypes: roomTypes,
          onSaved: onSaved,
          existing: existing,
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
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
      debugPrint('Delete failed: $e');
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
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  int? _roomTypeId;
  DateTime? _start;
  DateTime? _end;
  final _price = TextEditingController(text: '0');
  String _currency = 'EUR';
  bool _saving = false;

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
    );
  }

  String? _nonNegativeDouble(String? v) {
    final parsed = double.tryParse((v ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be ≥ 0';
    return null;
  }

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

  AdminRoomTypeDto? _roomTypeFor(int? id) {
    if (id == null) return null;
    for (final rt in widget.roomTypes) {
      if (rt.id == id) return rt;
    }
    return null;
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
      debugPrint('Select room type and dates');
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
      debugPrint('Save failed: $e');
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

    final title = isEdit ? 'Edit rate' : 'New rate';
    final subtitle = isEdit
        ? 'Update price and date range.'
        : 'Set a price for a specific date range.';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
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
                          colors: [Color(0xFFFFF1F2), Color(0xFFEFFBF6)],
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
                              child: CustomPaint(
                                painter: _SoftCirclesPainter(),
                              ),
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
                                  const Icon(
                                    Icons.price_change_outlined,
                                    color: _textPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _saving
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(
                                        0.75,
                                      ),
                                    ),
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Close',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Details'),
                                  const SizedBox(height: 10),
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
                                    onChanged: (v) {
                                      setState(() {
                                        _roomTypeId = v;
                                        final rt = _roomTypeFor(v);
                                        if (rt != null) _currency = rt.currency;
                                      });
                                    },
                                    decoration: _decoration(
                                      label: 'Room type',
                                      icon: Icons.bed_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  FilledButton.tonalIcon(
                                    onPressed: _pickDateRange,
                                    icon: const Icon(Icons.date_range_outlined),
                                    label: Text(dateText),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
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
                                  const _SectionTitle(title: 'Pricing'),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final priceField = TextFormField(
                                        controller: _price,
                                        textInputAction: TextInputAction.next,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: _decoration(
                                          label: 'Price',
                                          hint: 'Per night',
                                          icon: Icons.payments_outlined,
                                        ),
                                        validator: _nonNegativeDouble,
                                      );
                                      final currencyField =
                                          DropdownButtonFormField<String>(
                                            value: _currency,
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'EUR',
                                                child: Text('EUR'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'USD',
                                                child: Text('USD'),
                                              ),
                                            ],
                                            onChanged: (v) => setState(
                                              () => _currency = v ?? 'EUR',
                                            ),
                                            decoration: _decoration(
                                              label: 'Currency',
                                              icon: Icons.currency_exchange,
                                            ),
                                          );

                                      if (c.maxWidth >= 520) {
                                        return Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: priceField,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(child: currencyField),
                                          ],
                                        );
                                      }
                                      return Column(
                                        children: [
                                          priceField,
                                          const SizedBox(height: 10),
                                          currencyField,
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tip: use rates to handle peak dates and promotions.',
                                    style: TextStyle(
                                      color: _textMuted.withOpacity(0.95),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF05A87A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(_saving ? 'Saving…' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
            const Text(
              'No availability records yet.',
              style: TextStyle(color: _textMuted),
            )
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
                            icon: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                _deleteAvailability(context, a, onSaved),
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
    Future<void> Function() onSaved, {
    AdminRoomAvailabilityDto? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _AvailabilityForm(
          roomTypes: roomTypes,
          onSaved: onSaved,
          existing: existing,
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
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
      debugPrint('Delete failed: $e');
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
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  int? _roomTypeId;
  DateTime? _date;
  final _available = TextEditingController(text: '0');
  bool _saving = false;

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
    );
  }

  String? _nonNegativeInt(String? v) {
    final parsed = int.tryParse((v ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be ≥ 0';
    return null;
  }

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
      debugPrint('Select room type and date');
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
      debugPrint('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final dateText = _date == null
        ? 'Select date'
        : DateFormat('dd MMM yyyy').format(_date!);

    final title = isEdit ? 'Edit availability' : 'New availability';
    final subtitle = isEdit
        ? 'Update inventory for this date.'
        : 'Set how many rooms are available.';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.74,
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
                          colors: [Color(0xFFE8ECFF), Color(0xFFFFF7ED)],
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
                              child: CustomPaint(
                                painter: _SoftCirclesPainter(),
                              ),
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
                                  const Icon(
                                    Icons.event_available_outlined,
                                    color: _textPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _saving
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(
                                        0.75,
                                      ),
                                    ),
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Close',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Details'),
                                  const SizedBox(height: 10),
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
                                    onChanged: (v) =>
                                        setState(() => _roomTypeId = v),
                                    decoration: _decoration(
                                      label: 'Room type',
                                      icon: Icons.bed_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  FilledButton.tonalIcon(
                                    onPressed: _pickDate,
                                    icon: const Icon(Icons.event_outlined),
                                    label: Text(dateText),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
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
                                  const _SectionTitle(title: 'Inventory'),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _available,
                                    textInputAction: TextInputAction.done,
                                    keyboardType: TextInputType.number,
                                    decoration: _decoration(
                                      label: 'Available rooms',
                                      hint: 'e.g. 12',
                                      icon: Icons.inventory_2_outlined,
                                    ),
                                    validator: _nonNegativeInt,
                                  ),
                                ],
                              ),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF05A87A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(_saving ? 'Saving…' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
              children: (List.of(images)
                    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
                  .map(
                    (img) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _SmartImage(
                        source: img.url,
                        width: 48,
                        height: 48,
                      ),
                      title: Text(
                        _imageLabel(img.url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('Order ${img.sortOrder}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: () => _move(context, img, -1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: () => _move(context, img, 1),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                              size: 18,
                            ),
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

  Future<void> _move(
    BuildContext context,
    AdminHotelImageDto img,
    int delta,
  ) async {
    final list = List.of(images)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = list.indexWhere((i) => i.id == img.id);
    final newIdx = idx + delta;
    if (idx < 0 || newIdx < 0 || newIdx >= list.length) return;
    final item = list.removeAt(idx);
    list.insert(newIdx, item);
    final payload = list
        .asMap()
        .entries
        .map(
          (e) => AdminHotelImageDto(
            id: e.value.id,
            hotelId: e.value.hotelId,
            url: e.value.url,
            sortOrder: e.key + 1,
          ),
        )
        .toList(growable: false);
    final api = context.read<RoomWiseApiClient>();
    try {
      await api.reorderAdminHotelImages(payload);
      await onChanged();
    } catch (e) {
      if (!context.mounted) return;
      final msg = _formatError(e);
      debugPrint('Reorder failed: $msg');
    }
  }

  void _openImageForm(BuildContext context) {
    final reservedOrders = images.map((img) => img.sortOrder).toSet();
    showModalBottomSheet<_HotelImageFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ImageForm(reservedOrders: reservedOrders);
      },
    ).then((result) async {
      if (result == null) return;
      final api = context.read<RoomWiseApiClient>();
      try {
        if (result.filePath != null) {
          await api.uploadAdminHotelImage(
            File(result.filePath!),
            sortOrder: result.sortOrder,
          );
        } else if (result.request != null) {
          await api.createAdminHotelImage(result.request!);
        }
        await onChanged();
      } catch (e) {
        if (!context.mounted) return;
        final msg = _formatError(e);
        debugPrint('Save failed: $msg');
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
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
      debugPrint('Delete failed: $msg');
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

  AdminRoomTypeImageDto? _imageForSortOrder(int roomTypeId, int sortOrder) {
    for (final img in widget.images) {
      if (img.roomTypeId == roomTypeId && img.sortOrder == sortOrder) {
        return img;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.roomTypes.isNotEmpty) {
      _selectedRoomTypeId = widget.roomTypes.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.images
            .where(
              (img) =>
                  _selectedRoomTypeId == null ||
                  img.roomTypeId == _selectedRoomTypeId,
            )
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
                      (rt) =>
                          DropdownMenuItem(value: rt.id, child: Text(rt.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedRoomTypeId = v),
                hint: const Text('Room type'),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: _selectedRoomTypeId == null
                    ? null
                    : () =>
                          _openForm(context, roomTypeId: _selectedRoomTypeId!),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Text(
              'No images yet.',
              style: TextStyle(color: _ImagesSection._textMuted),
            )
          else
            Column(
              children: filtered
                  .map(
                    (img) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _SmartImage(
                        source: img.url,
                        width: 48,
                        height: 48,
                      ),
                      title: Text(
                        _imageLabel(img.url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                              size: 18,
                            ),
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
    final list =
        widget.images.where((i) => i.roomTypeId == _selectedRoomTypeId).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = list.indexWhere((i) => i.id == img.id);
    final newIdx = idx + delta;
    if (idx < 0 || newIdx < 0 || newIdx >= list.length) return;
    final item = list.removeAt(idx);
    list.insert(newIdx, item);
    final payload = list
        .asMap()
        .entries
        .map(
          (e) => AdminRoomTypeImageReorderItem(
            id: e.value.id,
            sortOrder: e.key + 1,
          ),
        )
        .toList();
    final api = context.read<RoomWiseApiClient>();
    try {
      await api.reorderAdminRoomTypeImages(payload);
      await widget.onChanged();
    } catch (e) {
      if (!context.mounted) return;
      final msg = _formatError(e);
      debugPrint('Reorder failed: $msg');
    }
  }

  void _openForm(
    BuildContext context, {
    required int roomTypeId,
    AdminRoomTypeImageDto? existing,
  }) {
    final reservedOrders =
        widget.images
            .where(
              (img) =>
                  img.roomTypeId == roomTypeId &&
                  img.id != existing?.id,
            )
            .map((img) => img.sortOrder)
            .toSet();
    showModalBottomSheet<_RoomTypeImageFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _RoomImageForm(
          roomTypeId: roomTypeId,
          existing: existing,
          reservedOrders: reservedOrders,
        );
      },
    ).then((result) async {
      if (result == null) return;
      final api = context.read<RoomWiseApiClient>();
      final target = existing ?? _imageForSortOrder(
        roomTypeId,
        result.sortOrder,
      );
      if (existing == null && target != null) {
        debugPrint(
          'Room image replace: roomTypeId=$roomTypeId sortOrder=${result.sortOrder} id=${target.id}',
        );
      }
      try {
        if (result.filePath != null) {
          final bytes = await File(result.filePath!).readAsBytes();
          final req = AdminRoomTypeImageUpsertRequest(
            roomTypeId: roomTypeId,
            url: base64Encode(bytes),
            sortOrder: result.sortOrder,
          );
          if (target == null) {
            await api.createAdminRoomTypeImage(req);
          } else {
            await api.updateAdminRoomTypeImage(target.id, req);
          }
        } else if (result.request != null) {
          if (target == null) {
            await api.createAdminRoomTypeImage(result.request!);
          } else {
            await api.updateAdminRoomTypeImage(target.id, result.request!);
          }
        }
        await widget.onChanged();
      } catch (e) {
        if (!context.mounted) return;
        final msg = _formatError(e);
        debugPrint('Save failed: $msg');
      }
    });
  }

  Future<void> _delete(BuildContext context, AdminRoomTypeImageDto img) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete room image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
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
      debugPrint('Delete failed: $msg');
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
  final Set<int> reservedOrders;

  const _RoomImageForm({
    required this.roomTypeId,
    required this.reservedOrders,
    this.existing,
  });

  @override
  State<_RoomImageForm> createState() => _RoomImageFormState();
}

class _RoomImageFormState extends State<_RoomImageForm> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _order = TextEditingController(text: '1');
  XFile? _pickedFile;
  bool _saving = false;

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _url.text = widget.existing!.url;
      _order.text = widget.existing!.sortOrder.toString();
    } else {
      _order.text = _nextAvailableOrder().toString();
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _pickedFile = picked;
        _url.clear();
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Pick image failed: $e');
    }
  }

  void _clearPicked() {
    setState(() => _pickedFile = null);
  }

  int _nextAvailableOrder() {
    var order = 1;
    while (widget.reservedOrders.contains(order)) {
      order += 1;
    }
    return order;
  }

  String? _nonNegativeInt(String? v) {
    final parsed = int.tryParse((v ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 1) return 'Must be ≥ 1';
    if (widget.reservedOrders.contains(parsed)) {
      return 'Order already used';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final title = isEdit ? 'Edit room image' : 'Add room image';
    final subtitle = isEdit
        ? 'Update the image or display order.'
        : 'Attach an image to this room type.';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
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
                              child: CustomPaint(
                                painter: _SoftCirclesPainter(),
                              ),
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
                                  const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: _textPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _saving
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(
                                        0.75,
                                      ),
                                    ),
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Close',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Image'),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _pickedFile == null
                                              ? 'Upload from device'
                                              : 'Selected: ${_pickedFile!.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _textMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.tonalIcon(
                                        onPressed: _saving ? null : _pickImage,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Upload'),
                                      ),
                                      if (_pickedFile != null) ...[
                                        const SizedBox(width: 6),
                                        IconButton(
                                          onPressed: _saving ? null : _clearPicked,
                                          icon: const Icon(Icons.close),
                                          tooltip: 'Remove file',
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (_pickedFile != null) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Image.file(
                                          File(_pickedFile!.path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFFF3F4F6),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              color: _textMuted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  const Divider(height: 1),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _url,
                                    textInputAction: TextInputAction.next,
                                    decoration: _decoration(
                                      label: 'Image URL / Base64',
                                      hint: 'https://… or base64 string',
                                      icon: Icons.link,
                                    ),
                                    validator: (v) {
                                      if (_pickedFile != null) return null;
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) {
                                      if (_pickedFile != null &&
                                          _url.text.trim().isNotEmpty) {
                                        _pickedFile = null;
                                      }
                                      setState(() {});
                                    },
                                  ),
                                  if (_pickedFile == null &&
                                      _url.text.trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _SmartImage(
                                      source: _url.text.trim(),
                                      height: 160,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Ordering'),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _order,
                                    textInputAction: TextInputAction.done,
                                    keyboardType: TextInputType.number,
                                    decoration: _decoration(
                                      label: 'Sort order',
                                      hint: '1',
                                      icon: Icons.format_list_numbered,
                                    ),
                                    validator: _nonNegativeInt,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Lower numbers show first.',
                                    style: TextStyle(
                                      color: _textMuted.withOpacity(0.95),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF05A87A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(_saving ? 'Saving…' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final sortOrder = int.tryParse(_order.text) ?? 1;
    if (_pickedFile != null) {
      Navigator.of(context).pop(
        _RoomTypeImageFormResult.upload(
          filePath: _pickedFile!.path,
          sortOrder: sortOrder,
        ),
      );
      return;
    }
    final req = AdminRoomTypeImageUpsertRequest(
      roomTypeId: widget.roomTypeId,
      url: _url.text.trim(),
      sortOrder: sortOrder,
    );
    Navigator.of(context).pop(_RoomTypeImageFormResult.link(req));
  }
}

class _RoomTypeImageFormResult {
  final AdminRoomTypeImageUpsertRequest? request;
  final String? filePath;
  final int sortOrder;

  const _RoomTypeImageFormResult._({
    required this.sortOrder,
    this.request,
    this.filePath,
  });

  _RoomTypeImageFormResult.link(AdminRoomTypeImageUpsertRequest request)
      : this._(request: request, sortOrder: request.sortOrder);

  const _RoomTypeImageFormResult.upload({
    required String filePath,
    required int sortOrder,
  }) : this._(filePath: filePath, sortOrder: sortOrder);
}

class _HotelImageFormResult {
  final AdminHotelImageUpsertRequest? request;
  final String? filePath;
  final int sortOrder;

  const _HotelImageFormResult._({
    required this.sortOrder,
    this.request,
    this.filePath,
  });

  _HotelImageFormResult.link(AdminHotelImageUpsertRequest request)
      : this._(
          request: request,
          sortOrder: request.sortOrder,
        );

  const _HotelImageFormResult.upload({
    required String filePath,
    required int sortOrder,
  }) : this._(filePath: filePath, sortOrder: sortOrder);
}

class _ImageForm extends StatefulWidget {
  final Set<int> reservedOrders;

  const _ImageForm({required this.reservedOrders});

  @override
  State<_ImageForm> createState() => _ImageFormState();
}

class _ImageFormState extends State<_ImageForm> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _order = TextEditingController(text: '1');
  XFile? _pickedFile;
  bool _saving = false;

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
    );
  }

  String? _nonNegativeInt(String? v) {
    final parsed = int.tryParse((v ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 1) return 'Must be ≥ 1';
    if (widget.reservedOrders.contains(parsed)) {
      return 'Order already used';
    }
    return null;
  }

  int _nextAvailableOrder() {
    var order = 1;
    while (widget.reservedOrders.contains(order)) {
      order += 1;
    }
    return order;
  }

  @override
  void initState() {
    super.initState();
    _order.text = _nextAvailableOrder().toString();
  }

  @override
  void dispose() {
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _pickedFile = picked;
        _url.clear();
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Pick image failed: $e');
    }
  }

  void _clearPicked() {
    setState(() => _pickedFile = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final sortOrder = int.tryParse(_order.text) ?? 1;
    if (_pickedFile != null) {
      Navigator.of(context).pop(
        _HotelImageFormResult.upload(
          filePath: _pickedFile!.path,
          sortOrder: sortOrder,
        ),
      );
      return;
    }
    final req = AdminHotelImageUpsertRequest(
      url: _url.text.trim(),
      sortOrder: sortOrder,
    );
    Navigator.of(context).pop(_HotelImageFormResult.link(req));
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Add hotel image';
    const subtitle = 'Upload a file or paste a URL/base64 image.';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
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
                          colors: [Color(0xFFFFF7ED), Color(0xFFE8ECFF)],
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
                              child: CustomPaint(
                                painter: _SoftCirclesPainter(),
                              ),
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
                                  const Icon(
                                    Icons.photo_library_outlined,
                                    color: _textPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: TextStyle(color: _textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _saving
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(
                                        0.75,
                                      ),
                                    ),
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Close',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Image'),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _pickedFile == null
                                              ? 'Upload from device'
                                              : 'Selected: ${_pickedFile!.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _textMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.tonalIcon(
                                        onPressed: _saving ? null : _pickImage,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Upload'),
                                      ),
                                      if (_pickedFile != null) ...[
                                        const SizedBox(width: 6),
                                        IconButton(
                                          onPressed: _saving ? null : _clearPicked,
                                          icon: const Icon(Icons.close),
                                          tooltip: 'Remove file',
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (_pickedFile != null) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Image.file(
                                          File(_pickedFile!.path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFFF3F4F6),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              color: _textMuted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  const Divider(height: 1),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _url,
                                    textInputAction: TextInputAction.next,
                                    decoration: _decoration(
                                      label: 'Image URL / Base64',
                                      hint: 'https://… or base64 string',
                                      icon: Icons.link,
                                    ),
                                    validator: (v) {
                                      if (_pickedFile != null) return null;
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) {
                                      if (_pickedFile != null &&
                                          _url.text.trim().isNotEmpty) {
                                        _pickedFile = null;
                                      }
                                      setState(() {});
                                    },
                                  ),
                                  if (_pickedFile == null &&
                                      _url.text.trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _SmartImage(
                                      source: _url.text.trim(),
                                      height: 160,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Ordering'),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _order,
                                    textInputAction: TextInputAction.done,
                                    keyboardType: TextInputType.number,
                                    decoration: _decoration(
                                      label: 'Sort order',
                                      hint: '1',
                                      icon: Icons.format_list_numbered,
                                    ),
                                    validator: _nonNegativeInt,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Lower numbers show first.',
                                    style: TextStyle(
                                      color: _textMuted.withOpacity(0.95),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF05A87A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(_saving ? 'Saving…' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _imageLabel(String url) {
  final value = url.trim();
  if (value.isEmpty) return 'Image';
  if (value.startsWith('http')) return value;
  if (value.startsWith('data:image')) return 'Base64 image';
  if (value.length > 60) return 'Base64 image';
  return value;
}

class _SmartImage extends StatelessWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _SmartImage({
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final provider = _resolveImageProvider(source);
    final fallback = Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFF6B7280),
      ),
    );

    if (provider == null) return fallback;

    final image = Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );

    if (width != null && height != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: image,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: image,
      ),
    );
  }
}

ImageProvider? _resolveImageProvider(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http')) {
    return NetworkImage(trimmed);
  }

  final pureBase64 =
      trimmed.contains(',') ? trimmed.split(',').last.trim() : trimmed;
  try {
    final bytes = base64Decode(pureBase64);
    return MemoryImage(bytes);
  } catch (_) {
    return NetworkImage(trimmed);
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return _Card(
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

  const _ErrorCard({super.key, required this.message, required this.onRetry});

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
