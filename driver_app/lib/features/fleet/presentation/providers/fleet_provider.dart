import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Fleet owner ID provider
// ---------------------------------------------------------------------------

final fleetOwnerIdProvider = Provider<String>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';
});

// ---------------------------------------------------------------------------
// FleetState
// ---------------------------------------------------------------------------

class FleetState {
  final bool isLoading;
  final String? error;

  const FleetState({this.isLoading = false, this.error});

  FleetState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FleetState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// FleetNotifier
// ---------------------------------------------------------------------------

class FleetNotifier extends StateNotifier<FleetState> {
  final SupabaseClient _supabase;

  FleetNotifier(this._supabase) : super(const FleetState());

  String get _ownerId => _supabase.auth.currentUser?.id ?? '';

  /// Toggle a vehicle's active status.
  Future<void> toggleVehicleStatus(String vehicleId, bool isActive) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase
          .from('fleet_vehicles')
          .update({'is_active': isActive})
          .eq('id', vehicleId);

      if (!isActive) {
        // Notify the driver assigned to this vehicle, if any.
        final rows = await _supabase
            .from('drivers')
            .select('id')
            .eq('fleet_vehicle_id', vehicleId)
            .limit(1);
        if (rows is List && rows.isNotEmpty) {
          _supabase.functions.invoke('send-notification', body: {
            'user_id': rows.first['id'] as String,
            'title': 'تم تعطيل سيارتك',
            'body': 'قام صاحب الأسطول بتعطيل السيارة المخصصة لك مؤقتاً.',
            'type': 'vehicle_deactivated',
          }).ignore();
        }
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Add a new vehicle to the fleet.
  Future<bool> addVehicle({
    required String plateNumber,
    required String type,
    required String model,
    required int year,
    required String color,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase.from('fleet_vehicles').insert({
        'fleet_owner_id': _ownerId,
        'plate_number': plateNumber,
        'type': type,
        'model': model,
        'year': year,
        'color': color,
        'is_active': true,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Invite a new driver via phone number.
  Future<String?> inviteDriver({
    required String phone,
    required String tempPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase.from('fleet_driver_invitations').insert({
        'fleet_owner_id': _ownerId,
        'phone': phone,
        'temp_password': tempPassword,
        'status': 'pending',
      });
      state = state.copyWith(isLoading: false);
      return tempPassword;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Update a driver's profit share percentage.
  Future<void> updateDriverShare(String driverId, double sharePercent) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase
          .from('drivers')
          .update({'driver_share_percent': sharePercent})
          .eq('id', driverId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Remove a driver from the fleet.
  Future<void> removeDriver(String driverId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase
          .from('drivers')
          .update({'fleet_owner_id': null})
          .eq('id', driverId);

      _supabase.functions.invoke('send-notification', body: {
        'user_id': driverId,
        'title': 'تم فصلك من الأسطول',
        'body': 'قام صاحب الأسطول بفصلك. يمكنك الاستمرار كسائق مستقل.',
        'type': 'fleet_removed',
      }).ignore();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Mark a settlement as waived.
  Future<void> waiveSettlement(String settlementId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _supabase
          .from('fleet_owner_settlements')
          .update({'is_waived': true})
          .eq('id', settlementId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final fleetNotifierProvider =
    StateNotifierProvider<FleetNotifier, FleetState>((ref) {
  return FleetNotifier(ref.watch(supabaseClientProvider));
});
