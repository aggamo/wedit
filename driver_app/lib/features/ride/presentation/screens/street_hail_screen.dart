import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class StreetHailScreen extends ConsumerStatefulWidget {
  final String rideId;
  final String passengerPhone;
  final String vehicleType;
  final double startLat;
  final double startLng;

  const StreetHailScreen({
    super.key,
    required this.rideId,
    required this.passengerPhone,
    required this.vehicleType,
    required this.startLat,
    required this.startLng,
  });

  @override
  ConsumerState<StreetHailScreen> createState() => _StreetHailScreenState();
}

class _StreetHailScreenState extends ConsumerState<StreetHailScreen> {
  // ── Timers & location ────────────────────────────────────────────────────────
  Timer? _uiTimer;
  StreamSubscription<Position>? _locationSub;
  GoogleMapController? _mapController;

  // ── Ride state ───────────────────────────────────────────────────────────────
  final DateTime _startTime = DateTime.now();
  double _totalDistanceKm = 0;
  Position? _lastPosition;
  Position? _currentPosition;

  // ── Pricing config ───────────────────────────────────────────────────────────
  late final double _baseFare;
  late final double _pricePerKm;
  late final double _pricePerMin;

  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _setPricingConfig();
    _startLocationTracking();
    // Refresh UI every second (for timer display)
    _uiTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _setPricingConfig() {
    switch (widget.vehicleType) {
      case 'suv':
        _baseFare = 35; _pricePerKm = 12; _pricePerMin = 2.0;
      case 'vip':
        _baseFare = 60; _pricePerKm = 20; _pricePerMin = 3.5;
      case 'minibus':
        _baseFare = 20; _pricePerKm = 6;  _pricePerMin = 1.0;
      default: // sedan
        _baseFare = 25; _pricePerKm = 8;  _pricePerMin = 1.5;
    }
  }

  Future<void> _startLocationTracking() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // update every 5 m of movement
    );

    _locationSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
      if (!mounted) return;
      setState(() {
        if (_lastPosition != null) {
          _totalDistanceKm += _haversineKm(
            _lastPosition!.latitude, _lastPosition!.longitude,
            pos.latitude, pos.longitude,
          );
        }
        _lastPosition = pos;
        _currentPosition = pos;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
    });
  }

  // ── Haversine distance ───────────────────────────────────────────────────────
  double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  // ── Derived values ───────────────────────────────────────────────────────────
  Duration get _elapsed => DateTime.now().difference(_startTime);

  double get _liveFare {
    final mins = _elapsed.inSeconds / 60.0;
    return _baseFare + _pricePerKm * _totalDistanceKm + _pricePerMin * mins;
  }

  String get _formattedTime {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    final s = _elapsed.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _vehicleName {
    switch (widget.vehicleType) {
      case 'suv':     return 'دفع رباعي';
      case 'vip':     return 'VIP';
      case 'minibus': return 'ميني باص';
      default:        return 'سيدان';
    }
  }

  // ── End ride flow ─────────────────────────────────────────────────────────────
  Future<void> _confirmEndRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء الرحلة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الأجرة المحسوبة: ${_liveFare.toStringAsFixed(2)} ب',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'المسافة: ${_totalDistanceKm.toStringAsFixed(2)} كم\n'
              'المدة: $_formattedTime',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            const Text('هل تريد إنهاء الرحلة وإرسال SMS للراكب؟'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            child: const Text('إنهاء الرحلة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _endRide();
  }

  Future<void> _endRide() async {
    setState(() => _isEnding = true);

    final endPos = _currentPosition;
    final endLat = endPos?.latitude ?? widget.startLat;
    final endLng = endPos?.longitude ?? widget.startLng;
    final durationMin = _elapsed.inSeconds / 60.0;

    final fare = await ref.read(rideNotifierProvider.notifier).endStreetHailRide(
      rideId: widget.rideId,
      endLat: endLat,
      endLng: endLng,
      distanceKm: _totalDistanceKm,
      durationMinutes: durationMin,
    );

    if (!mounted) return;
    setState(() => _isEnding = false);

    if (fare == null) {
      final error = ref.read(rideNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error ?? 'خطأ في إنهاء الرحلة'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Show summary
    await _showSummary(fare);
  }

  Future<void> _showSummary(double fare) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 14),
            const Text('الرحلة اكتملت!',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('تم إرسال SMS للراكب',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            _SummaryRow(
                label: 'الأجرة الإجمالية',
                value: '${fare.toStringAsFixed(2)} ب',
                isBold: true),
            _SummaryRow(
                label: 'المسافة',
                value: '${_totalDistanceKm.toStringAsFixed(2)} كم'),
            _SummaryRow(label: 'المدة', value: _formattedTime),
            _SummaryRow(
                label: 'نوع السيارة', value: _vehicleName),
            _SummaryRow(
                label: 'هاتف الراكب', value: widget.passengerPhone),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('العودة للرئيسية',
                    style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rideState = ref.watch(rideNotifierProvider);

    final startLatLng = LatLng(widget.startLat, widget.startLng);
    final currentLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : startLatLng;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: currentLatLng, zoom: 16),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('start'),
                position: startLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(title: 'نقطة الانطلاق'),
              ),
            },
          ),

          // ── Top panel: "Street Hail" badge + phone ───────────────────────────
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hail,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('رحلة شارع',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            Text(widget.passengerPhone,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom fare panel ────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.fromLTRB(24, 20, 24, 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live fare + time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Fare
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الأجرة الحية',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text(
                            '${_liveFare.toStringAsFixed(1)} ب',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      // Timer
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('المدة',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text(
                            _formattedTime,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFeatures: [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Distance stat
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route,
                                size: 16,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${_totalDistanceKm.toStringAsFixed(2)} كم',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.directions_car,
                                size: 16,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(_vehicleName,
                                style: theme.textTheme.labelMedium),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // End ride button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isEnding || rideState.isLoading)
                          ? null
                          : _confirmEndRide,
                      icon: _isEnding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.stop_circle_outlined,
                              size: 20),
                      label: Text(
                        _isEnding ? 'جاري الإنهاء...' : 'إنهاء الرحلة',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow(
      {required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
