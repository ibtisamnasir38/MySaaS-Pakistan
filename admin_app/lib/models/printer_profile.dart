import 'dart:convert';

enum PrinterTransport { network, bluetooth, ble, windows, serial, pdf }

/// A capability profile shipped with `esc_pos_utils_plus`.
class PrinterCapabilityProfile {
  final String key;
  final String vendor;
  final String label;

  const PrinterCapabilityProfile({
    required this.key,
    this.vendor = '',
    String? label,
  }) : label = label ?? key;

  String get displayName => vendor.isEmpty ? label : '$vendor — $label';
}

class PrinterProfile {
  /// Fallback list used when the capability catalogue cannot be read from the
  /// bundled `esc_pos_utils_plus` asset (tests, restricted platforms).
  static const List<PrinterCapabilityProfile> fallbackCapabilityProfiles = [
    PrinterCapabilityProfile(key: 'default', label: 'Default'),
    PrinterCapabilityProfile(key: 'simple', label: 'Simple'),
    PrinterCapabilityProfile(key: 'XP-N160I', vendor: 'Xprinter'),
    PrinterCapabilityProfile(key: 'RP80USE', vendor: 'Rongta'),
  ];

  /// Capability profiles addressable through the legacy integer `profileId`.
  static const List<String> legacyCapabilityProfileNames = [
    'default',
    'XP-N160I',
    'RP80USE',
  ];

  static const List<int> supportedBaudRates = [
    9600,
    19200,
    38400,
    57600,
    115200,
  ];

  static const int maxCopies = 5;
  static const int maxFeedLines = 10;
  static const int defaultFeedLines = 3;

  final String id;
  final String name;
  final PrinterTransport transport;
  final Map<String, dynamic> connectionParams;
  final Map<String, dynamic> capabilityParams;

  PrinterProfile({
    required this.id,
    required this.name,
    required this.transport,
    required this.connectionParams,
    this.capabilityParams = const {},
  });

  // Connection Params Helpers
  String? get ip => connectionParams['ip'] as String?;
  int? get port => _asInt(connectionParams['port']);
  String? get macAddress =>
      connectionParams['macAddress'] as String?; // For BT Classic / BLE
  String? get deviceId =>
      connectionParams['deviceId'] as String?; // For BLE / USB / Windows
  String? get serviceUuid => connectionParams['serviceUuid'] as String?; // BLE
  String? get characteristicUuid =>
      connectionParams['characteristicUuid'] as String?; // For BLE
  String? get printerName =>
      connectionParams['printerName'] as String?; // For Windows Spooler
  String? get portName =>
      connectionParams['portName'] as String?; // Serial (COM1, /dev/ttyUSB0)
  int? get baudRate => _asInt(connectionParams['baudRate']); // For Serial

  // Capability Params Helpers
  int get paperWidth =>
      _asInt(capabilityParams['paperWidth']) == 58 ? 58 : 80; // 58 or 80 mm
  bool get cut => _asBool(capabilityParams['cut']) ?? true;
  bool get drawer => _asBool(capabilityParams['drawer']) ?? false;

  /// Legacy numeric handle for a capability profile. Kept for profiles saved
  /// before [capabilityProfileName] existed.
  int get profileId => _asInt(capabilityParams['profileId']) ?? 0;

  bool get forceImagePrint =>
      _asBool(capabilityParams['forceImagePrint']) ?? false;

  /// Number of identical receipts sent per print job.
  int get copies => _clamp(_asInt(capabilityParams['copies']) ?? 1, 1, maxCopies);

  /// Blank lines fed after the receipt body, before cutting.
  int get feedLines => _clamp(
    _asInt(capabilityParams['feedLines']) ?? defaultFeedLines,
    0,
    maxFeedLines,
  );

  /// Name of the `esc_pos_utils_plus` capability profile to build with.
  ///
  /// Prefers the stored profile key and falls back to the legacy integer id so
  /// profiles saved by older builds keep printing the same way.
  String get capabilityProfileName {
    final stored = capabilityParams['capabilityProfile'];
    if (stored is String && stored.trim().isNotEmpty) return stored.trim();

    final legacy = profileId;
    if (legacy >= 0 && legacy < legacyCapabilityProfileNames.length) {
      return legacyCapabilityProfileNames[legacy];
    }
    return 'default';
  }

  static int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  static PrinterTransport _transportFrom(dynamic value) {
    final index = _asInt(value);
    if (index != null && index >= 0 && index < PrinterTransport.values.length) {
      return PrinterTransport.values[index];
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      for (final transport in PrinterTransport.values) {
        if (transport.name == normalized) return transport;
      }
    }
    return PrinterTransport.network;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'transport': transport.index,
      'connectionParams': connectionParams,
      'capabilityParams': capabilityParams,
    };
  }

  factory PrinterProfile.fromMap(Map<String, dynamic> map) {
    return PrinterProfile(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      transport: _transportFrom(map['transport']),
      connectionParams: Map<String, dynamic>.from(
        map['connectionParams'] ?? {},
      ),
      capabilityParams: Map<String, dynamic>.from(
        map['capabilityParams'] ?? {},
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory PrinterProfile.fromJson(String source) =>
      PrinterProfile.fromMap(json.decode(source));

  PrinterProfile copyWith({
    String? id,
    String? name,
    PrinterTransport? transport,
    Map<String, dynamic>? connectionParams,
    Map<String, dynamic>? capabilityParams,
  }) {
    return PrinterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      transport: transport ?? this.transport,
      connectionParams: connectionParams ?? this.connectionParams,
      capabilityParams: capabilityParams ?? this.capabilityParams,
    );
  }

  /// Returns a copy with [updates] merged over the existing capability params,
  /// so keys this build does not know about survive an edit.
  PrinterProfile withCapabilities(Map<String, dynamic> updates) {
    return copyWith(capabilityParams: {...capabilityParams, ...updates});
  }
}
