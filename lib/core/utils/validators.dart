/// Utility validators for UNEXA multi-tenant forms and domain matching.
class Validators {
  /// Extracts the domain from an email address (e.g. 'alice@example.edu' -> 'example.edu')
  static String? extractEmailDomain(String? email) {
    if (email == null || !email.contains('@')) return null;
    final parts = email.trim().toLowerCase().split('@');
    if (parts.length == 2 && parts[1].isNotEmpty) {
      return parts[1];
    }
    return null;
  }

  /// Verifies if a given email belongs to an allowed college domain list.
  /// Supports exact domain match (e.g. 'iitkalyani.ac.in') or subdomain matching.
  static bool isDomainAllowed(String email, List<String> allowedDomains) {
    if (allowedDomains.isEmpty) return true; // Open or unrestricted if not configured
    final emailDomain = extractEmailDomain(email);
    if (emailDomain == null) return false;

    for (final domain in allowedDomains) {
      final clean = domain.trim().toLowerCase().replaceAll('@', '');
      if (emailDomain == clean || emailDomain.endsWith('.$clean')) {
        return true;
      }
    }
    return false;
  }

  /// Non-empty required field check
  static String? requiredField(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates standard time format (e.g. "10:00 AM" or "02:30 PM")
  static String? timeFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Time is required';
    }
    final regex = RegExp(r'^(0?[1-9]|1[0-2]):[0-5][0-9]\s?(AM|PM)$', caseSensitive: false);
    if (!regex.hasMatch(value.trim())) {
      return 'Please use format like 10:00 AM';
    }
    return null;
  }
}
