import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/printer_profile.dart';
import 'package:admin_app/utils/printer_validators.dart';

PrinterProfile _profile(String id, String name) => PrinterProfile(
  id: id,
  name: name,
  transport: PrinterTransport.network,
  connectionParams: const {'ip': '192.168.1.50'},
);

void main() {
  group('host validation', () {
    test('accepts well formed IPv4 addresses', () {
      expect(PrinterValidators.isValidIpv4('192.168.1.100'), isTrue);
      expect(PrinterValidators.isValidIpv4('0.0.0.0'), isTrue);
      expect(PrinterValidators.isValidIpv4('255.255.255.255'), isTrue);
    });

    test('rejects out of range and malformed IPv4 addresses', () {
      expect(PrinterValidators.isValidIpv4('192.168.1.256'), isFalse);
      expect(PrinterValidators.isValidIpv4('192.168.1'), isFalse);
      expect(PrinterValidators.isValidIpv4('192.168.1.1.1'), isFalse);
      expect(PrinterValidators.isValidIpv4(''), isFalse);
    });

    test('accepts host names as well as addresses', () {
      expect(PrinterValidators.isValidHost('printer-kitchen'), isTrue);
      expect(PrinterValidators.isValidHost('pos.local'), isTrue);
      expect(PrinterValidators.isValidHost(' 10.0.0.8 '), isTrue);
    });

    test('rejects malformed hosts', () {
      expect(PrinterValidators.isValidHost(''), isFalse);
      expect(PrinterValidators.isValidHost('   '), isFalse);
      expect(PrinterValidators.isValidHost('-bad-start'), isFalse);
      expect(PrinterValidators.isValidHost('has space'), isFalse);
      // A dotted quad with a bad octet is a broken address, not a host name.
      expect(PrinterValidators.isValidHost('10.0.0.999'), isFalse);
    });
  });

  group('port validation', () {
    test('accepts ports inside the usable range', () {
      expect(PrinterValidators.isValidPort('9100'), isTrue);
      expect(PrinterValidators.isValidPort('1'), isTrue);
      expect(PrinterValidators.isValidPort('65535'), isTrue);
    });

    test('rejects zero, overflow and non numeric ports', () {
      expect(PrinterValidators.isValidPort('0'), isFalse);
      expect(PrinterValidators.isValidPort('65536'), isFalse);
      expect(PrinterValidators.isValidPort('-1'), isFalse);
      expect(PrinterValidators.isValidPort('91oo'), isFalse);
      expect(PrinterValidators.isValidPort(''), isFalse);
    });
  });

  group('MAC validation', () {
    test('accepts colon and dash separated addresses', () {
      expect(PrinterValidators.isValidMacAddress('00:11:22:33:44:55'), isTrue);
      expect(PrinterValidators.isValidMacAddress('aa-bb-cc-dd-ee-ff'), isTrue);
    });

    test('rejects malformed addresses', () {
      expect(PrinterValidators.isValidMacAddress('00:11:22:33:44'), isFalse);
      expect(PrinterValidators.isValidMacAddress('001122334455'), isFalse);
      expect(PrinterValidators.isValidMacAddress('zz:11:22:33:44:55'), isFalse);
    });

    test('normalizes to uppercase colon form', () {
      expect(
        PrinterValidators.normalizeMacAddress('aa-bb-cc-dd-ee-ff'),
        'AA:BB:CC:DD:EE:FF',
      );
      expect(PrinterValidators.normalizeMacAddress('not-a-mac'), isNull);
    });
  });

  group('name availability', () {
    final existing = [_profile('a', 'Kitchen'), _profile('b', 'Counter')];

    test('rejects a name already used by another profile', () {
      expect(PrinterValidators.isNameAvailable('Kitchen', existing), isFalse);
      // Comparison ignores case and surrounding whitespace.
      expect(PrinterValidators.isNameAvailable(' kitchen ', existing), isFalse);
    });

    test('lets a profile keep its own name while editing', () {
      expect(
        PrinterValidators.isNameAvailable(
          'Kitchen',
          existing,
          currentId: 'a',
        ),
        isTrue,
      );
    });

    test('rejects empty names and accepts unused ones', () {
      expect(PrinterValidators.isNameAvailable('   ', existing), isFalse);
      expect(PrinterValidators.isNameAvailable('Bar', existing), isTrue);
    });
  });
}
