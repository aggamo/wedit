import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final currentAdminProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    final response = await supabase
        .from('admins')
        .select('*')
        .eq('user_id', user.id)
        .single();
    return response;
  } catch (e) {
    return null;
  }
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final adminData = await ref.watch(currentAdminProvider.future);
  return adminData != null;
});

// Dashboard stats provider
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

    final ridesCount = await supabase
        .from('rides')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .gte('created_at', startOfDay);

    final activeDrivers = await supabase
        .from('drivers')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('status', 'online');

    final revenue = await supabase
        .from('rides')
        .select('fare_amount')
        .gte('created_at', startOfDay)
        .eq('status', 'completed');

    double totalRevenue = 0;
    for (final ride in (revenue as List)) {
      totalRevenue += (ride['fare_amount'] ?? 0).toDouble();
    }

    final newRegistrations = await supabase
        .from('drivers')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .gte('created_at', startOfDay);

    return {
      'rides_today': ridesCount.count ?? 0,
      'active_drivers': activeDrivers.count ?? 0,
      'revenue_today': totalRevenue,
      'new_registrations': newRegistrations.count ?? 0,
    };
  } catch (e) {
    return {
      'rides_today': 0,
      'active_drivers': 0,
      'revenue_today': 0.0,
      'new_registrations': 0,
    };
  }
});

// Pending items counts for badges
final pendingCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final pendingDrivers = await supabase
        .from('drivers')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('status', 'pending');

    final pendingTransfers = await supabase
        .from('subscriptions')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('payment_method', 'bank_transfer')
        .eq('payment_status', 'pending');

    final openComplaints = await supabase
        .from('complaints')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('status', 'open');

    return {
      'pending_drivers': pendingDrivers.count ?? 0,
      'pending_transfers': pendingTransfers.count ?? 0,
      'open_complaints': openComplaints.count ?? 0,
    };
  } catch (e) {
    return {
      'pending_drivers': 0,
      'pending_transfers': 0,
      'open_complaints': 0,
    };
  }
});
