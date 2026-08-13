import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/printer_profile.dart';

PrinterProfile _withCapabilities(Map<String, dynamic> capabilityParams) {
  return PrinterProfile(
    id: 'p1',
    name: 'Kitchen',
    transport: PrinterTransport.network,
    connectionParams: const {'ip': '192.168.1.100', 'port': 9100},
    capabilityParams: capabilityParams,
  );
}

void main() {
  group('capability defaults', () {
    test('falls back to sane values when nothing is stored', () {
      final profile = _withCapabilities(const {});

      expect(profile.paperWidth, 80);
      expect(profile.cut, isTrue);
      expect(profile.drawer, isFalse);
      expect(profile.forceImagePrint, isFalse);
      expect(profile.copies, 1);
      expect(profile.feedLines, PrinterProfile.defaultFeedLines);
      expect(profile.capabilityProfileName, 'default');
    });

    test('clamps copies and feed lines to the supported range', () {
      expect(_withCapabilities(const {'copies': 0}).copies, 1);
      expect(
        _withCapabilities(const {'copies': 99}).copies,
        PrinterProfile.maxCopies,
      );
      expect(_withCapabilities(const {'feedLines': -4}).feedLines, 0);
      expect(
        _withCapabilities(const {'feedLines': 50}).feedLines,
        PrinterProfile.maxFeedLines,
      );
    });

    test('only 58 narrows the paper, anything else stays 80mm', () {
      expect(_withCapabilities(const {'paperWidth': 58}).paperWidth, 58);
      expect(_withCapabilities(const {'paperWidth': 72}).paperWidth, 80);
    });
  });

  group('JSON tolerance', () {
    test('reads numbers and booleans sent as strings', () {
      final profile = PrinterProfile.fromMap({
        'id': 'p1',
        'name': 'Kitchen',
        'transport': 0,
        'connectionParams': {'ip': '10.0.0.5', 'port': '9100'},
        'capabilityParams': {
          'paperWidth': '58',
          'cut': 'false',
          'drawer': 'true',
          'copies': '2',
        },
      });

      expect(profile.port, 9100);
      expect(profile.paperWidth, 58);
      expect(profile.cut, isFalse);
      expect(profile.drawer, isTrue);
      expect(profile.copies, 2);
    });

    test('accepts a transport sent as a name and survives bad values', () {
      expect(
        PrinterProfile.fromMap({'transport': 'serial'}).transport,
        PrinterTransport.serial,
      );
      expect(
        PrinterProfile.fromMap({'transport': 99}).transport,
        PrinterTransport.network,
      );
      expect(
        PrinterProfile.fromMap({'transport': null}).transport,
        PrinterTransport.network,
      );
    });

    test('round trips through JSON', () {
      final profile = _withCapabilities(const {
        'paperWidth': 58,
        'copies': 2,
        'capabilityProfile': 'XP-N160I',
      });

      final restored = PrinterProfile.fromJson(profile.toJson());
      expect(restored.paperWidth, 58);
      expect(restored.copies, 2);
      expect(restored.capabilityProfileName, 'XP-N160I');
      expect(restored.transport, profile.transport);
    });
  });

  group('capability profile resolution', () {
    test('prefers the stored profile key', () {
      final profile = _withCapabilities(const {
        'capabilityProfile': 'RP80USE',
        'profileId': 1,
      });
      expect(profile.capabilityProfileName, 'RP80USE');
    });

    test('falls back to the legacy numeric id', () {
      expect(
        _withCapabilities(const {'profileId': 1}).capabilityProfileName,
        'XP-N160I',
      );
      expect(
        _withCapabilities(const {'profileId': 2}).capabilityProfileName,
        'RP80USE',
      );
      expect(
        _withCapabilities(const {'profileId': 7}).capabilityProfileName,
        'default',
      );
    });

    test('ignores a blank stored key', () {
      final profile = _withCapabilities(const {
        'capabilityProfile': '  ',
        'profileId': 2,
      });
      expect(profile.capabilityProfileName, 'RP80USE');
    });
  });

  test('withCapabilities keeps keys this build does not know about', () {
    final profile = _withCapabilities(const {
      'paperWidth': 80,
      'futureSetting': 'keep-me',
    });

    final updated = profile.withCapabilities({'paperWidth': 58, 'copies': 3});

    expect(updated.paperWidth, 58);
    expect(updated.copies, 3);
    expect(updated.capabilityParams['futureSetting'], 'keep-me');
    // The original profile is untouched.
    expect(profile.paperWidth, 80);
  });
}
