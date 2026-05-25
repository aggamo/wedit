import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/data_table_widget.dart';

final _complaintsSvcProvider = Provider<SupabaseAdminService>((ref) {
  return SupabaseAdminService(ref.watch(supabaseClientProvider));
});

class _ComplaintsFilter {
  final String status;
  final String category;
  final int page;

  const _ComplaintsFilter({
    this.status = 'open',
    this.category = '',
    this.page = 0,
  });

  _ComplaintsFilter copyWith({
    String? status,
    String? category,
    int? page,
  }) =>
      _ComplaintsFilter(
        status: status ?? this.status,
        category: category ?? this.category,
        page: page ?? this.page,
      );
}

class _ComplaintsState {
  final List<Map<String, dynamic>> complaints;
  final bool isLoading;
  final String? error;
  final _ComplaintsFilter filter;
  final String? expandedId;

  const _ComplaintsState({
    this.complaints = const [],
    this.isLoading = false,
    this.error,
    this.filter = const _ComplaintsFilter(),
    this.expandedId,
  });

  _ComplaintsState copyWith({
    List<Map<String, dynamic>>? complaints,
    bool? isLoading,
    String? error,
    _ComplaintsFilter? filter,
    String? expandedId,
    bool clearExpanded = false,
  }) =>
      _ComplaintsState(
        complaints: complaints ?? this.complaints,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        filter: filter ?? this.filter,
        expandedId: clearExpanded ? null : (expandedId ?? this.expandedId),
      );
}

class _ComplaintsNotifier extends StateNotifier<_ComplaintsState> {
  final SupabaseAdminService _service;

  _ComplaintsNotifier(this._service) : super(const _ComplaintsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final complaints = await _service.getComplaints(
        status: state.filter.status,
        category: state.filter.category,
        page: state.filter.page,
      );
      state = state.copyWith(complaints: complaints, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(_ComplaintsFilter filter) {
    state = state.copyWith(filter: filter.copyWith(page: 0));
    load();
  }

  void toggleExpanded(String id) {
    if (state.expandedId == id) {
      state = state.copyWith(clearExpanded: true);
    } else {
      state = state.copyWith(expandedId: id);
    }
  }

  Future<void> resolve(String id, String note) async {
    await _service.resolveComplaint(id, adminNote: note);
    load();
  }
}

final complaintsProvider =
    StateNotifierProvider<_ComplaintsNotifier, _ComplaintsState>((ref) {
  return _ComplaintsNotifier(ref.watch(_complaintsSvcProvider));
});

class ComplaintsPage extends ConsumerWidget {
  const ComplaintsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(complaintsProvider);
    final notifier = ref.read(complaintsProvider.notifier);
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

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
                'إدارة الشكاوى',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'تحديث',
                onPressed: notifier.load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: _FiltersRow(
            filter: state.filter,
            onChanged: notifier.setFilter,
          ),
        ),

        // Table
        Expanded(
          child: Card(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('خطأ: ${state.error}'))
                    : state.complaints.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 56, color: AppColors.success),
                                SizedBox(height: 12),
                                Text('لا توجد شكاوى مفتوحة',
                                    style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 16)),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: state.complaints.map((complaint) {
                                final isExpanded =
                                    state.expandedId == complaint['id'];
                                return _ComplaintRow(
                                  complaint: complaint,
                                  isExpanded: isExpanded,
                                  dateFormat: dateFormat,
                                  onTap: () => notifier
                                      .toggleExpanded(complaint['id']),
                                  onResolve: (note) => notifier
                                      .resolve(complaint['id'], note),
                                );
                              }).toList(),
                            ),
                          ),
          ),
        ),
      ],
    );
  }
}

class _FiltersRow extends StatefulWidget {
  final _ComplaintsFilter filter;
  final ValueChanged<_ComplaintsFilter> onChanged;

  const _FiltersRow(
      {required this.filter, required this.onChanged});

  @override
  State<_FiltersRow> createState() => _FiltersRowState();
}

