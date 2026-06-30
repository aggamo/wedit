import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'ብር ',
    decimalDigits: 0,
    locale: 'en_US',
  );

  static final NumberFormat _compactFormat = NumberFormat.compact();

  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatCompactCurrency(double amount) {
    return 'ብር ${_compactFormat.format(amount)}';
  }

  static String formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatDateAr(DateTime date) {
    return DateFormat('d MMM yyyy', 'ar').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }

  static String maskName(String fullName) {
    if (fullName.isEmpty) return '';
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) {
      return '${parts[0][0].toUpperCase()}***';
    }
    return '${parts[0]} ${parts[1][0].toUpperCase()}.';
  }

  static String maskPlate(String plate) {
    if (plate.length <= 3) return plate;
    return '***${plate.substring(plate.length - 2)}';
  }

  static String maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 4)}****${phone.substring(phone.length - 2)}';
  }

  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  static String formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '$m:${s.toString().padLeft(2, '0')}';
    return '${s}s';
  }

  static String formatPhoneForDisplay(String phone) {
    if (phone.startsWith('+251') && phone.length == 13) {
      return '+251 ${phone.substring(4, 6)} ${phone.substring(6, 9)} ${phone.substring(9)}';
    }
    return phone;
  }

  static String normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '+251${cleaned.substring(1)}';
    } else if (cleaned.startsWith('9') || cleaned.startsWith('7')) {
      cleaned = '+251$cleaned';
    }
    return cleaned;
  }

  static String formatSubscriptionPeriod(String plan) {
    switch (plan) {
      case 'daily':
        return '1 Day';
      case 'weekly':
        return '7 Days';
      case 'monthly':
        return '30 Days';
      default:
        return plan;
    }
  }

  static String formatPeriodEndTime(DateTime endTime) {
    final now = DateTime.now();
    final diff = endTime.difference(now);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours % 24}h';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    }
    return 'Expired';
  }
}
