import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/earnings_entity.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_request_entity.dart';

abstract class RideRemoteDatasource {
  Stream<List<RideRequestEntity>> streamIncomingRequests(String driverId);
  Stream<RideEntity?> streamCurrentRide(String driverId);
  Future<void> submitOffer(
      String rideId, String driverId, double price, bool isSystemPrice);
  Future<void> declineRequest(String rideId, String driverId);
  Future<void> updateLocation(
      String driverId, double lat, double lng, double heading);
  Future<void> markArrived(String rideId, String driverId);
  Future<void> startRide(String rideId, String driverId);
  Future<void> completeRide(String rideId, String driverId);
  Future<void> setOnlineStatus(String driverId, bool isOnline);
  Future<EarningsEntity> getEarnings(String driverId, String period);
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
  Future<void> submitOffer(
      String rideId, String driverId, double price, bool isSystemPrice) async {
    try {
      await _supabase.from('ride_offers').insert({
        'ride_id': rideId,
        'driver_id': driverId,
        'offered_price': price,
        'is_system_price': isSystemPrice,
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
      driverLat: (data['driver_lat'] as num?)?.toDouble(),
      driverLng: (data['driver_lng'] as num?)?.toDouble(),
      driverHeading: (data['driver_heading'] as num?)?.toDouble(),
    );
  }
}
