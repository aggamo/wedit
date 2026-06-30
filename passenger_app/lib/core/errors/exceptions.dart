class ServerException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const ServerException({
    required this.message,
    this.code,
    this.statusCode,
  });

  @override
  String toString() =>
      'ServerException(message: $message, code: $code, statusCode: $statusCode)';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException({
    this.message = 'No internet connection. Please check your network.',
  });

  @override
  String toString() => 'NetworkException(message: $message)';
}

class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'AuthException(message: $message, code: $code)';
}

class LocationException implements Exception {
  final String message;
  final String? code;

  const LocationException({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'LocationException(message: $message, code: $code)';
}

class PaymentException implements Exception {
  final String message;
  final String? code;

  const PaymentException({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'PaymentException(message: $message, code: $code)';
}

class CacheException implements Exception {
  final String message;

  const CacheException({required this.message});

  @override
  String toString() => 'CacheException(message: $message)';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, String>? fieldErrors;

  const ValidationException({required this.message, this.fieldErrors});

  @override
  String toString() => 'ValidationException(message: $message)';
}

class NotFoundException implements Exception {
  final String message;

  const NotFoundException({required this.message});

  @override
  String toString() => 'NotFoundException(message: $message)';
}

class PermissionException implements Exception {
  final String message;

  const PermissionException({required this.message});

  @override
  String toString() => 'PermissionException(message: $message)';
}
