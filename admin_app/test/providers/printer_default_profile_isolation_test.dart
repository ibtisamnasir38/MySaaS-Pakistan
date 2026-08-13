import 'package:admin_app/bootstrap.dart';
import 'package:admin_app/models/app_mode.dart';
import 'package:admin_app/models/bootstrap_config.dart';
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

/// Lives in its own file so the workspace below is the only one this test
/// process ever binds to — swapping tenants inside a single process tears the
/// shared database down under the sync service.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.databasesPathProvider = () async => inMemoryDatabasePath;
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
          if (methodCall.method == 'check') return ['none'];
          return null;
        });
  });

  test('another workspace default is never adopted', () async {
    // The device previously ran as tenant-a and picked a printer there.
    SharedPreferences.setMockInitialValues({
      _defaultKeyFor('tenant-a'): 'printer-owned-by-tenant-a',
    });
    await DatabaseService().resetForTest();

    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(
          () => BootstrapNotifier(
            BootstrapConfig(
              apiBaseUrl: 'http://localhost',
              mode: AppMode.online,
              tenantId: 'tenant-b',
            ),
          ),
        ),
      ],
    );
    container.read(authProvider);

    await container.read(printerProfilesProvider.notifier).loadProfiles();

    expect(container.read(printerProfilesProvider).defaultProfile, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_defaultKeyFor('tenant-b')), isNull);
    // Tenant A's choice is left untouched, not consumed by tenant B.
    expect(
      prefs.getString(_defaultKeyFor('tenant-a')),
      'printer-owned-by-tenant-a',
    );

    container.dispose();
  });
}
