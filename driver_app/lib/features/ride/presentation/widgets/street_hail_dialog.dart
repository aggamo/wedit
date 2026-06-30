import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Result returned when the driver confirms a street-hail ride.
class StreetHailParams {
  final String passengerPhone;
  final String vehicleType;
  final String? destination;

  const StreetHailParams({
    required this.passengerPhone,
    required this.vehicleType,
    this.destination,
  });
}

/// Shows the street-hail setup dialog.
/// Returns [StreetHailParams] on confirm or null on cancel.
Future<StreetHailParams?> showStreetHailDialog(BuildContext context) {
  return showModalBottomSheet<StreetHailParams>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StreetHailSheet(),
  );
}

class _StreetHailSheet extends StatefulWidget {
  const _StreetHailSheet();

  @override
  State<_StreetHailSheet> createState() => _StreetHailSheetState();
}

class _StreetHailSheetState extends State<_StreetHailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  String _vehicleType = 'sedan';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(StreetHailParams(
        passengerPhone: _phoneCtrl.text.trim(),
        vehicleType: _vehicleType,
        destination:
            _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hail,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رحلة شارع',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700)),
                    Text('التقاط راكب بدون حجز مسبق',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Phone number
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'رقم هاتف الراكب *',
                hintText: '09XXXXXXXX',
                prefixIcon: const Icon(Icons.phone),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'أدخل رقم هاتف الراكب';
                }
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 9) return 'رقم غير صالح';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Vehicle type
            Text('نوع السيارة',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _VehicleTypeSelector(
              selected: _vehicleType,
              onChanged: (vt) => setState(() => _vehicleType = vt),
            ),
            const SizedBox(height: 14),

            // Destination (optional)
            TextFormField(
              controller: _destCtrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                labelText: 'الوجهة (اختياري)',
                hintText: 'مثال: ميركاتو، المطار...',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('بدء الرحلة',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vehicle type selector ─────────────────────────────────────────────────────

class _VehicleTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _VehicleTypeSelector(
      {required this.selected, required this.onChanged});

  static const _types = [
    ('sedan',   'سيدان',     Icons.directions_car),
    ('suv',     'SUV',       Icons.directions_car_filled),
    ('vip',     'VIP',       Icons.star_rounded),
    ('minibus', 'ميني باص',  Icons.airport_shuttle),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _types.map((t) {
        final (vt, label, icon) = t;
        final isSelected = vt == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(vt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      color: isSelected ? AppColors.primary : Colors.grey,
                      size: 22),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected ? AppColors.primary : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
