/// Custom typed exceptions for UNEXA with friendly user-facing messages.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Authentication related errors (Google Sign-In, domain mismatch, cancelled, etc.)
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.originalError});

  factory AuthException.fromFirebase(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('network') || str.contains('socket')) {
      return const AuthException('No internet connection. Please check your network and try again.');
    } else if (str.contains('sign_in_canceled') || str.contains('cancelled')) {
      return const AuthException('Sign in was cancelled.');
    } else if (str.contains('user-disabled')) {
      return const AuthException('This account has been disabled. Please contact your institute administrator.');
    } else if (str.contains('invalid-credential')) {
      return const AuthException('Invalid credentials provided.');
    }
    return AuthException('Authentication error: ${error.toString()}');
  }

  factory AuthException.unauthorizedDomain(String userDomain, List<String> allowedDomains) {
    return AuthException(
      'Your email domain (@$userDomain) is not recognized by this institute. '
      'Please sign in with your official institute Google account (${allowedDomains.map((d) => "@$d").join(", ")}).',
    );
  }
}

/// Account status exceptions (banned, suspended, pending)
class AccountStatusException extends AppException {
  final String status;
  final String? banReason;
  final String? bannedByRole;

  const AccountStatusException({
    required this.status,
    required String message,
    this.banReason,
    this.bannedByRole,
  }) : super(message);
}

/// Authorization & role violation exceptions
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([super.message = 'You do not have permission to perform this action.']);
}

/// Entity not found exceptions
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Validation errors
class ValidationException extends AppException {
  const ValidationException(super.message);
}
