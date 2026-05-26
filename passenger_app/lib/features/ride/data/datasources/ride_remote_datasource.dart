import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../domain/entities/driver_location_entity.dart';
import '../../domain/entities/ride_offer_entity.dart';
import '../models/ride_model.dart';

abstract class RideRemoteDatasource {
  Future<RideModel> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required String vehicleType,
  });

  Stream<List<RideOfferEntity>> streamRideOffers(String rideId);

  Future<RideModel> acceptOffer(String offerId);

  Future<void> cancelRide(String rideId, String reason);

  Stream<RideModel> streamRideStatus(String rideId);

  Future<void> submitRating({
    required String rideId,
    required int score,
    String? comment,
    List<String>? categories,
  });

  Stream<List<DriverLocationEntity>> streamNearbyDrivers();

  Future<List<RideModel>> getRideHistory(String passengerId);

  Future<double> getEstimatedPrice({
    required double distanceKm,
    required String vehicleType,
  });

  Future<RideModel> getRideById(String rideId);
}

class RideRemoteDatasourceImpl implements RideRemoteDatasource {
  final SupabaseService _supabase;

  const RideRemoteDatasourceImpl(this._supabase);

  @override
  Future<RideModel> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required String vehicleType,
  }) async {
    try {
      final userId = _supabase.currentUserId;
      if (userId == null) {
        throw const ServerException(message: 'User not authenticated');
      }

      final data = await _supabase.ridesTable
          .insert({
            'passenger_id': userId,
            'pickup_lat': pickupLat,
            'pickup_lng': pickupLng,
            'pickup_address': pickupAddress,
            'destination_lat': dropoffLat,
            'destination_lng': dropoffLng,
            'destination_address': dropoffAddress,
            'vehicle_type': vehicleType,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return RideModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Stream<List<RideOfferEntity>> streamRideOffers(String rideId) {
    final controller = _SupabaseStreamController<List<RideOfferEntity>>();

    final channel = _supabase.client
        .channel('ride_offers_$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (_) async {
            final offers = await _fetchPendingOffers(rideId);
            controller.add(offers);
          },
        )
        .subscribe();

    // Initial fetch
    _fetchPendingOffers(rideId).then(controller.add).catchError(controller.addError);

    return controller.stream.handleError((_) => <RideOfferEntity>[]).asBroadcastStream()
      ..listen(null, onDone: () {
        _supabase.client.removeChannel(channel);
      });
  }

  Future<List<RideOfferEntity>> _fetchPendingOffers(String rideId) async {
    try {
      final data = await _supabase.client
          .from('ride_offers')
          .select('''
            *,
            driver:profiles!driver_id(
              id, full_name, avatar_url, rating, total_rides
            ),
            vehicle:driver_vehicles!driver_id(
              model, plate, color, vehicle_type
            )
          ''')
          .eq('ride_id', rideId)
          .eq('status', 'pending')
          .order('offered_price', ascending: true);

      return (data as List)
          .map((json) => _mapToOfferEntity(json))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    }
  }

  RideOfferEntity _mapToOfferEntity(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>? ?? {};
    final vehicle = json['vehicle'] as Map<String, dynamic>? ?? {};

    return RideOfferEntity(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      driverId: json['driver_id'] as String,
      driverName: driver['full_name'] as String? ?? 'السائق',
      driverRating: (driver['rating'] as num?)?.toDouble() ?? 4.5,
      driverTotalRides: (driver['total_rides'] as num?)?.toInt() ?? 0,
      driverAvatarUrl: driver['avatar_url'] as String?,
      vehicleModel: vehicle['model'] as String? ?? 'سيارة',
      vehiclePlate: vehicle['plate'] as String? ?? '---',
      vehicleColor: vehicle['color'] as String? ?? 'أبيض',
      vehicleType: vehicle['vehicle_type'] as String? ?? 'sedan',
      offeredPrice: (json['offered_price'] as num).toDouble(),
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 5,
      distanceToPickupKm:
          (json['distance_to_pickup_km'] as num?)?.toDouble() ?? 1.0,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now().add(const Duration(seconds: 45)),
      isSystemPrice: (json['is_system_price'] as bool?) ?? false,
      status: json['status'] as String? ?? 'pending',
    );
  }

  @override
  Future<RideModel> acceptOffer(String offerId) async {
    try {
      // Get offer details
      final offer = await _supabase.client
          .from('ride_offers')
          .select()
          .eq('id', offerId)
          .single();

      final rideId = offer['ride_id'] as String;
      final driverId = offer['driver_id'] as String;
      final price = offer['offered_price'] as num;

      // Update offer status
      await _supabase.rideOffersTable
          .update({'status': 'accepted'})
          .eq('id', offerId);

      // Update ride with accepted offer
      final rideData = await _supabase.ridesTable
          .update({
            'status': 'accepted',
            'accepted_offer_id': offerId,
            'driver_id': driverId,
            'offered_price': price,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .select()
          .single();

      return RideModel.fromJson(rideData);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> cancelRide(String rideId, String reason) async {
    try {
      await _supabase.ridesTable
          .update({
            'status': 'cancelled',
            'cancel_reason': reason,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Stream<RideModel> streamRideStatus(String rideId) {
    final controller = _SupabaseStreamController<RideModel>();

    final channel = _supabase.client
        .channel('ride_status_$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              controller.add(RideModel.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();

    // Initial fetch
    _fetchRideById(rideId).then(controller.add).catchError(controller.addError);

    return controller.stream.asBroadcastStream()
      ..listen(null, onDone: () {
        _supabase.client.removeChannel(channel);
      });
  }

  Future<RideModel> _fetchRideById(String rideId) async {
    final data = await _supabase.ridesTable
        .select()
        .eq('id', rideId)
        .single();
    return RideModel.fromJson(data);
  }

  @override
  Future<void> submitRating({
    required String rideId,
    required int score,
    String? comment,
    List<String>? categories,
  }) async {
    try {
      final userId = _supabase.currentUserId;
      if (userId == null) {
        throw const ServerException(message: 'User not authenticated');
      }

      // Get ride to find driver
      final ride = await _supabase.ridesTable
          .select()
          .eq('id', rideId)
          .single();

      await _supabase.client.from('ratings').insert({
        'ride_id': rideId,
        'passenger_id': userId,
        'driver_id': ride['driver_id'],
        'score': score,
        'comment': comment,
        'categories': categories,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Also update the ride's passenger rating
      await _supabase.ridesTable
          .update({
            'passenger_rating': score,
            'passenger_comment': comment,
          })
          .eq('id', rideId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Stream<List<DriverLocationEntity>> streamNearbyDrivers() {
    final controller = _SupabaseStreamController<List<DriverLocationEntity>>();

    final channel = _supabase.client
        .channel('nearby_drivers')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_locations',
          callback: (_) async {
            final drivers = await _fetchNearbyDrivers();
            controller.add(drivers);
          },
        )
        .subscribe();

    // Initial fetch
    _fetchNearbyDrivers().then(controller.add).catchError(controller.addError);

    return controller.stream.handleError((_) => <DriverLocationEntity>[]).asBroadcastStream()
      ..listen(null, onDone: () {
        _supabase.client.removeChannel(channel);
      });
  }

  Future<List<DriverLocationEntity>> _fetchNearbyDrivers() async {
    try {
      final data = await _supabase.driverLocationsTable
          .select()
          .eq('is_online', true)
          .limit(50);

      return (data as List)
          .map((json) => DriverLocationEntity(
                driverId: json['driver_id'] as String,
                lat: (json['lat'] as num).toDouble(),
                lng: (json['lng'] as num).toDouble(),
                heading: (json['heading'] as num?)?.toDouble(),
                isOnline: json['is_online'] as bool? ?? true,
                vehicleType: json['vehicle_type'] as String?,
                updatedAt: json['updated_at'] != null
                    ? DateTime.tryParse(json['updated_at'] as String)
                    : null,
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    }
  }

  @override
  Future<List<RideModel>> getRideHistory(String passengerId) async {
    try {
      final data = await _supabase.ridesTable
          .select()
          .eq('passenger_id', passengerId)
          .order('created_at', ascending: false)
          .limit(20);

      return (data as List).map((json) => RideModel.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<double> getEstimatedPrice({
    required double distanceKm,
    required String vehicleType,
  }) async {
    try {
      final result = await _supabase.client.rpc(
        'calculate_estimated_price',
        params: {
          'p_distance_km': distanceKm,
          'p_vehicle_type': vehicleType,
        },
      );
      return (result as num).toDouble();
    } on PostgrestException catch (e) {
      // Fallback to local calculation if RPC doesn't exist
      return _localPriceEstimate(distanceKm, vehicleType);
    } catch (e) {
      return _localPriceEstimate(distanceKm, vehicleType);
    }
  }

  double _localPriceEstimate(double distanceKm, String vehicleType) {
    switch (vehicleType) {
      case 'suv':
        return 75.0 + distanceKm * 18.0;
      case 'vip':
        return 120.0 + distanceKm * 25.0;
      case 'minibus':
        return 40.0 + distanceKm * 10.0;
      default: // sedan
        return 50.0 + distanceKm * 12.0;
    }
  }

  @override
  Future<RideModel> getRideById(String rideId) async {
    try {
      return _fetchRideById(rideId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}

/// Simple stream controller helper for Supabase realtime
class _SupabaseStreamController<T> {
  final _controller = StreamController<T>.broadcast();

  Stream<T> get stream => _controller.stream;

  void add(T data) {
    if (!_controller.isClosed) _controller.add(data);
  }

  void addError(Object error) {
    if (!_controller.isClosed) _controller.addError(error);
  }

  void close() => _controller.close();
}