class _FiltersRowState extends State<_FiltersRow> {
  late _ComplaintsFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            value: _filter.status.isEmpty ? null : _filter.status,
            decoration: const InputDecoration(
                labelText: 'الحالة', isDense: true),
            items: const [
              DropdownMenuItem(value: '', child: Text('الكل')),
              DropdownMenuItem(value: 'open', child: Text('مفتوح')),
              DropdownMenuItem(
                  value: 'resolved', child: Text('محلول')),
              DropdownMenuItem(
                  value: 'dismissed', child: Text('مُتجاهَل')),
            ],
            onChanged: (v) {
              setState(
                  () => _filter = _filter.copyWith(status: v ?? ''));
              widget.onChanged(_filter);
            },
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _filter.category.isEmpty ? null : _filter.category,
            decoration: const InputDecoration(
                labelText: 'التصنيف', isDense: true),
            items: const [
              DropdownMenuItem(value: '', child: Text('الكل')),
              DropdownMenuItem(
                  value: 'driver_behavior',
                  child: Text('سلوك السائق')),
              DropdownMenuItem(
                  value: 'passenger_behavior',
                  child: Text('سلوك الراكب')),
              DropdownMenuItem(
                  value: 'payment', child: Text('مشكلة دفع')),
              DropdownMenuItem(
                  value: 'app_issue', child: Text('مشكلة تقنية')),
              DropdownMenuItem(value: 'other', child: Text('أخرى')),
            ],
            onChanged: (v) {
              setState(
                  () => _filter = _filter.copyWith(category: v ?? ''));
              widget.onChanged(_filter);
            },
          ),
        ),
      ],
    );
  }
}

class _ComplaintRow extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final bool isExpanded;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final ValueChanged<String> onResolve;

  const _ComplaintRow({
    required this.complaint,
    required this.isExpanded,
    required this.dateFormat,
    required this.onTap,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final reporter = complaint['reporter'] as Map? ?? {};
    final reported = complaint['reported'] as Map? ?? {};
    final status = complaint['status'] as String? ?? 'open';
    final category = complaint['category'] as String? ?? '';
    final description = complaint['description'] as String? ?? '';
    final rideId = complaint['ride_id'] as String? ?? '';
    final createdAt = complaint['created_at'] as String?;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isExpanded
            ? AppColors.primary.withOpacity(0.03)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Column(
        children: [
          // Main row (clickable)
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: status == 'open'
                          ? AppColors.warning
                          : AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Reporter
                  SizedBox(
                    width: 130,
                    child: Text(
                      reporter['full_name'] as String? ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // → icon
                  const Icon(Icons.arrow_forward,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),

                  // Reported
                  SizedBox(
                    width: 130,
                    child: Text(
                      reported['full_name'] as String? ?? '—',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _categoryLabel(category),
                      style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Description preview
                  Expanded(
                    child: Text(
                      description,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13),
                    ),
                  ),

                  // Date
                  if (createdAt != null)
                    Text(
                      dateFormat.format(DateTime.parse(createdAt)),
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12),
                    ),
                  const SizedBox(width: 12),

                  StatusBadge(status: status),
                  const SizedBox(width: 8),

                  // Expand icon
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _ExpandedContent(
                complaint: complaint,
                description: description,
                rideId: rideId,
                adminNote: complaint['admin_note'] as String? ?? '',
                status: status,
                onResolve: onResolve,
              ),
            ),
        ],
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'driver_behavior':
        return 'سلوك السائق';
      case 'passenger_behavior':
        return 'سلوك الراكب';
      case 'payment':
        return 'مشكلة دفع';
      case 'app_issue':
        return 'مشكلة تقنية';
      default:
        return cat.isNotEmpty ? cat : 'أخرى';
    }
  }
}

class _ExpandedContent extends StatefulWidget {
  final Map<String, dynamic> complaint;
  final String description;
  final String rideId;
  final String adminNote;
  final String status;
  final ValueChanged<String> onResolve;

  const _ExpandedContent({
    required this.complaint,
    required this.description,
    required this.rideId,
    required this.adminNote,
    required this.status,
    required this.onResolve,
  });

  @override
  State<_ExpandedContent> createState() => _ExpandedContentState();
}

class _ExpandedContentState extends State<_ExpandedContent> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.adminNote);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full description
        const Text(
          'تفاصيل الشكوى:',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(widget.description),
        ),

        if (widget.rideId.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('رقم الرحلة: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              SelectableText(
                '#${widget.rideId.substring(0, 8)}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Admin note
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(
            labelText: 'ملاحظة المدير',
            hintText: 'أضف ملاحظتك هنا...',
          ),
          maxLines: 3,
          enabled: widget.status == 'open',
        ),
        const SizedBox(height: 12),

        if (widget.status == 'open')
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('تجاهل'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  widget.onResolve(_noteCtrl.text.trim());
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('تحديد كمحلول'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success),
              ),
            ],
          )
        else
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Text(
                'تمت معالجة هذه الشكوى',
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
      ],
    );
  }
}
