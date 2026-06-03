import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/earnings_entity.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_request_entity.dart';

abstract class RideRemoteDatasource {
  Stream<List<RideRequestEntity>> streamIncomingRequests(String driverId);
  Stream<RideEntity?> streamCurrentRide(String driverId);
  Future<void> submitOffer(String rideId, String driverId, double price,
      bool isSystemPrice, bool isSurgeOffer);
  Future<void> declineRequest(String rideId, String driverId);
  Future<void> toggleSurge(String driverId, bool enabled);
  Future<bool> canReceiveRequests(String driverId);
  Future<void> updateLocation(
      String driverId, double lat, double lng, double heading);
  Future<void> markArrived(String rideId, String driverId);
  Future<void> startRide(String rideId, String driverId);
  Future<void> completeRide(String rideId, String driverId);
  Future<void> setOnlineStatus(String driverId, bool isOnline);
  Future<EarningsEntity> getEarnings(String driverId, String period);
  Future<RideEntity> startStreetHailRide({
    required String driverId,
    required String passengerPhone,
    required String vehicleType,
    required double startLat,
    required double startLng,
    String? destination,
  });
  Future<double> endStreetHailRide({
    required String rideId,
    required String driverId,
    required double endLat,
    required double endLng,
    required double distanceKm,
    required double durationMinutes,
  });
  Future<void> declineCallCenterRide(String rideId);
}

class RideRemoteDatasourceImpl implements RideRemoteDatasource {
  final SupabaseClient _supabase;

  RideRemoteDatasourceImpl(this._supabase);

  @override
  Stream<List<RideRequestEntity>> streamIncomingRequests(String driverId) {
    return _supabase
        .from(AppConstants.rideRequestsTable)
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .asyncMap((data) async {
          // Fleet driver checks: car active + daily trips limit
          try {
            final driverRow = await _supabase
                .from('drivers')
                .select('is_car_active, max_daily_trips, daily_trips_count, daily_trips_reset_at')
                .eq('id', driverId)
                .maybeSingle();
            if (driverRow != null) {
              final isCarActive = driverRow['is_car_active'] as bool? ?? true;
              if (!isCarActive) return <RideRequestEntity>[];

              final maxTrips = driverRow['max_daily_trips'] as int?;
              final todayCount = driverRow['daily_trips_count'] as int? ?? 0;
              if (maxTrips != null && todayCount >= maxTrips) {
                return <RideRequestEntity>[];
              }
            }
          } catch (_) {}

          final active = data.where((row) =>
              row['expires_at'] != null &&
              DateTime.parse(row['expires_at']).isAfter(DateTime.now()));

          final requests = <RideRequestEntity>[];
          for (final row in active) {
            final rideId = row['id'] as String;
            int competitorCount = 0;
            try {
              final countData = await _supabase
                  .from('ride_offers')
                  .select('id')
                  .eq('ride_id', rideId)
                  .eq('status', 'pending')
                  .neq('driver_id', driverId);
              competitorCount = (countData as List).length;
            } catch (_) {}
            requests.add(_mapToRequest(row, competitorCount: competitorCount));
          }
          return requests;
        });
  }

  @override
  Stream<RideEntity?> streamCurrentRide(String driverId) {
    return _supabase
        .from(AppConstants.ridesTable)
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .inFilter('status', ['accepted', 'driver_arrived', 'in_progress'])
        .map((data) => data.isEmpty ? null : _mapToRide(data.first));
  }

