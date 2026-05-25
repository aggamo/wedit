class AppValidators {
  AppValidators._();

  /// Validates Ethiopian phone numbers.
  /// Accepts formats: +251XXXXXXXXX, 251XXXXXXXXX, 09XXXXXXXX, 07XXXXXXXX
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');
    // Ethiopian mobile: +251 9X/7X or 09X/07X
    final ethiopianRegex = RegExp(
      r'^(\+251|251|0)(9[0-9]{8}|7[0-9]{8})$',
    );
    if (!ethiopianRegex.hasMatch(cleaned)) {
      return 'Please enter a valid Ethiopian phone number';
    }
    return null;
  }

  /// Normalize Ethiopian phone to +251XXXXXXXXX format
  static String normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.startsWith('+251')) return cleaned;
    if (cleaned.startsWith('251')) return '+$cleaned';
    if (cleaned.startsWith('0')) return '+251${cleaned.substring(1)}';
    return '+251$cleaned';
  }

  /// Validates full name (min 2 words, letters only)
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Name must be at least 3 characters';
    }
    if (trimmed.length > 60) {
      return 'Name is too long';
    }
    return null;
  }

  /// Validates that a required field is not empty
  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Validates a referral code format
  static String? validateReferralCode(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final regex = RegExp(r'^[A-Z0-9]{6,10}$');
    if (!regex.hasMatch(value.trim().toUpperCase())) {
      return 'Invalid referral code format';
    }
    return null;
  }

  /// Validates OTP (6 digits)
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Verification code is required';
    }
    if (value.trim().length != 6) {
      return 'Code must be 6 digits';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Code must contain only digits';
    }
    return null;
  }

  /// Validates a location name/address
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Location is required';
    }
    if (value.trim().length < 3) {
      return 'Please enter a more specific location';
    }
    return null;
  }

  /// Validates email (optional field)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates a comment/text is within bounds
  static String? validateComment(String? value, {int maxLength = 500}) {
    if (value == null) return null;
    if (value.length > maxLength) {
      return 'Comment is too long (max $maxLength characters)';
    }
    return null;
  }
}
