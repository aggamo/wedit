import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Standalone vehicle info screen (for navigation purposes)
class VehicleInfoScreen extends StatelessWidget {
  const VehicleInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معلومات المركبة')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('يرجى المتابعة من شاشة التسجيل'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/registration'),
              child: const Text('العودة للتسجيل'),
            ),
          ],
        ),
      ),
    );
  }
}
