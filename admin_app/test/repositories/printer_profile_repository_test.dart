import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/printer_profile.dart';
import 'package:admin_app/repositories/printer_profile_repository.dart';
import 'package:admin_app/services/database_service.dart';
import 'package:admin_app/services/tenant_mode_service.dart';
import 'package:admin_app/models/app_mode.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:admin_app/services/api_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.databasesPathProvider = () async => inMemoryDatabasePath;
    DatabaseService.databaseOpener = (path,
            {version,
            onConfigure,
            onCreate,
            onDowngrade,
            onOpen,
            onUpgrade,
            password,
            readOnly = false,
            singleInstance = true}) =>
        databaseFactory.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: version,
            onConfigure: onConfigure,
            onCreate: onCreate,
            onDowngrade: onDowngrade,
            onOpen: onOpen,
            onUpgrade: onUpgrade,
            singleInstance: false,
          ),
        );
    TenantModeService().initialize(mode: AppMode.online, tenantId: 'test-tenant');
  });

  setUp(() async {
    await DatabaseService().resetForTest();
  });

  PrinterProfile buildProfile({String name = 'Test Printer'}) {
    return PrinterProfile(
      id: '',
      name: name,
      transport: PrinterTransport.network,
      connectionParams: {'ip': '192.168.1.100', 'port': 9100},
      capabilityParams: {'paperWidth': 80, 'cut': true},
    );
  }

  test('create and load printer profile', () async {
    final repo = PrinterProfileRepository(ApiService());

    final created = await repo.createProfile(buildProfile());
    expect(created.id, isNotEmpty);
    expect(created.name, 'Test Printer');

    final profiles = await repo.getProfiles();
    expect(profiles.length, 1);
    expect(profiles.first.id, created.id);
    expect(profiles.first.name, 'Test Printer');
    expect(profiles.first.connectionParams['ip'], '192.168.1.100');
  });

  test('deleted printer does not come back on the next load', () async {
    final repo = PrinterProfileRepository(ApiService());

    final created = await repo.createProfile(buildProfile(name: 'Kitchen'));
    expect((await repo.getProfiles()).length, 1);

    await repo.deleteProfile(created.id);

    // The local row must be gone, not just flagged, otherwise reopening
    // settings while offline resurrects the printer.
    expect(await repo.getProfiles(), isEmpty);
  });

  test('capability settings survive an update', () async {
    final repo = PrinterProfileRepository(ApiService());

    final created = await repo.createProfile(buildProfile(name: 'Counter'));
    await repo.updateProfile(
      created.withCapabilities({
        'paperWidth': 58,
        'copies': 2,
        'capabilityProfile': 'XP-N160I',
      }),
    );

    final stored = (await repo.getProfiles()).single;
    expect(stored.paperWidth, 58);
    expect(stored.copies, 2);
    expect(stored.capabilityProfileName, 'XP-N160I');
    // Untouched keys are still there.
    expect(stored.cut, isTrue);
  });
}
