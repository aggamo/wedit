import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/admin_provider.dart';

class CallCenterState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? result;

  const CallCenterState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  CallCenterState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? result,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return CallCenterState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

class CallCenterNotifier extends StateNotifier<CallCenterState> {
  final SupabaseClient _supabase;

  CallCenterNotifier(this._supabase) : super(const CallCenterState());

  Future<void> createRide({
    required String passengerPhone,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required String vehicleType,
    String notes = '',
    double? dropoffLat,
    double? dropoffLng,
    String dropoffAddress = '',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearResult: true);

    try {
      final response = await _supabase.functions.invoke(
        'create-call-center-ride',
        body: {
          'passenger_phone': passengerPhone,
          'pickup_lat':      pickupLat,
          'pickup_lng':      pickupLng,
          'pickup_address':  pickupAddress,
          'vehicle_type':    vehicleType,
          if (notes.isNotEmpty) 'notes': notes,
          if (dropoffLat != null) 'dropoff_lat': dropoffLat,
          if (dropoffLng != null) 'dropoff_lng': dropoffLng,
          if (dropoffAddress.isNotEmpty) 'dropoff_address': dropoffAddress,
        },
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      if (data['success'] == true) {
        state = CallCenterState(result: data);
      } else {
        state = CallCenterState(
          error: data['error'] as String? ?? 'فشل إرسال الطلب',
        );
      }
    } catch (e) {
      state = CallCenterState(error: e.toString());
    }
  }

  void reset() => state = const CallCenterState();
}

final callCenterProvider =
    StateNotifierProvider<CallCenterNotifier, CallCenterState>((ref) {
  return CallCenterNotifier(ref.watch(supabaseClientProvider));
});

/// Stream of nearby available drivers — refreshed on demand.
final nearbyDriversProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ({double lat, double lng, String vehicleType})>(
  (ref, args) async {
    final supabase = ref.watch(supabaseClientProvider);
    final response = await supabase.rpc(
      'find_nearby_drivers',
      params: {
        'lat': args.lat,
        'lng': args.lng,
        'radius_km': 5,
        'vehicle_type': args.vehicleType,
        'dest_lat': args.lat,
        'dest_lng': args.lng,
      },
    );
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  },
);