  @override
  Future<void> submitOffer(String rideId, String driverId, double price,
      bool isSystemPrice, bool isSurgeOffer) async {
    try {
      await _supabase.from('ride_offers').insert({
        'ride_id': rideId,
        'driver_id': driverId,
        'offered_price': price,
        'is_system_price': isSystemPrice,
        'is_surge_offer': isSurgeOffer,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> toggleSurge(String driverId, bool enabled) async {
    try {
      await _supabase
          .from('drivers')
          .update({'surge_enabled': enabled})
          .eq('id', driverId);
    } catch (_) {}
  }

  @override
  Future<bool> canReceiveRequests(String driverId) async {
    try {
      final row = await _supabase
          .from('drivers')
          .select('is_car_active, max_daily_trips, daily_trips_count')
          .eq('id', driverId)
          .maybeSingle();
      if (row == null) return true;
      if (row['is_car_active'] == false) return false;
      final max = row['max_daily_trips'] as int?;
      final count = row['daily_trips_count'] as int? ?? 0;
      if (max != null && count >= max) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> declineRequest(String rideId, String driverId) async {
    try {
      await _supabase.from('ride_declines').insert({
        'ride_id': rideId,
        'driver_id': driverId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Non-critical
    }
  }

  @override
  Future<void> updateLocation(
      String driverId, double lat, double lng, double heading) async {
    try {
      await _supabase.from(AppConstants.driversTable).update({
        'current_lat': lat,
        'current_lng': lng,
        'heading': heading,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', driverId);
    } catch (e) {
      // Non-critical
    }
  }

  @override
  Future<void> markArrived(String rideId, String driverId) async {
    try {
      await _supabase
          .from(AppConstants.ridesTable)
          .update({
            'status': 'driver_arrived',
            'arrived_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', driverId);
    } on PostgrestException catch (e) {
      throw RideFailure(e.message);
    }
  }

  @override
  Future<void> startRide(String rideId, String driverId) async {
    try {
      await _supabase
          .from(AppConstants.ridesTable)
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', driverId);
    } on PostgrestException catch (e) {
      throw RideFailure(e.message);
    }
  }

  @override
  Future<void> completeRide(String rideId, String driverId) async {
    try {
      await _supabase
          .from(AppConstants.ridesTable)
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', driverId);
    } on PostgrestException catch (e) {
      throw RideFailure(e.message);
    }
  }

  @override
  Future<void> setOnlineStatus(String driverId, bool isOnline) async {
    try {
      await _supabase.from(AppConstants.driversTable).update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', driverId);
    } catch (e) {
      // Non-critical
    }
  }

  @override
  Future<EarningsEntity> getEarnings(String driverId, String period) async {
    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (period) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(2020, 1, 1);
      }

      final data = await _supabase
          .from(AppConstants.ridesTable)
          .select('agreed_price, completed_at, created_at')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .gte('completed_at', startDate.toIso8601String())
          .order('completed_at', ascending: false);

      double total = 0;
      for (final row in data) {
        total += (row['agreed_price'] as num?)?.toDouble() ?? 0;
      }

      // Build daily breakdown
      final Map<String, (double, int)> dailyMap = {};
      for (final row in data) {
        final completedAt = row['completed_at'] as String?;
        if (completedAt != null) {
          final date = DateTime.parse(completedAt);
          final key = '${date.year}-${date.month}-${date.day}';
          final amount = (row['agreed_price'] as num?)?.toDouble() ?? 0;
          final existing = dailyMap[key];
          if (existing != null) {
            dailyMap[key] = (existing.$1 + amount, existing.$2 + 1);
          } else {
            dailyMap[key] = (amount, 1);
          }
        }
      }

      final breakdown = dailyMap.entries.map((e) {
        final parts = e.key.split('-');
        return DailyEarning(
          date: DateTime(int.parse(parts[0]), int.parse(parts[1]),
              int.parse(parts[2])),
          amount: e.value.$1,
          rides: e.value.$2,
        );
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final allTimeData = await _supabase
          .from(AppConstants.ridesTable)
          .select('agreed_price')
          .eq('driver_id', driverId)
          .eq('status', 'completed');

      double allTime = 0;
      for (final row in allTimeData) {
        allTime += (row['agreed_price'] as num?)?.toDouble() ?? 0;
      }

      final count = data.length;
      return EarningsEntity(
        todayTotal: period == 'today' ? total : 0,
        weekTotal: period == 'week' ? total : 0,
        monthTotal: period == 'month' ? total : 0,
        allTimeTotal: allTime,
        ridesCount: count,
        averagePerRide: count > 0 ? total / count : 0,
        dailyBreakdown: breakdown,
      );
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<RideEntity> startStreetHailRide({
    required String driverId,
    required String passengerPhone,
    required String vehicleType,
    required double startLat,
    required double startLng,
    String? destination,
  }) async {
    try {
      // Fetch driver's vehicle plate for SMS
      String plateNumber = '';
      String driverName = '';
      try {
        final driverData = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', driverId)
            .maybeSingle();
        driverName = driverData?['full_name'] as String? ?? '';

        final vehicleData = await _supabase
            .from('vehicles')
            .select('plate')
            .eq('driver_id', driverId)
            .eq('is_active', true)
            .maybeSingle();
        plateNumber = vehicleData?['plate'] as String? ?? '';
      } catch (_) {}

      final now = DateTime.now().toIso8601String();

      final rideData = await _supabase.from(AppConstants.ridesTable).insert({
        'driver_id':       driverId,
        'passenger_id':    driverId, // self-reference; no app passenger
        'passenger_name':  passengerPhone,
        'passenger_phone': passengerPhone,
        'pickup_lat':      startLat,
        'pickup_lng':      startLng,
        'pickup_address':  'شارع — موقع GPS',
        'dropoff_lat':     startLat,
        'dropoff_lng':     startLng,
        'dropoff_address': destination ?? '',
        'vehicle_type':    vehicleType,
        'ride_type':       'street_hail',
        'status':          'in_progress',
        'payment_method':  'cash',
        'agreed_price':    0,
        'started_at':      now,
        'created_at':      now,
      }).select().single();

      // Fire-and-forget SMS (ride_start)
      if (driverName.isNotEmpty && plateNumber.isNotEmpty) {
        _supabase.functions.invoke('send-sms', body: {
          'ride_id':      rideData['id'],
          'message_type': 'ride_start',
          'phone_number': passengerPhone,
          'driver_name':  driverName,
          'plate_number': plateNumber,
        }).ignore();
      }

      return _mapToRide(rideData);
    } on PostgrestException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      if (e is ServerFailure) rethrow;
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<double> endStreetHailRide({
    required String rideId,
    required String driverId,
    required double endLat,
    required double endLng,
    required double distanceKm,
    required double durationMinutes,
  }) async {
    try {
      // Retrieve original ride for fare calculation
      final original = await _supabase
          .from(AppConstants.ridesTable)
          .select('vehicle_type, passenger_phone, started_at')
          .eq('id', rideId)
          .single();

      final vehicleType = original['vehicle_type'] as String? ?? 'sedan';
      final passengerPhone = original['passenger_phone'] as String? ?? '';

      // Calculate final fare
      double base, ppk, ppm;
      switch (vehicleType) {
        case 'suv':     base = 35; ppk = 12; ppm = 2.0; break;
        case 'vip':     base = 60; ppk = 20; ppm = 3.5; break;
        case 'minibus': base = 20; ppk = 6;  ppm = 1.0; break;
        default:        base = 25; ppk = 8;  ppm = 1.5;
      }
      final fare =
          (base + ppk * distanceKm + ppm * durationMinutes).roundToDouble();

      final now = DateTime.now().toIso8601String();

      await _supabase.from(AppConstants.ridesTable).update({
        'status':       'completed',
        'agreed_price': fare,
        'final_price':  fare,
        'dropoff_lat':  endLat,
        'dropoff_lng':  endLng,
        'distance_km':  distanceKm,
        'completed_at': now,
      }).eq('id', rideId).eq('driver_id', driverId);

      // Fire-and-forget SMS (ride_end)
      if (passengerPhone.isNotEmpty) {
        _supabase.functions.invoke('send-sms', body: {
          'ride_id':      rideId,
          'message_type': 'ride_end',
          'phone_number': passengerPhone,
          'driver_name':  '',
          'plate_number': '',
          'total_fare':   fare,
        }).ignore();
      }

      return fare;
    } on PostgrestException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      if (e is ServerFailure) rethrow;
      throw ServerFailure(e.toString());
    }
  }

  RideRequestEntity _mapToRequest(Map<String, dynamic> data,
      {int competitorCount = 0}) {
    return RideRequestEntity(
      rideId: data['id'] as String,
      passengerId: data['passenger_id'] as String? ?? '',
      passengerName: data['passenger_name'] as String? ?? 'راكب',
      passengerRating: (data['passenger_rating'] as num?)?.toDouble() ?? 5.0,
      pickupLat: (data['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (data['pickup_lng'] as num?)?.toDouble() ?? 0,
      pickupAddress: data['pickup_address'] as String? ?? '',
      dropoffLat: (data['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (data['dropoff_lng'] as num?)?.toDouble() ?? 0,
      dropoffAddress: data['dropoff_address'] as String? ?? '',
      vehicleType: data['vehicle_type'] as String? ?? 'sedan',
      estimatedPrice: (data['estimated_price'] as num?)?.toDouble() ?? 0,
      distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0,
      expiresAt: data['expires_at'] != null
          ? DateTime.parse(data['expires_at'] as String)
          : DateTime.now().add(const Duration(seconds: 45)),
      competitorCount: competitorCount,
    );
  }

  RideEntity _mapToRide(Map<String, dynamic> data) {
    return RideEntity(
      id: data['id'] as String,
      passengerId: data['passenger_id'] as String? ?? '',
      driverId: data['driver_id'] as String?,
      passengerName: data['passenger_name'] as String? ?? 'راكب',
      passengerRating: (data['passenger_rating'] as num?)?.toDouble() ?? 5.0,
      pickupLat: (data['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (data['pickup_lng'] as num?)?.toDouble() ?? 0,
      pickupAddress: data['pickup_address'] as String? ?? '',
      dropoffLat: (data['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (data['dropoff_lng'] as num?)?.toDouble() ?? 0,
      dropoffAddress: data['dropoff_address'] as String? ?? '',
      vehicleType: data['vehicle_type'] as String? ?? 'sedan',
      rideType: data['ride_type'] as String? ?? 'app_request',
      agreedPrice: (data['agreed_price'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'accepted',
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
      startedAt: data['started_at'] != null
          ? DateTime.parse(data['started_at'] as String)
          : null,
      completedAt: data['completed_at'] != null
          ? DateTime.parse(data['completed_at'] as String)
          : null,
      passengerPhone: data['passenger_phone'] as String?,
      driverLat:      (data['driver_lat']      as num?)?.toDouble(),
      driverLng:      (data['driver_lng']      as num?)?.toDouble(),
      driverHeading:  (data['driver_heading']  as num?)?.toDouble(),
      estimatedPrice: (data['estimated_price'] as num?)?.toDouble(),
    );
  }

  Future<void> declineCallCenterRide(String rideId) async {
    try {
      await _supabase.functions.invoke(
        'decline-call-center-ride',
        body: {'ride_id': rideId},
      );
    } catch (_) {
      // Non-critical
    }
  }
}
