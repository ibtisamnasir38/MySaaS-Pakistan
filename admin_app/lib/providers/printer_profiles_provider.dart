import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_profile.dart';
import '../models/receipt_layout.dart';
import '../repositories/printer_profile_repository.dart';
import '../repositories/receipt_layout_repository.dart';
import '../services/api_service.dart';
import '../services/tenant_mode_service.dart';

class PrinterProfilesState {
  final List<PrinterProfile> profiles;
  final PrinterProfile? defaultProfile;
  final ReceiptLayout? receiptLayout;
  final bool isLoading;
  final String? errorMessage;

  PrinterProfilesState({
    this.profiles = const [],
    this.defaultProfile,
    this.receiptLayout,
    this.isLoading = false,
    this.errorMessage,
  });

  PrinterProfilesState copyWith({
    List<PrinterProfile>? profiles,
    PrinterProfile? defaultProfile,
    bool clearDefaultProfile = false,
    ReceiptLayout? receiptLayout,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PrinterProfilesState(
      profiles: profiles ?? this.profiles,
      defaultProfile: clearDefaultProfile
          ? null
          : (defaultProfile ?? this.defaultProfile),
      receiptLayout: receiptLayout ?? this.receiptLayout,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class PrinterProfilesNotifier extends Notifier<PrinterProfilesState> {
  /// Legacy, non tenant-scoped key. Only read once, to migrate.
  static const _legacyKeyDefaultProfileId = 'default_printer_profile_id';

  late final PrinterProfileRepository _printerRepo;
  late final ReceiptLayoutRepository _receiptRepo;

  /// The default printer is a per-device preference, but a device can be
  /// re-provisioned to another workspace, so the key is namespaced to keep
  /// one tenant's choice from leaking into another's.
  String get _keyDefaultProfileId =>
      'default_printer_profile_id::${TenantModeService().activeNamespaceKey}';

  @override
  PrinterProfilesState build() {
    final api = ref.watch(apiProvider);
    _printerRepo = PrinterProfileRepository(api);
    _receiptRepo = ReceiptLayoutRepository(api);

    // Start data fetch automatically when provider is used
    Future.microtask(() {
      if (ref.mounted) loadProfiles();
    });
    return PrinterProfilesState(isLoading: true);
  }

  /// Moves a pre-namespacing default onto the tenant-scoped key so upgrading
  /// users keep their selected printer.
  Future<String?> _readDefaultProfileId(SharedPreferences prefs) async {
    final scoped = prefs.getString(_keyDefaultProfileId);
    if (scoped != null) return scoped;

    final legacy = prefs.getString(_legacyKeyDefaultProfileId);
    if (legacy == null) return null;

    await prefs.setString(_keyDefaultProfileId, legacy);
    await prefs.remove(_legacyKeyDefaultProfileId);
    return legacy;
  }

  Future<void> loadProfiles({bool forceRefresh = false}) async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final profiles = await _printerRepo.getProfiles(
        forceRefresh: forceRefresh,
      );

      final prefs = await SharedPreferences.getInstance();
      final defaultProfileId = await _readDefaultProfileId(prefs);

      PrinterProfile? defaultProfile;
      if (defaultProfileId != null) {
        defaultProfile = profiles
            .where((p) => p.id == defaultProfileId)
            .firstOrNull;
        if (defaultProfile == null) {
          await prefs.remove(_keyDefaultProfileId);
        }
      }

      final layouts = await _receiptRepo.getLayouts(forceRefresh: forceRefresh);
      ReceiptLayout layout = layouts.isNotEmpty
          ? layouts.first
          : ReceiptLayout.standard();

      // The page may have been closed while the load was in flight.
      if (!ref.mounted) return;
      state = PrinterProfilesState(
        profiles: profiles,
        defaultProfile: defaultProfile,
        receiptLayout: layout,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading printer profiles: $e');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> saveLayout(ReceiptLayout layout) async {
    // Check if it exists, if standard and new, we might create it, else update
    final current = state.receiptLayout;
    if (current != null && current.id != 'standard') {
      final newLayout = layout.copyWith(id: current.id);
      await _receiptRepo.updateLayout(newLayout);
      if (!ref.mounted) return;
      state = state.copyWith(receiptLayout: newLayout);
    } else {
      final created = await _receiptRepo.createLayout(layout);
      if (!ref.mounted) return;
      state = state.copyWith(receiptLayout: created);
    }
  }

  Future<PrinterProfile> addProfile(PrinterProfile profile) async {
    final created = await _printerRepo.createProfile(profile);
    if (!ref.mounted) return created;

    // The initial load may have landed while the save was in flight and
    // already picked the new row up; keep one entry per id either way.
    final newProfiles = [
      ...state.profiles.where((p) => p.id != created.id),
      created,
    ];
    state = state.copyWith(profiles: newProfiles);

    if (state.defaultProfile == null) {
      await setDefaultProfile(created.id);
    }

    return created;
  }

  Future<void> updateProfile(PrinterProfile profile) async {
    await _printerRepo.updateProfile(profile);
    if (!ref.mounted) return;

    final index = state.profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      final newProfiles = [...state.profiles];
      newProfiles[index] = profile;

      state = state.copyWith(
        profiles: newProfiles,
        defaultProfile: state.defaultProfile?.id == profile.id
            ? profile
            : state.defaultProfile,
      );
    }
  }

  Future<void> removeProfile(String id) async {
    await _printerRepo.deleteProfile(id);
    if (!ref.mounted) return;
    final newProfiles = state.profiles.where((p) => p.id != id).toList();

    if (state.defaultProfile?.id == id) {
      state = state.copyWith(profiles: newProfiles);
      // Promote the next available printer so POS keeps a target to print to.
      await setDefaultProfile(newProfiles.isEmpty ? null : newProfiles.first.id);
    } else {
      state = state.copyWith(profiles: newProfiles);
    }
  }

  Future<void> setDefaultProfile(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;

    if (id == null) {
      await prefs.remove(_keyDefaultProfileId);
      if (!ref.mounted) return;
      state = state.copyWith(clearDefaultProfile: true);
    } else {
      final profile = state.profiles.where((p) => p.id == id).firstOrNull;
      if (profile != null) {
        await prefs.setString(_keyDefaultProfileId, id);
        if (!ref.mounted) return;
        state = state.copyWith(defaultProfile: profile);
      }
    }
  }
}

final printerProfilesProvider =
    NotifierProvider<PrinterProfilesNotifier, PrinterProfilesState>(
      PrinterProfilesNotifier.new,
    );
