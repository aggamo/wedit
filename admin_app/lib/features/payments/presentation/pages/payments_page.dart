import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _supabase
          .from('payments')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      setState(() { _payments = List<Map<String, dynamic>>.from(data); });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('المدفوعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('خطأ: $_error'))
              : _payments.isEmpty
                  ? const Center(child: Text('لا توجد مدفوعات بعد'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('المعرف')),
                          DataColumn(label: Text('السائق')),
                          DataColumn(label: Text('المبلغ (ETB)')),
                          DataColumn(label: Text('الطريقة')),
                          DataColumn(label: Text('الحالة')),
                          DataColumn(label: Text('التاريخ')),
                        ],
                        rows: _payments.map((p) {
                          final id = (p['id'] as String?)?.substring(0, 8) ?? '-';
                          final driver = p['driver_id'] as String? ?? '-';
                          final amount = p['amount'] != null
                              ? fmt.format(p['amount'])
                              : '-';
                          final method = p['payment_method'] as String? ?? '-';
                          final status = p['status'] as String? ?? '-';
                          final date = p['created_at'] != null
                              ? dateFmt.format(DateTime.parse(p['created_at'] as String).toLocal())
                              : '-';
                          return DataRow(cells: [
                            DataCell(Text(id)),
                            DataCell(Text(driver.substring(0, 8))),
                            DataCell(Text(amount)),
                            DataCell(Text(method)),
                            DataCell(Text(status)),
                            DataCell(Text(date)),
                          ]);
                        }).toList(),
                      ),
                    ),
    );
  }
}
