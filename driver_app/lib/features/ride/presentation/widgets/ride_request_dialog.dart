import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ride_request_entity.dart';

/// Shows the incoming ride request dialog.
/// Returns [double] (offered price) when driver accepts, or [null] when declined/timed out.
Future<double?> showRideRequestDialog(
    BuildContext context, RideRequestEntity request) {
  return showModalBottomSheet<double>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RideRequestSheet(request: request),
  );
}

class _RideRequestSheet extends StatefulWidget {
  final RideRequestEntity request;

  const _RideRequestSheet({required this.request});

  @override
  State<_RideRequestSheet> createState() => _RideRequestSheetState();
}

class _RideRequestSheetState extends State<_RideRequestSheet>
    with TickerProviderStateMixin {
  late AnimationController _countdownController;
  late TextEditingController _priceController;
  late int _secondsRemaining;
  Timer? _timer;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.request.secondsRemaining.clamp(1, 30);
    _priceController = TextEditingController(
      text: widget.request.estimatedPrice.toStringAsFixed(0),
    );

    _countdownController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secondsRemaining),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) Navigator.of(context).pop(null);
      } else {
        if (mounted) setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _accept() {
    if (_formKey.currentState?.validate() ?? false) {
      _timer?.cancel();
      final price = double.tryParse(_priceController.text.trim()) ??
          widget.request.estimatedPrice;
      Navigator.of(context).pop(price);
    }
  }

  void _decline() {
    _timer?.cancel();
    Navigator.of(context).pop(null);
  }

  String _buildStars(double rating) {
    final full = rating.floor();
    final half = (rating - full) >= 0.5;
    final empty = 5 - full - (half ? 1 : 0);
    return ('★' * full) + (half ? '½' : '') + ('☆' * empty);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _secondsRemaining / 30.0;

    return GestureDetector(
      onTap: () {}, // prevent dismiss on tap outside sheet content
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 16),

              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car,
                        color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'طلب رحلة جديد!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Countdown timer
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _secondsRemaining > 10
                              ? AppTheme.onlineColor
                              : Colors.orange,
                        ),
                      ),
                    ),
                    Text(
                      '$_secondsRemaining',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _secondsRemaining > 10
                            ? Colors.black87
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Passenger rating
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.person,
                              color: colorScheme.onPrimaryContainer,
                              size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.request.passengerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _buildStars(
                                      widget.request.passengerRating),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${widget.request.passengerRating.toStringAsFixed(1)})',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Pickup
                    _AddressRow(
                      icon: Icons.my_location,
                      iconColor: AppTheme.onlineColor,
                      label: 'نقطة الانطلاق',
                      address: widget.request.pickupAddress,
                    ),

                    const SizedBox(height: 8),

                    // Destination
                    _AddressRow(
                      icon: Icons.location_on,
                      iconColor: AppTheme.primaryColor,
                      label: 'الوجهة',
                      address: widget.request.dropoffAddress,
                    ),

                    const SizedBox(height: 14),

                    // Info chips
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.near_me,
                          text:
                              '${widget.request.distanceKm.toStringAsFixed(1)} كم منك',
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.route,
                          text:
                              '${(widget.request.distanceKm * 1.2).toStringAsFixed(1)} كم الرحلة',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Suggested price
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'السعر المقترح:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${widget.request.estimatedPrice.toStringAsFixed(0)} ب',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Price input
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]')),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'سعرك (ب)',
                        suffixText: 'بر',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'أدخل السعر';
                        }
                        final p = double.tryParse(v);
                        if (p == null || p <= 0) {
                          return 'سعر غير صالح';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            onPressed: _decline,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('رفض'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _accept,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text('قبول وإرسال عرض'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.onlineColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                address.isEmpty ? 'غير محدد' : address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
