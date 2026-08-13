import '../models/printer_profile.dart';

/// Pure validation helpers for printer connection settings.
///
/// Kept free of Flutter and localization imports so they can be unit tested
/// and reused by any layer that needs to check a printer configuration.
class PrinterValidators {
  const PrinterValidators._();

  static const int minPort = 1;
  static const int maxPort = 65535;

  static final RegExp _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
  static final RegExp _hostname = RegExp(
    r'^[A-Za-z0-9]([A-Za-z0-9\-]{0,61}[A-Za-z0-9])?'
    r'(\.[A-Za-z0-9]([A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)*$',
  );
  static final RegExp _mac = RegExp(r'^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$');

  /// True for a dotted-quad IPv4 address with every octet in 0..255.
  static bool isValidIpv4(String value) {
    final match = _ipv4.firstMatch(value.trim());
    if (match == null) return false;

    for (var group = 1; group <= 4; group++) {
      final octet = int.tryParse(match.group(group)!);
      if (octet == null || octet > 255) return false;
    }
    return true;
  }

  /// True for an IPv4 address or a DNS host name. Network printers on a LAN
  /// are usually addressed by IP, but a hostname is equally valid.
  static bool isValidHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 253) return false;
    if (isValidIpv4(trimmed)) return true;
    // A dotted-quad shape that failed the IPv4 check is a malformed address,
    // not a hostname.
    if (_ipv4.hasMatch(trimmed)) return false;
    return _hostname.hasMatch(trimmed);
  }

  /// True for a TCP port inside the usable range.
  static bool isValidPort(String value) {
    final port = int.tryParse(value.trim());
    if (port == null) return false;
    return port >= minPort && port <= maxPort;
  }

  /// True for a six-group MAC address separated by `:` or `-`.
  static bool isValidMacAddress(String value) => _mac.hasMatch(value.trim());

  /// Uppercases and colon-separates a MAC address, or returns null when the
  /// input is not a MAC address.
  static String? normalizeMacAddress(String value) {
    final trimmed = value.trim();
    if (!isValidMacAddress(trimmed)) return null;
    return trimmed.toUpperCase().replaceAll('-', ':');
  }

  /// True when [name] is not already used by another profile.
  ///
  /// [currentId] is the profile being edited, which is allowed to keep its
  /// own name.
  static bool isNameAvailable(
    String name,
    List<PrinterProfile> existing, {
    String? currentId,
  }) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    return !existing.any(
      (profile) =>
          profile.id != currentId &&
          profile.name.trim().toLowerCase() == normalized,
    );
  }
}
