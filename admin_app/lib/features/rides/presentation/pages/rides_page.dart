import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/data_table_widget.dart';

// State
class _RidesFilter {
  final String status;
  final String vehicleType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final String search;

  const _RidesFilter({
    this.status = '',
    this.vehicleType = '',
    this.startDate,
    this.endDate,
    this.page = 0,
    this.search = '',
  });

  _RidesFilter copyWith({
    String? status,
    String? vehicleType,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    String? search,
  }) =>
      _RidesFilter(
        status: status ?? this.status,
        vehicleType: vehicleType ?? this.vehicleType,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        page: page ?? this.page,
        search: search ?? this.search,
      );
}

class _RidesState {
  final List<Map<String, dynamic>> rides;
  final bool isLoading;
  final String? error;
  final _RidesFilter filter;
  final bool showMapView;

  const _RidesState({
    this.rides = const [],
    this.isLoading = false,
    this.error,
    this.filter = const _RidesFilter(),
    this.showMapView = false,
  });

  _RidesState copyWith({
    List<Map<String, dynamic>>? rides,
    bool? isLoading,
    String? error,
    _RidesFilter? filter,
    bool? showMapView,
  }) =>
      _RidesState(
        rides: rides ?? this.rides,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        filter: filter ?? this.filter,
        showMapView: showMapView ?? this.showMapView,
      );
}

class _RidesNotifier extends StateNotifier<_RidesState> {
  final SupabaseAdminService _service;

  _RidesNotifier(this._service) : super(const _RidesState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rides = await _service.getRides(
        status: state.filter.status,
        vehicleType: state.filter.vehicleType,
        startDate: state.filter.startDate,
        endDate: state.filter.endDate,
        page: state.filter.page,
      );
      state = state.copyWith(rides: rides, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(_RidesFilter filter) {
    state = state.copyWith(filter: filter.copyWith(page: 0));
    load();
  }

  void setPage(int page) {
    state = state.copyWith(filter: state.filter.copyWith(page: page));
    load();
  }

  void toggleMapView() {
    state = state.copyWith(showMapView: !state.showMapView);
  }
}

final ridesPageProvider =
    StateNotifierProvider<_RidesNotifier, _RidesState>((ref) {
  return _RidesNotifier(
      SupabaseAdminService(ref.watch(supabaseClientProvider)));
});

final activeRidesStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = SupabaseAdminService(ref.watch(supabaseClientProvider));
  return service.watchActiveRides();
});

