import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ride_request_entity.dart';

/// Result returned when the driver acts on an incoming ride request.
class RideOfferResult {
  final double price;
  final bool isSystemPrice;
  final bool isSurgeOffer;

  const RideOfferResult({
    required this.price,
    required this.isSystemPrice,
    this.isSurgeOffer = false,
  });
}

/// Shows the incoming ride request dialog.
/// Returns [RideOfferResult] when driver offers/accepts, or [null] on decline/timeout.
Future<RideOfferResult?> showRideRequestDialog(
    BuildContext context, RideRequestEntity request,
    {bool surgeEnabled = false}) {
  return showModalBottomSheet<RideOfferResult>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _RideRequestSheet(request: request, surgeEnabled: surgeEnabled),
  );
}

enum _OfferMode { none, custom }

class _RideRequestSheet extends StatefulWidget {
  final RideRequestEntity request;
  final bool surgeEnabled;

  const _RideRequestSheet({required this.request, this.surgeEnabled = false});

  @override
  State<_RideRequestSheet> createState() => _RideRequestSheetState();
}

class _RideRequestSheetState extends State<_RideRequestSheet>
    with TickerProviderStateMixin {
  late AnimationController _countdownController;
  late TextEditingController _priceController;
  late int _secondsRemaining;
  Timer? _timer;
  _OfferMode _mode = _OfferMode.none;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.request.secondsRemaining.clamp(1, 45);
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

  double get _surgeMultiplier => 1.5; // Matches admin-configured value

  double get _effectivePrice => widget.surgeEnabled
      ? widget.request.estimatedPrice * _surgeMultiplier
      : widget.request.estimatedPrice;

  void _acceptSystemPrice() {
    _timer?.cancel();
    Navigator.of(context).pop(RideOfferResult(
      price: _effectivePrice,
      isSystemPrice: true,
      isSurgeOffer: widget.surgeEnabled,
    ));
  }

  void _submitCustomPrice() {
    if (_formKey.currentState?.validate() ?? false) {
      _timer?.cancel();
      final price = double.tryParse(_priceController.text.trim()) ??
          widget.request.estimatedPrice;
      Navigator.of(context).pop(RideOfferResult(
        price: price,
        isSystemPrice: false,
        isSurgeOffer: false,
      ));
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
    final progress = _secondsRemaining / 45.0;

    return GestureDetector(
      onTap: () {},
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

              // Countdown + competitor count row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Competitors badge
                    if (widget.request.competitorCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.request.competitorCount} سائقين آخرين عرضوا',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Countdown circle
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 5,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _secondsRemaining > 15
                                  ? AppTheme.onlineColor
                                  : Colors.orange,
                            ),
                          ),
                        ),
                        Text(
                          '$_secondsRemaining',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _secondsRemaining > 15
                                ? Colors.black87
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Passenger info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.person,
                              color: colorScheme.onPrimaryContainer, size: 20),
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
                                  _buildStars(widget.request.passengerRating),
                                  style: const TextStyle(
                                      color: Colors.amber, fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${widget.request.passengerRating.toStringAsFixed(1)})',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    _AddressRow(
                      icon: Icons.my_location,
                      iconColor: AppTheme.onlineColor,
                      label: 'نقطة الانطلاق',
                      address: widget.request.pickupAddress,
                    ),

                    const SizedBox(height: 8),

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
                              '~${(widget.request.distanceKm * 1.2).toStringAsFixed(1)} كم الرحلة',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // System price box (prominent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: widget.surgeEnabled
                            ? Colors.orange.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.surgeEnabled
                              ? Colors.orange.shade300
                              : Colors.amber.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.surgeEnabled
                                    ? 'سعر الذروة 🔥:'
                                    : 'سعر النظام المقترح:',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (widget.surgeEnabled)
                                Text(
                                  'الأساسي: ${widget.request.estimatedPrice.toStringAsFixed(0)} ب × 1.5',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade600),
                                ),
                            ],
                          ),
                          Text(
                            '${_effectivePrice.toStringAsFixed(0)} ب',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: widget.surgeEnabled
                                  ? Colors.orange.shade700
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Primary CTA: Accept at system price
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _acceptSystemPrice,
                        icon: Icon(
                          widget.surgeEnabled ? Icons.local_fire_department : Icons.bolt,
                          size: 20,
                        ),
                        label: Text(
                          widget.surgeEnabled
                              ? 'قبول بسعر الذروة (أسرع قبول)'
                              : 'قبول بسعر النظام (أسرع قبول)',
                          style: const TextStyle(fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.surgeEnabled
                              ? Colors.orange
                              : AppTheme.onlineColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Secondary: offer different price
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _mode = _mode == _OfferMode.custom
                                ? _OfferMode.none
                                : _OfferMode.custom),
                        icon: Icon(
                          _mode == _OfferMode.custom
                              ? Icons.keyboard_arrow_up
                              : Icons.edit,
                          size: 18,
                        ),
                        label: Text(
                          _mode == _OfferMode.custom
                              ? 'إخفاء'
                              : 'عرض سعر مختلف',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    // Custom price input (expandable)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _mode == _OfferMode.custom
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _priceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
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
                                      labelText: 'سعرك (بر)',
                                      suffixText: 'بر',
                                      prefixIcon:
                                          const Icon(Icons.attach_money),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
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
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _submitCustomPrice,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                      child: const Text('إرسال العرض'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 10),

                    // Decline button (tertiary)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _decline,
                        icon:
                            const Icon(Icons.close, size: 16, color: Colors.red),
                        label: const Text('رفض الطلب',
                            style: TextStyle(color: Colors.red)),
                      ),
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
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(
                address.isEmpty ? 'غير محدد' : address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
