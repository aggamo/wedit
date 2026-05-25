import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  /// Formats a price amount as Ethiopian Birr
  /// e.g., 150.0 → "150 ብር" or "150 ETB"
  static String formatPrice(double amount, {bool useAmharic = false}) {
    final formatted = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return useAmharic ? '$formatted ብር' : '$formatted ETB';
  }

  /// Formats price with locale currency symbol
  static String formatPriceFull(double amount) {
    final formatter = NumberFormat('#,##0.##', 'en');
    return '${formatter.format(amount)} ETB';
  }

  /// Formats a distance in km
  /// e.g., 2.5 → "2.5 km", 0.3 → "300 m"
  static String formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).toInt();
      return '$meters m';
    }
    if (km % 1 == 0) {
      return '${km.toInt()} km';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Masks a license plate showing only the last N digits
  /// e.g., "AA12345", 3 → "**345"
  static String maskPlate(String plate, int digitsToShow) {
    if (plate.length <= digitsToShow) return plate;
    final masked = '*' * (plate.length - digitsToShow);
    final visible = plate.substring(plate.length - digitsToShow);
    return masked + visible;
  }

  /// Formats a rating with star symbol
  /// e.g., 4.8 → "4.8 ★"
  static String formatRating(double rating) {
    if (rating == rating.toInt()) {
      return '${rating.toInt()} ★';
    }
    return '${rating.toStringAsFixed(1)} ★';
  }

  /// Abbreviates a full name
  /// e.g., "Ahmed Mohammed Ali" → "Ahmed M."
  static String abbreviateName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return fullName;
    if (parts.length == 1) return parts[0];
    final firstName = parts[0];
    final lastInitial = '${parts[1][0].toUpperCase()}.';
    return '$firstName $lastInitial';
  }

  /// Formats a countdown duration
  /// e.g., Duration(days: 3, hours: 5, minutes: 12) → "3d 5h 12m"
  static String formatCountdown(Duration duration) {
    if (duration.isNegative) return '0m';
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Formats seconds as MM:SS
  static String formatSecondsAsTimer(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Formats a DateTime for ride history display
  static String formatRideDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    }
    if (diff.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    }
    if (diff.inDays < 7) {
      return DateFormat('EEEE HH:mm').format(date);
    }
    return DateFormat('MMM d, y').format(date);
  }

  /// Formats duration of a ride
  /// e.g., 75 minutes → "1h 15m"
  static String formatRideDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Formats ETA in minutes
  /// e.g., 5 → "5 min"
  static String formatEta(int minutes) {
    if (minutes < 1) return '< 1 min';
    return '$minutes min';
  }

  /// Formats points balance
  static String formatPoints(int points) {
    if (points >= 1000) {
      return '${(points / 1000).toStringAsFixed(1)}k pts';
    }
    return '$points pts';
  }
}