class RidesPage extends ConsumerWidget {
  const RidesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ridesPageProvider);
    final notifier = ref.read(ridesPageProvider.notifier);
    final currency = NumberFormat.currency(locale: 'am_ET', symbol: '');
    final dateFormat = DateFormat('MM/dd HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Text(
                'إدارة الرحلات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              // Map / Table toggle
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.table_chart, size: 18),
                    label: Text('جدول'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.map, size: 18),
                    label: Text('خريطة'),
                  ),
                ],
                selected: {state.showMapView},
                onSelectionChanged: (s) => notifier.toggleMapView(),
              ),
              const SizedBox(width: 12),
              // Export CSV
              OutlinedButton.icon(
                onPressed: () => _exportCSV(state.rides),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('تصدير CSV'),
              ),
            ],
          ),
        ),

        // Live rides banner
        _ActiveRidesBanner(),

        // Filters
        _FiltersBar(
          filter: state.filter,
          onChanged: notifier.setFilter,
        ),

        // Content
        Expanded(
          child: state.showMapView
              ? _MapView()
              : Card(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: state.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : state.error != null
                                ? Center(child: Text('خطأ: ${state.error}'))
                                : state.rides.isEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.directions_car_outlined,
                                                size: 48,
                                                color: AppColors.textSecondary),
                                            SizedBox(height: 12),
                                            Text('لا توجد رحلات',
                                                style: TextStyle(
                                                    color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      )
                                    : DataTable2(
                                        columnSpacing: 12,
                                        horizontalMargin: 16,
                                        minWidth: 900,
                                        headingRowHeight: 48,
                                        dataRowHeight: 56,
                                        border: TableBorder(
                                          horizontalInside: BorderSide(
                                              color: Colors.grey.shade100),
                                        ),
                                        headingRowColor: WidgetStateProperty.all(
                                          AppColors.primary.withOpacity(0.04),
                                        ),
                                        columns: const [
                                          DataColumn2(
                                              label: Text('المعرّف'),
                                              size: ColumnSize.S),
                                          DataColumn2(
                                              label: Text('الراكب'),
                                              size: ColumnSize.M),
                                          DataColumn2(
                                              label: Text('السائق'),
                                              size: ColumnSize.M),
                                          DataColumn2(
                                              label: Text('النوع'),
                                              size: ColumnSize.S),
                                          DataColumn2(
                                              label: Text('السعر'),
                                              size: ColumnSize.S,
                                              numeric: true),
                                          DataColumn2(
                                              label: Text('التاريخ'),
                                              size: ColumnSize.M),
                                          DataColumn2(
                                              label: Text('الحالة'),
                                              size: ColumnSize.S),
                                        ],
                                        rows: state.rides.map((ride) {
                                          final id = (ride['id'] as String? ?? '')
                                              .substring(0, 8);
                                          final passenger =
                                              ride['passenger'] as Map? ?? {};
                                          final driver =
                                              ride['driver'] as Map? ?? {};
                                          return DataRow2(
                                            cells: [
                                              DataCell(Text(
                                                '#$id',
                                                style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 12),
                                              )),
                                              DataCell(Text(
                                                  passenger['full_name']
                                                          as String? ??
                                                      '—')),
                                              DataCell(Text(driver['full_name']
                                                      as String? ??
                                                  '—')),
                                              DataCell(Text(_vehicleLabel(
                                                  ride['vehicle_type']
                                                          as String? ??
                                                      ''))),
                                              DataCell(Text(
                                                '${currency.format(ride['fare_amount'] ?? 0)} ETB',
                                                textAlign: TextAlign.end,
                                              )),
                                              DataCell(Text(
                                                  ride['created_at'] != null
                                                      ? dateFormat.format(
                                                          DateTime.parse(
                                                              ride['created_at']))
                                                      : '—')),
                                              DataCell(StatusBadge(
                                                  status: ride['status']
                                                          as String? ??
                                                      '')),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  String _vehicleLabel(String type) {
    switch (type) {
      case 'sedan':
        return 'سيدان';
      case 'suv':
        return 'SUV';
      case 'vip':
        return 'VIP';
      case 'minibus':
        return 'ميني باص';
      default:
        return type;
    }
  }

  void _exportCSV(List<Map<String, dynamic>> rides) {
    // TODO: implement CSV export using dart:html for web
  }
}

class _ActiveRidesBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(activeRidesStreamProvider);

    return streamAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (rides) => rides.isEmpty
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${rides.length} رحلة نشطة الآن',
                    style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FiltersBar extends StatefulWidget {
  final _RidesFilter filter;
  final ValueChanged<_RidesFilter> onChanged;

  const _FiltersBar({required this.filter, required this.onChanged});

  @override
  State<_FiltersBar> createState() => _FiltersBarState();
}

class _FiltersBarState extends State<_FiltersBar> {
  late _RidesFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Status filter
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _filter.status.isEmpty ? null : _filter.status,
              decoration: const InputDecoration(
                  labelText: 'الحالة', isDense: true),
              items: const [
                DropdownMenuItem(value: '', child: Text('الكل')),
                DropdownMenuItem(
                    value: 'completed', child: Text('مكتملة')),
                DropdownMenuItem(
                    value: 'in_progress', child: Text('جارية')),
                DropdownMenuItem(
                    value: 'cancelled', child: Text('ملغاة')),
                DropdownMenuItem(
                    value: 'accepted', child: Text('مقبولة')),
              ],
              onChanged: (v) {
                setState(() => _filter = _filter.copyWith(status: v ?? ''));
                widget.onChanged(_filter);
              },
            ),
          ),

          // Vehicle type filter
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _filter.vehicleType.isEmpty ? null : _filter.vehicleType,
              decoration: const InputDecoration(
                  labelText: 'نوع المركبة', isDense: true),
              items: const [
                DropdownMenuItem(value: '', child: Text('الكل')),
                DropdownMenuItem(value: 'sedan', child: Text('سيدان')),
                DropdownMenuItem(value: 'suv', child: Text('SUV')),
                DropdownMenuItem(value: 'vip', child: Text('VIP')),
                DropdownMenuItem(
                    value: 'minibus', child: Text('ميني باص')),
              ],
              onChanged: (v) {
                setState(
                    () => _filter = _filter.copyWith(vehicleType: v ?? ''));
                widget.onChanged(_filter);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Text(
                'خريطة الرحلات النشطة',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'يتطلب مفتاح Google Maps API',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
