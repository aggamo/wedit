import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class BankTransferWidget extends StatefulWidget {
  final File? receiptFile;
  final VoidCallback onPickReceipt;

  const BankTransferWidget({
    super.key,
    this.receiptFile,
    required this.onPickReceipt,
  });

  @override
  State<BankTransferWidget> createState() => _BankTransferWidgetState();
}

class _BankTransferWidgetState extends State<BankTransferWidget> {
  bool _copied = false;

  void _copyAccount() async {
    await Clipboard.setData(
        const ClipboardData(text: AppConstants.bankAccount));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_rounded,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'بيانات التحويل البنكي',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow('اسم البنك', AppConstants.bankName),
            const SizedBox(height: 8),
            _infoRow('اسم الحساب', AppConstants.bankHolder),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'رقم الحساب:',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppConstants.bankAccount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: TextButton.icon(
                    onPressed: _copyAccount,
                    icon: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 16,
                    ),
                    label: Text(_copied ? 'تم النسخ' : 'نسخ'),
                    style: TextButton.styleFrom(
                      foregroundColor: _copied
                          ? AppTheme.secondaryColor
                          : AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'بعد التحويل، يرجى رفع صورة الإيصال:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: widget.onPickReceipt,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: widget.receiptFile != null ? 180 : 80,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.receiptFile != null
                        ? AppTheme.secondaryColor
                        : theme.colorScheme.outline.withOpacity(0.4),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: widget.receiptFile != null
                      ? AppTheme.secondaryColor.withOpacity(0.05)
                      : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                child: widget.receiptFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(widget.receiptFile!, fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.secondaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.upload_file_rounded,
                              color: Colors.grey, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'اضغط لرفع الإيصال',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.tertiaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppTheme.tertiaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم تفعيل اشتراكك خلال ساعات قليلة بعد التحقق من التحويل.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.brown.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
