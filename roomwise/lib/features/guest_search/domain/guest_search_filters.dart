import 'package:flutter/material.dart';

class GuestSearchFilters {
  final int? cityId;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final List<int> addonIds;
  final List<int> facilityIds;
  final DateTimeRange? dateRange;
  final int? guests;

  const GuestSearchFilters({
    this.cityId,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.addonIds = const [],
    this.facilityIds = const [],
    this.dateRange,
    this.guests,
  });

  GuestSearchFilters copyWith({
    int? cityId,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    List<int>? addonIds,
    List<int>? facilityIds,
    DateTimeRange? dateRange,
    int? guests,
  }) {
    return GuestSearchFilters(
      cityId: cityId ?? this.cityId,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      addonIds: addonIds ?? this.addonIds,
      facilityIds: facilityIds ?? this.facilityIds,
      dateRange: dateRange ?? this.dateRange,
      guests: guests ?? this.guests,
    );
  }
}
