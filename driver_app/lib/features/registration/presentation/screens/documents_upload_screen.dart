import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Standalone documents upload screen (for navigation purposes)
// Main upload is integrated in DriverRegistrationScreen step 3
class DocumentsUploadScreen extends StatelessWidget {
  const DocumentsUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رفع المستندات')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.upload_file_rounded, size: 64, color: Colors.grey),
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
