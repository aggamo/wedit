import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../theme/app_theme.dart';

class AdminDataTable extends StatefulWidget {
  final List<DataColumn2> columns;
  final List<DataRow2> rows;
  final int totalRows;
  final int currentPage;
  final int pageSize;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<String>? onSearch;
  final List<Widget>? filters;
  final String? searchHint;
  final bool isLoading;
  final Widget? emptyWidget;
  final List<Widget>? actions;

  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.totalRows = 0,
    this.currentPage = 0,
    this.pageSize = 20,
    this.onPageChanged,
    this.onSearch,
    this.filters,
    this.searchHint,
    this.isLoading = false,
    this.emptyWidget,
    this.actions,
  });

  @override
  State<AdminDataTable> createState() => _AdminDataTableState();
}

class _AdminDataTableState extends State<AdminDataTable> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (widget.totalRows / widget.pageSize).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (widget.onSearch != null) ...[
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: widget.searchHint ?? 'بحث...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                widget.onSearch?.call('');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: widget.onSearch,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (widget.filters != null) ...widget.filters!,
              const Spacer(),
              if (widget.actions != null) ...widget.actions!,
            ],
          ),
        ),

        // Table
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : widget.rows.isEmpty
                  ? widget.emptyWidget ??
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48, color: AppColors.textSecondary),
                            SizedBox(height: 12),
                            Text(
                              'لا توجد بيانات',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                  : DataTable2(
                      columnSpacing: 16,
                      horizontalMargin: 16,
                      minWidth: 600,
                      headingRowHeight: 48,
                      dataRowHeight: 52,
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.primary.withOpacity(0.04),
                      ),
                      columns: widget.columns,
                      rows: widget.rows,
                    ),
        ),

        // Pagination
        if (widget.onPageChanged != null && widget.totalRows > widget.pageSize)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عرض ${widget.currentPage * widget.pageSize + 1}–'
                  '${((widget.currentPage + 1) * widget.pageSize).clamp(0, widget.totalRows)} '
                  'من ${widget.totalRows}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: widget.currentPage > 0
                          ? () => widget.onPageChanged
                              ?.call(widget.currentPage - 1)
                          : null,
                    ),
                    ...List.generate(
                      totalPages.clamp(0, 5),
                      (i) {
                        final page = i;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            onTap: () => widget.onPageChanged?.call(page),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: page == widget.currentPage
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${page + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: page == widget.currentPage
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: widget.currentPage < totalPages - 1
                          ? () => widget.onPageChanged
                              ?.call(widget.currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Status badge widget reused across tables
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color) _statusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'completed':
      case 'confirmed':
      case 'online':
        return ('نشط', AppColors.success);
      case 'pending':
        return ('معلق', AppColors.warning);
      case 'suspended':
      case 'rejected':
      case 'cancelled':
        return ('موقوف', AppColors.error);
      case 'offline':
        return ('غير متصل', AppColors.textSecondary);
      case 'in_progress':
      case 'accepted':
        return ('جارٍ', AppColors.info);
      case 'resolved':
        return ('محلول', AppColors.success);
      case 'open':
        return ('مفتوح', AppColors.warning);
      case 'expired':
        return ('منتهي', AppColors.textSecondary);
      default:
        return (status, AppColors.textSecondary);
    }
  }
}
