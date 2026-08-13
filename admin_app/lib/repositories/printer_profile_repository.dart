import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'dart:convert';

import '../models/printer_profile.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/tenant_mode_service.dart';

class PrinterProfileRepository {
  final ApiService _apiService;
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();

  PrinterProfileRepository(this._apiService);

  String get _tid => TenantModeService().activeTenantId;

  PrinterProfile _fromRow(Map<String, Object?> row) {
    return PrinterProfile.fromMap({
      'id': row['id'],
      'name': row['name'],
      'transport': row['transport'],
      'connectionParams': row['connectionParams'] != null
          ? jsonDecode(row['connectionParams'].toString())
          : {},
      'capabilityParams': row['capabilityParams'] != null
          ? jsonDecode(row['capabilityParams'].toString())
          : {},
    });
  }

  Future<List<PrinterProfile>> getProfiles({bool forceRefresh = false}) async {
    final db = await _dbService.database;
    final localData = await db.query(
      'printer_profiles',
      where: 'tenantId = ?',
      whereArgs: [_tid],
    );

    final localProfiles = localData.map(_fromRow).toList();

    var shouldFetchRemote = forceRefresh;
    if (!shouldFetchRemote) {
      try {
        shouldFetchRemote = await _syncService.isOnline;
      } catch (_) {
        // A failing connectivity probe must not hide the local printers.
        shouldFetchRemote = false;
      }
    }

    if (shouldFetchRemote) {
      try {
        final response = await _apiService.client.get(
          '/admin/settings/printers',
        );
        final List<dynamic> remoteData = response.data;
        final remoteProfiles = remoteData
            .map((e) => PrinterProfile.fromMap(Map<String, dynamic>.from(e)))
            .toList();

        await db.transaction((txn) async {
          await txn.delete(
            'printer_profiles',
            where: "tenantId = ? AND syncStatus = 'synced'",
            whereArgs: [_tid],
          );
          for (var p in remoteProfiles) {
            await txn.insert('printer_profiles', {
              'id': p.id,
              'tenantId': _tid,
              'name': p.name,
              'transport': p.transport.index,
              'connectionParams': jsonEncode(p.connectionParams),
              'capabilityParams': jsonEncode(p.capabilityParams),
              'syncStatus': 'synced',
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });

        // Locally created/edited profiles that have not reached the server yet
        // must survive a refresh, otherwise they disappear from settings until
        // the sync queue drains.
        final remoteIds = remoteProfiles.map((p) => p.id).toSet();
        final pendingOnly = localData
            .where(
              (row) =>
                  row['syncStatus'] != SyncStatus.synced.name &&
                  !remoteIds.contains(row['id']?.toString()),
            )
            .map(_fromRow);

        return [...remoteProfiles, ...pendingOnly];
      } catch (_) {}
    }
    return localProfiles;
  }

  Future<PrinterProfile> createProfile(PrinterProfile profile) async {
    final db = await _dbService.database;

    final id = const Uuid().v4();
    final newProfile = profile.copyWith(id: id);

    await db.insert('printer_profiles', {
      'id': newProfile.id,
      'tenantId': _tid,
      'name': newProfile.name,
      'transport': newProfile.transport.index,
      'connectionParams': jsonEncode(newProfile.connectionParams),
      'capabilityParams': jsonEncode(newProfile.capabilityParams),
      'syncStatus': SyncStatus.pending.name,
    });

    await _syncService.enqueueOperation(
      entityType: 'printerProfile',
      action: 'create',
      payload: newProfile.toMap(),
    );

    return newProfile;
  }

  Future<void> updateProfile(PrinterProfile profile) async {
    final db = await _dbService.database;

    await db.update(
      'printer_profiles',
      {
        'name': profile.name,
        'transport': profile.transport.index,
        'connectionParams': jsonEncode(profile.connectionParams),
        'capabilityParams': jsonEncode(profile.capabilityParams),
        'syncStatus': SyncStatus.pending.name,
      },
      where: 'id = ? AND tenantId = ?',
      whereArgs: [profile.id, _tid],
    );

    await _syncService.enqueueOperation(
      entityType: 'printerProfile',
      action: 'update',
      payload: profile.toMap(),
    );
  }

  Future<void> deleteProfile(String id) async {
    final db = await _dbService.database;

    // Queue the remote delete first: the outbox row carries the id, so the
    // server still gets the delete even though the local row is gone.
    await _syncService.enqueueOperation(
      entityType: 'printerProfile',
      action: 'delete',
      payload: {'id': id},
    );

    // Remove the local row so a deleted printer does not come back the next
    // time settings are opened offline.
    await db.delete(
      'printer_profiles',
      where: 'id = ? AND tenantId = ?',
      whereArgs: [id, _tid],
    );
  }
}
