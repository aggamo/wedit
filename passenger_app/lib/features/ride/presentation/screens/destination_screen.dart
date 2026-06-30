import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';
import '../widgets/vehicle_type_card.dart';

class _PopularPlace {
  final String name;
  final String subtitle;
  final double lat;
  final double lng;
  final IconData icon;

  const _PopularPlace({
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lng,
    required this.icon,
  });
}

const _popularPlaces = [
  _PopularPlace(
    name: 'مطار بولي الدولي',
    subtitle: 'بولي، أديس أبابا',
    lat: 8.9779,
    lng: 38.7993,
    icon: Icons.flight,
  ),
  _PopularPlace(
    name: 'ميدان المكسيك',
    subtitle: 'كرالو، أديس أبابا',
    lat: 9.0168,
    lng: 38.7524,
    icon: Icons.location_city,
  ),
  _PopularPlace(
    name: 'ميركاتو',
    subtitle: 'أديس كتيما، أديس أبابا',
    lat: 9.0354,
    lng: 38.7357,
    icon: Icons.store,
  ),
  _PopularPlace(
    name: 'بياتزا',
    subtitle: 'تكلي هيمانوت، أديس أبابا',
    lat: 9.0393,
    lng: 38.7484,
    icon: Icons.location_on,
  ),
  _PopularPlace(
    name: 'مسجد الأنوار',
    subtitle: 'أديس أبابا',
    lat: 9.0252,
    lng: 38.7469,
    icon: Icons.mosque,
  ),
  _PopularPlace(
    name: 'جامعة أديس أبابا',
    subtitle: 'الحرم الجامعي الرئيسي',
    lat: 9.0465,
    lng: 38.7612,
    icon: Icons.school,
  ),
  _PopularPlace(
    name: 'مستشفى بلاك ليون',
    subtitle: 'غولي، أديس أبابا',
    lat: 9.0427,
    lng: 38.7631,
    icon: Icons.local_hospital,
  ),
];

// ---------------------------------------------------------------------------
// Price breakdown model
// ---------------------------------------------------------------------------

class _PriceBreakdown {
  final double base;
  final double distanceFare;
  final double timeFare;
  final double surgeFee;
  final double total;
  final double surgeMultiplier;

  const _PriceBreakdown({
    required this.base,
    required this.distanceFare,
    required this.timeFare,
    required this.surgeFee,
    required this.total,
    required this.surgeMultiplier,
  });

  bool get hasSurge => surgeMultiplier > 1.0;
}

