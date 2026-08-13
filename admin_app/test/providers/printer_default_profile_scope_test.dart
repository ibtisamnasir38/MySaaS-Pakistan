import 'package:admin_app/bootstrap.dart';
import 'package:admin_app/models/app_mode.dart';
import 'package:admin_app/models/bootstrap_config.dart';
import 'package:admin_app/models/printer_profile.dart';
import 'package:admin_app/models/workspace_binding.dart';
import 'package:admin_app/providers/auth_provider.dart';
import 'package:admin_app/providers/printer_profiles_provider.dart';
import 'package:admin_app/services/database_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String _defaultKeyFor(String tenantId) =>
    'default_printer_profile_id::'
    '${WorkspaceBinding(tenantId: tenantId).namespaceKey}';

BootstrapConfig _bootstrapFor(String tenantId) => BootstrapConfig(
  apiBaseUrl: 'http://localhost',
  mode: AppMode.online,
  tenantId: tenantId,
);

void main() {
  // Plain `test` bodies, not `testWidgets`: the sqflite ffi database does real
  // asynchronous I/O, which never completes under the widget tester's fake
  // clock.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.databasesPathProvider = () async => inMemoryDatabasePath;
    // Route every open through the ffi factory: the real sqlcipher plugin is
    // not available under `flutter test`.
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
          // Keep the repository on its local path: this suite is about the
          // stored preference, not about talking to the backend.
          if (methodCall.method == 'check') return ['none'];
          return null;
        });
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService().resetForTest();
  });

  PrinterProfile buildProfile(String name) => PrinterProfile(
    id: '',
    name: name,
    transport: PrinterTransport.network,
    connectionParams: const {'ip': '192.168.1.100', 'port': 9100},
  );

  ProviderContainer containerFor(String tenantId) {
    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(
          () => BootstrapNotifier(_bootstrapFor(tenantId)),
        ),
      ],
    );
    // Reading auth binds TenantModeService to this tenant workspace.
    container.read(authProvider);
    return container;
  }

  test('the default printer is stored per tenant workspace', () async {
    final containerA = containerFor('tenant-a');

    final created = await containerA
        .read(printerProfilesProvider.notifier)
        .addProfile(buildProfile('Kitchen'));

    expect(
      containerA.read(printerProfilesProvider).defaultProfile?.id,
      created.id,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_defaultKeyFor('tenant-a')), created.id);
    // The old global key must not be used any more: it would leak one
    // tenant's printer choice into another workspace on the same device.
    expect(prefs.getString('default_printer_profile_id'), isNull);
    expect(prefs.getString(_defaultKeyFor('tenant-b')), isNull);

    containerA.dispose();
  });

  test('a pre-namespacing default is migrated to the scoped key', () async {
    final container = containerFor('tenant-a');

    final created = await container
        .read(printerProfilesProvider.notifier)
        .addProfile(buildProfile('Counter'));

    // Simulate a device upgraded from a build that stored the default
    // globally.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_defaultKeyFor('tenant-a'));
    await prefs.setString('default_printer_profile_id', created.id);

    await container.read(printerProfilesProvider.notifier).loadProfiles();

    expect(
      container.read(printerProfilesProvider).defaultProfile?.id,
      created.id,
    );
    expect(prefs.getString(_defaultKeyFor('tenant-a')), created.id);
    expect(prefs.getString('default_printer_profile_id'), isNull);

    container.dispose();
  });

  test('removing the default printer promotes the next one', () async {
    final container = containerFor('tenant-a');
    final notifier = container.read(printerProfilesProvider.notifier);

    final first = await notifier.addProfile(buildProfile('Kitchen'));
    final second = await notifier.addProfile(buildProfile('Counter'));
    expect(container.read(printerProfilesProvider).defaultProfile?.id, first.id);

    await notifier.removeProfile(first.id);

    final state = container.read(printerProfilesProvider);
    expect(state.profiles.map((p) => p.id), [second.id]);
    expect(state.defaultProfile?.id, second.id);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_defaultKeyFor('tenant-a')), second.id);

    container.dispose();
  });

  test('removing the last printer clears the stored default', () async {
    final container = containerFor('tenant-a');
    final notifier = container.read(printerProfilesProvider.notifier);

    final only = await notifier.addProfile(buildProfile('Kitchen'));
    await notifier.removeProfile(only.id);

    expect(container.read(printerProfilesProvider).defaultProfile, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_defaultKeyFor('tenant-a')), isNull);

    container.dispose();
  });
}
