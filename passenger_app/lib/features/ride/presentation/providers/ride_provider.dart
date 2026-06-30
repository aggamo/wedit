import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/driver_location_entity.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_offer_entity.dart';
import '../../domain/repositories/ride_repository.dart';

// ---------------------------------------------------------------------------
// State class
// ---------------------------------------------------------------------------

class RideState {
  final RideEntity? currentRide;
  final bool isLoading;
  final String? error;

  const RideState({
    this.currentRide,
    this.isLoading = false,
    this.error,
  });

  RideState copyWith({
    RideEntity? currentRide,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearRide = false,
  }) {
    return RideState(
      currentRide: clearRide ? null : currentRide ?? this.currentRide,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return getIt<RideRepository>();
});

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------

final nearbyDriversProvider =
    StreamProvider<List<DriverLocationEntity>>((ref) {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getNearbyDrivers(
    lat: 9.0350,
    lng: 38.7516,
  );
});

final rideOffersProvider =
    StreamProvider.family<List<RideOfferEntity>, String>((ref, rideId) {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getRideOffers(rideId);
});

final currentRideProvider =
    StreamProvider.family<RideEntity, String>((ref, rideId) {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getRideStatus(rideId);
});

// ---------------------------------------------------------------------------
// Future providers
// ---------------------------------------------------------------------------

final rideHistoryProvider = FutureProvider<List<RideEntity>>((ref) async {
  final repo = ref.watch(rideRepositoryProvider);
  final result = await repo.getRideHistory();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (rides) => rides,
  );
});

final estimatedPriceProvider =
    FutureProvider.family<Map<String, double>, double>((ref, distanceKm) async {
  final repo = ref.watch(rideRepositoryProvider);
  final vehicleTypes = ['sedan', 'suv', 'vip', 'minibus'];
  final prices = <String, double>{};

  for (final vt in vehicleTypes) {
    final result = await repo.getEstimatedPrice(
      distanceKm: distanceKm,
      vehicleType: vt,
    );
    result.fold(
      (failure) => prices[vt] = _localEstimate(distanceKm, vt),
      (price) => prices[vt] = price,
    );
  }

  return prices;
});

double _localEstimate(double distanceKm, String vehicleType) {
  switch (vehicleType) {
    case 'suv':
      return 75.0 + distanceKm * 18.0;
    case 'vip':
      return 120.0 + distanceKm * 25.0;
    case 'minibus':
      return 40.0 + distanceKm * 10.0;
    default:
      return 50.0 + distanceKm * 12.0;
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class RideNotifier extends StateNotifier<RideState> {
  final RideRepository _repository;

  RideNotifier(this._repository) : super(const RideState());

  Future<RideEntity?> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double destinationLat,
    required double destinationLng,
    required String destinationAddress,
    required String vehicleType,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final params = RequestRideParams(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      pickupAddress: pickupAddress,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      destinationAddress: destinationAddress,
      vehicleType: vehicleType,
    );

    final result = await _repository.requestRide(params);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return null;
      },
      (ride) {
        state = state.copyWith(isLoading: false, currentRide: ride);
        return ride;
      },
    );
  }

  Future<RideEntity?> acceptOffer(String offerId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.acceptOffer(offerId);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return null;
      },
      (ride) {
        state = state.copyWith(isLoading: false, currentRide: ride);
        return ride;
      },
    );
  }

  /// Accept the first driver who offered at system price.
  /// Returns the ride if a matching offer exists, or null if still waiting.
  Future<RideEntity?> acceptSystemPrice(
      String rideId, List<dynamic> currentOffers) async {
    final systemOffers = currentOffers
        .where((o) => o.isSystemPrice == true && o.status == 'pending')
        .toList();

    if (systemOffers.isNotEmpty) {
      return acceptOffer(systemOffers.first.id as String);
    }

    // No system-price offer yet — caller should show waiting UI
    return null;
  }

  Future<bool> cancelRide(String rideId, String reason) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.cancelRide(rideId, reason);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, clearRide: true);
        return true;
      },
    );
  }

  Future<bool> submitRating({
    required String rideId,
    required int score,
    String? comment,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.rateRide(
      rideId: rideId,
      score: score,
      comment: comment,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false);
        return true;
      },
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearRide() {
    state = state.copyWith(clearRide: true);
  }
}

final rideStateProvider =
    StateNotifierProvider<RideNotifier, RideState>((ref) {
  final repository = ref.watch(rideRepositoryProvider);
  return RideNotifier(repository);
});