_PriceBreakdown _calcBreakdown(
    String vt, double distKm, double durMin, double surgeMultiplier) {
  double base, ppk, ppm;
  switch (vt) {
    case 'suv':
      base = 35; ppk = 12; ppm = 2.0;
      break;
    case 'vip':
      base = 60; ppk = 20; ppm = 3.5;
      break;
    case 'minibus':
      base = 20; ppk = 6;  ppm = 1.0;
      break;
    default: // sedan
      base = 25; ppk = 8;  ppm = 1.5;
  }
  final dist   = ppk * distKm;
  final time   = ppm * durMin;
  final sub    = base + dist + time;
  final surge  = sub * (surgeMultiplier - 1);
  return _PriceBreakdown(
    base: base,
    distanceFare: dist,
    timeFare: time,
    surgeFee: surge,
    total: sub + surge,
    surgeMultiplier: surgeMultiplier,
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class DestinationScreen extends ConsumerStatefulWidget {
  const DestinationScreen({super.key});

  @override
  ConsumerState<DestinationScreen> createState() =>
      _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  final _searchController = TextEditingController();
  List<_PopularPlace> _filteredPlaces = _popularPlaces;
  String _selectedVehicleType = 'sedan';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPlaces = _popularPlaces
          .where((p) =>
              p.name.contains(query) ||
              p.subtitle.toLowerCase().contains(query))
          .toList();
    });
  }

  void _onPlaceSelected(_PopularPlace place) {
    _showEstimateSheet(place);
  }

  void _showEstimateSheet(_PopularPlace destination) {
    final rnd = Random();
    final distanceKm = 2.0 + rnd.nextDouble() * 8.0;
    // Estimate ~3 min/km in city traffic
    final durationMin = distanceKm * 3.0;
    // TODO: replace with real surge call once Supabase is connected
    const surgeMultiplier = 1.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EstimateSheet(
        destination: destination,
        distanceKm: distanceKm,
        durationMin: durationMin,
        surgeMultiplier: surgeMultiplier,
        selectedVehicleType: _selectedVehicleType,
        onVehicleTypeChanged: (vt) =>
            setState(() => _selectedVehicleType = vt),
        onRequestRide: () =>
            _requestRide(destination, distanceKm, surgeMultiplier),
      ),
    );
  }

  Future<void> _requestRide(
      _PopularPlace destination, double distanceKm, double surgeMultiplier) async {
    Navigator.pop(context); // close bottom sheet

    final breakdown = _calcBreakdown(
        _selectedVehicleType, distanceKm, distanceKm * 3.0, surgeMultiplier);

    // Show surge warning if needed
    if (breakdown.hasSurge && mounted) {
      final proceed = await _showSurgeWarning(breakdown.surgeMultiplier);
      if (proceed != true) return;
    }

    final rideNotifier = ref.read(rideStateProvider.notifier);
    final ride = await rideNotifier.requestRide(
      pickupLat: AppConstants.addisAbabaLat,
      pickupLng: AppConstants.addisAbabaLng,
      pickupAddress: 'موقعك الحالي',
      destinationLat: destination.lat,
      destinationLng: destination.lng,
      destinationAddress: destination.name,
      vehicleType: _selectedVehicleType,
    );

    if (ride != null && mounted) {
      context.go('/ride/${ride.id}/offers',
          extra: {'systemPrice': breakdown.total});
    } else {
      final error = ref.read(rideStateProvider).error;
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool?> _showSurgeWarning(double multiplier) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.bolt, color: Colors.orange, size: 36),
        title: const Text('أسعار ذروة مفعّلة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'السعر الحالي أعلى بـ ${((multiplier - 1) * 100).toStringAsFixed(0)}٪ بسبب ارتفاع الطلب.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'يمكنك الانتظار حتى تنخفض الأسعار.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انتظر'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إلى أين؟'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن الوجهة...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(
                              () => _filteredPlaces = _popularPlaces);
                        },
                      )
                    : null,
              ),
            ),
          ),

          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Text(
                    'أماكن شائعة في أديس أبابا',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                ..._filteredPlaces.map(
                  (place) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withOpacity(0.1),
                      child: Icon(place.icon,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text(place.name,
                        style: theme.textTheme.bodyMedium),
                    subtitle: Text(place.subtitle,
                        style: theme.textTheme.bodySmall),
                    onTap: () => _onPlaceSelected(place),
                  ),
                ),

                const Divider(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Text(
                    'الوجهات الأخيرة',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history,
                            size: 48, color: AppColors.textDisabled),
                        SizedBox(height: 8),
                        Text(
                          'لا توجد وجهات سابقة',
                          style:
                              TextStyle(color: AppColors.textHint),
                        ),
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// Estimate sheet (bottom sheet)
// ---------------------------------------------------------------------------

class _EstimateSheet extends ConsumerStatefulWidget {
  final _PopularPlace destination;
  final double distanceKm;
  final double durationMin;
  final double surgeMultiplier;
  final String selectedVehicleType;
  final ValueChanged<String> onVehicleTypeChanged;
  final VoidCallback onRequestRide;

  const _EstimateSheet({
    required this.destination,
    required this.distanceKm,
    required this.durationMin,
    required this.surgeMultiplier,
    required this.selectedVehicleType,
    required this.onVehicleTypeChanged,
    required this.onRequestRide,
  });

  @override
  ConsumerState<_EstimateSheet> createState() => _EstimateSheetState();
}

class _EstimateSheetState extends ConsumerState<_EstimateSheet> {
  late String _currentVehicleType;

  @override
  void initState() {
    super.initState();
    _currentVehicleType = widget.selectedVehicleType;
  }

  void _selectVehicle(String vt) {
    setState(() => _currentVehicleType = vt);
    widget.onVehicleTypeChanged(vt);
  }

  String _vehicleName(String vt) {
    switch (vt) {
      case 'suv':     return 'دفع رباعي';
      case 'vip':     return 'VIP';
      case 'minibus': return 'ميني باص';
      default:        return 'سيدان';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rideState = ref.watch(rideStateProvider);
    final breakdown = _calcBreakdown(
        _currentVehicleType, widget.distanceKm,
        widget.durationMin, widget.surgeMultiplier);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Destination & distance
            Text(widget.destination.name,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'المسافة: ~${widget.distanceKm.toStringAsFixed(1)} كم  •  الوقت: ~${widget.durationMin.toStringAsFixed(0)} دقيقة',
              style: theme.textTheme.bodySmall,
            ),

            // Surge banner
            if (breakdown.hasSurge) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'أسعار ذروة: ×${widget.surgeMultiplier.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Vehicle type cards
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: AppConstants.vehicleTypes.map((vt) {
                  final bd = _calcBreakdown(vt, widget.distanceKm,
                      widget.durationMin, widget.surgeMultiplier);
                  return VehicleTypeCard(
                    vehicleType: vt,
                    isSelected: _currentVehicleType == vt,
                    estimatedPrice: bd.total,
                    onTap: () => _selectVehicle(vt),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Price breakdown card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفصيل السعر — ${_vehicleName(_currentVehicleType)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _PriceRow(
                      label: 'سعر الانطلاق',
                      amount: breakdown.base),
                  _PriceRow(
                      label:
                          'المسافة (${widget.distanceKm.toStringAsFixed(1)} كم)',
                      amount: breakdown.distanceFare),
                  _PriceRow(
                      label:
                          'الوقت (~${widget.durationMin.toStringAsFixed(0)} د)',
                      amount: breakdown.timeFare),
                  if (breakdown.hasSurge)
                    _PriceRow(
                        label: 'رسوم الذروة',
                        amount: breakdown.surgeFee,
                        highlight: true),
                  const Divider(height: 14),
                  _PriceRow(
                    label: 'المجموع المقدر',
                    amount: breakdown.total,
                    isBold: true,
                  ),
                ],
              ),
            ),

            // Comparison row
            const SizedBox(height: 8),
            _ComparisonRow(
              currentVehicle: _currentVehicleType,
              distanceKm: widget.distanceKm,
              durationMin: widget.durationMin,
              surgeMultiplier: widget.surgeMultiplier,
            ),

            const SizedBox(height: 16),

            // Request button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: rideState.isLoading ? null : widget.onRequestRide,
                child: rideState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'اطلب رحلة  •  ~${breakdown.total.toStringAsFixed(0)} ب',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final bool highlight;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isBold = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isBold ? 14 : 13,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
      color: highlight ? Colors.orange.shade700 : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${amount.toStringAsFixed(0)} ب', style: style),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String currentVehicle;
  final double distanceKm;
  final double durationMin;
  final double surgeMultiplier;

  const _ComparisonRow({
    required this.currentVehicle,
    required this.distanceKm,
    required this.durationMin,
    required this.surgeMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    final others = AppConstants.vehicleTypes
        .where((vt) => vt != currentVehicle)
        .toList();

    return Wrap(
      spacing: 8,
      children: others.map((vt) {
        final bd = _calcBreakdown(vt, distanceKm, durationMin, surgeMultiplier);
        return Chip(
          visualDensity: VisualDensity.compact,
          label: Text('${_vtName(vt)}: ~${bd.total.toStringAsFixed(0)} ب',
              style: const TextStyle(fontSize: 11)),
          backgroundColor: Colors.grey.shade100,
        );
      }).toList(),
    );
  }

  String _vtName(String vt) {
    switch (vt) {
      case 'suv':     return 'SUV';
      case 'vip':     return 'VIP';
      case 'minibus': return 'ميني باص';
      default:        return 'سيدان';
    }
  }
}
