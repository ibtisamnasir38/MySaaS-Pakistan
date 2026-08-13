import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_app/models/printer_profile.dart';
import 'package:admin_app/providers/printer_profiles_provider.dart';
import 'package:admin_app/services/database_service.dart';
import 'package:admin_app/models/bootstrap_config.dart';
import 'package:admin_app/models/app_mode.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin_app/providers/auth_provider.dart';
import 'package:admin_app/bootstrap.dart';
import 'package:flutter/services.dart';

void main() {
  // Plain `test`, not `testWidgets`: the sqflite ffi database does real
  // asynchronous I/O, which never completes under the widget tester's fake
  // clock.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.databasesPathProvider = () async => inMemoryDatabasePath;
    // The real sqlcipher plugin is not available under `flutter test`, so
    // every open has to go through the ffi factory.
    DatabaseService.databaseOpener =
        (
          path, {
          version,
          onConfigure,
          onCreate,
          onDowngrade,
          onOpen,
          onUpgrade,
          password,
          readOnly = false,
          singleInstance = true,
        }) => databaseFactory.openDatabase(
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

    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'check') {
            return ['wifi'];
          }
          return null;
        });

    SharedPreferences.setMockInitialValues({});
  });

  test('printer profile persists across provider container restarts', () async {
    await DatabaseService().resetForTest();

    final bootstrap = BootstrapConfig(
      apiBaseUrl: 'http://localhost',
      mode: AppMode.online,
      tenantId: 'test-tenant',
    );

    // First container
    ProviderContainer container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(() => BootstrapNotifier(bootstrap)),
      ],
    );

    // AuthProvider initializes TenantModeService internally
    container.read(authProvider);

    // Add profile
    final profile = PrinterProfile(
      id: 'test-printer-1',
      name: 'Receipt Printer',
      transport: PrinterTransport.network,
      connectionParams: {'ip': '192.168.1.100', 'port': 9100},
      capabilityParams: {'paperWidth': 80},
    );

    await container.read(printerProfilesProvider.notifier).addProfile(profile);

    final state1 = container.read(printerProfilesProvider);
    expect(state1.profiles.length, 1);

    // Dispose container (simulating app restart)
    container.dispose();

    // Second container
    final container2 = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(() => BootstrapNotifier(bootstrap)),
      ],
    );

    // AuthProvider initializes TenantModeService
    container2.read(authProvider);

    // Load profiles (simulating opening settings page)
    await container2.read(printerProfilesProvider.notifier).loadProfiles();

    final state2 = container2.read(printerProfilesProvider);
    expect(state2.profiles.length, 1);

    container2.dispose();
  });
}
