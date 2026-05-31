import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/ride_remote_datasource.dart';
import '../../data/repositories/ride_repository_impl.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_request_entity.dart';
import '../../domain/repositories/ride_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final rideDatasourceProvider = Provider<RideRemoteDatasource>((ref) {
  return RideRemoteDatasourceImpl(ref.watch(supabaseClientProvider));
});

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepositoryImpl(
    ref.watch(rideDatasourceProvider),
    ref.watch(supabaseClientProvider),
  );
});

// ---------------------------------------------------------------------------
// Simple state providers
// ---------------------------------------------------------------------------

/// Whether the driver is currently online (accepting rides)
final onlineStatusProvider = StateProvider<bool>((ref) => false);

/// Whether the driver has surge mode enabled
final surgeModeProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------

/// Incoming ride requests stream
final incomingRequestsProvider =
    StreamProvider<List<RideRequestEntity>>((ref) {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.streamIncomingRequests();
});

/// Current active ride for this driver
final currentRideProvider = StreamProvider<RideEntity?>((ref) {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.streamCurrentRide();
});

/// Geolocator position stream for continuous tracking
final locationStreamProvider = StreamProvider<Position>((ref) async* {
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    await Geolocator.requestPermission();
  }

  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  yield* Geolocator.getPositionStream(locationSettings: locationSettings);
});

// ---------------------------------------------------------------------------
// RideState
// ---------------------------------------------------------------------------

class RideState {
  final bool isLoading;
  final String? error;
  final String? activeRideId;

  const RideState({
    this.isLoading = false,
    this.error,
    this.activeRideId,
  });

  RideState copyWith({
    bool? isLoading,
    String? error,
    String? activeRideId,
    bool clearError = false,
  }) {
    return RideState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeRideId: activeRideId ?? this.activeRideId,
    );
  }
}

// ---------------------------------------------------------------------------
// RideNotifier
// ---------------------------------------------------------------------------

class RideNotifier extends StateNotifier<RideState> {
  final RideRepository _repository;
  final SupabaseClient _supabase;

  RideNotifier(this._repository, this._supabase)
      : super(const RideState());

  String get _driverId => _supabase.auth.currentUser?.id ?? '';

  /// Toggle driver online status, updating Supabase driver_locations
  Future<void> setOnlineStatus(bool isOnline) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.setOnlineStatus(isOnline);

      // Also upsert driver_locations table
      await _supabase.from('driver_locations').upsert({
        'driver_id': _driverId,
        'is_online': isOnline,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'driver_id');
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Update driver location in Supabase
  Future<void> updateLocation(
      double lat, double lng, double heading) async {
    try {
      await _repository.updateLocation(lat, lng, heading);

      // Also update driver_locations table
      await _supabase.from('driver_locations').upsert({
        'driver_id': _driverId,
        'lat': lat,
        'lng': lng,
        'heading': heading,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'driver_id');
    } catch (_) {
      // Non-critical, silently ignore
    }
  }

  /// Submit a price offer for a ride
  Future<void> submitOffer(String rideId, double price,
      {bool isSystemPrice = false, bool isSurgeOffer = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.submitOffer(rideId, price,
        isSystemPrice: isSystemPrice, isSurgeOffer: isSurgeOffer);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (_) =>
          state = state.copyWith(isLoading: false, activeRideId: rideId),
    );
  }

  /// Toggle driver surge mode
  Future<void> toggleSurge(bool enabled) async {
    await _repository.toggleSurge(enabled);
  }

  /// Decline a ride request (just dismiss locally, log to Supabase)
  Future<void> declineRequest(String rideId) async {
    await _repository.declineRequest(rideId);
  }

  /// Mark driver has arrived at pickup point
  Future<void> markArrived(String rideId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.markArrived(rideId);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (_) => state = state.copyWith(isLoading: false),
    );
  }

  /// Start the ride (passenger on board)
  Future<void> startRide(String rideId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.startRide(rideId);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (_) => state = state.copyWith(isLoading: false),
    );
  }

  /// Complete the ride
  Future<void> completeRide(String rideId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.completeRide(rideId);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (_) => state =
          state.copyWith(isLoading: false, activeRideId: null),
    );
  }

  Future<RideEntity?> startStreetHailRide({
    required String passengerPhone,
    required String vehicleType,
    required double startLat,
    required double startLng,
    String? destination,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.startStreetHailRide(
      passengerPhone: passengerPhone,
      vehicleType: vehicleType,
      startLat: startLat,
      startLng: startLng,
      destination: destination,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return null;
      },
      (ride) {
        state = state.copyWith(isLoading: false, activeRideId: ride.id);
        return ride;
      },
    );
  }

  Future<double?> endStreetHailRide({
    required String rideId,
    required double endLat,
    required double endLng,
    required double distanceKm,
    required double durationMinutes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.endStreetHailRide(
      rideId: rideId,
      endLat: endLat,
      endLng: endLng,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return null;
      },
      (fare) {
        state = state.copyWith(isLoading: false, activeRideId: null);
        return fare;
      },
    );
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final rideNotifierProvider =
    StateNotifierProvider<RideNotifier, RideState>((ref) {
  return RideNotifier(
    ref.watch(rideRepositoryProvider),
    ref.watch(supabaseClientProvider),
  );
});
