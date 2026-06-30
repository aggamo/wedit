import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';

class FleetTermsScreen extends ConsumerStatefulWidget {
  final bool readOnly; // true = viewing from settings (no accept button)
  final String userRole; // 'fleet_owner' or 'driver'

  const FleetTermsScreen({
    super.key,
    this.readOnly = false,
    this.userRole = 'driver',
  });

  @override
  ConsumerState<FleetTermsScreen> createState() => _FleetTermsScreenState();
}

class _FleetTermsScreenState extends ConsumerState<FleetTermsScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _canAccept = false;
  bool _isAccepting = false;
  String? _error;

  String? _documentId;
  String _titleAr = 'شروط وأحكام الأسطول';
  String _contentAr = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchDocument();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_canAccept) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 50) {
      setState(() => _canAccept = true);
    }
  }

  Future<void> _fetchDocument() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('legal_documents')
          .select('id, title_ar, content_ar')
          .eq('doc_type', 'fleet_terms')
          .eq('is_active', true)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _isLoading = false;
          _error = 'لا يوجد مستند نشط';
        });
        return;
      }

      setState(() {
        _documentId = data['id'] as String;
        _titleAr = (data['title_ar'] as String?) ?? _titleAr;
        _contentAr = (data['content_ar'] as String?) ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'حدث خطأ أثناء تحميل الوثيقة';
      });
    }
  }

  Future<void> _accept() async {
    if (!_canAccept || _isAccepting || _documentId == null) return;

    setState(() => _isAccepting = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطأ: المستخدم غير مسجل الدخول')),
          );
        }
        return;
      }

      await supabase.from('legal_document_acceptances').insert({
        'user_id': userId,
        'document_id': _documentId,
        'accepted_at': DateTime.now().toIso8601String(),
        'user_role': widget.userRole,
      });

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء حفظ الموافقة، يرجى المحاولة مجدداً')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleAr,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: widget.readOnly
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]
            : null,
      ),
      body: _buildBody(),
      bottomNavigationBar: (!widget.readOnly && !_isLoading && _error == null)
          ? _buildAcceptBar()
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 16, fontFamily: 'Cairo'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _fetchDocument();
                },
                child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Text(
          _contentAr,
          style: const TextStyle(
            fontSize: 15,
            height: 1.8,
            fontFamily: 'Cairo',
            color: Colors.black87,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  Widget _buildAcceptBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_canAccept)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'يرجى قراءة الشروط والأحكام كاملاً للمتابعة',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canAccept && !_isAccepting ? _accept : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isAccepting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'أوافق على القواعد والشروط',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
