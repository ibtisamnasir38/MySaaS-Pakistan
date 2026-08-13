import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:printing/printing.dart';

import '../models/printer_profile.dart';

/// A printer installed on the host operating system (Windows spooler, CUPS…).
class SystemPrinter {
  final String name;
  final String? model;
  final String? location;
  final bool isDefault;
  final bool isAvailable;

  const SystemPrinter({
    required this.name,
    this.model,
    this.location,
    this.isDefault = false,
    this.isAvailable = true,
  });
}

/// A Bluetooth Classic device already paired with this machine.
class BondedBluetoothDevice {
  final String name;
  final String address;

  const BondedBluetoothDevice({required this.name, required this.address});
}

class DiscoveryService {
  /// Returns a list of available serial ports (e.g. COM1, /dev/ttyUSB0)
  static List<String> getAvailableSerialPorts() {
    try {
      return SerialPort.availablePorts;
    } catch (_) {
      // libserialport is unavailable on some platforms/CI hosts.
      return const [];
    }
  }

  /// Returns the printers installed on the host OS.
  ///
  /// Used to fill in the Windows spooler printer name without typing it.
  /// Returns an empty list on platforms that do not expose a printer list.
  static Future<List<SystemPrinter>> getSystemPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      return printers
          .map(
            (printer) => SystemPrinter(
              name: printer.name,
              model: printer.model,
              location: printer.location,
              isDefault: printer.isDefault,
              isAvailable: printer.isAvailable,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns the Bluetooth Classic devices already paired with this device.
  ///
  /// Pairing happens in the OS settings, so this only lists what is bonded.
  /// Android-only: other platforms return an empty list.
  static Future<List<BondedBluetoothDevice>> getBondedBluetoothDevices() async {
    if (!Platform.isAndroid) return const [];

    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices
          .map(
            (device) => BondedBluetoothDevice(
              name: (device.name?.trim().isNotEmpty ?? false)
                  ? device.name!.trim()
                  : device.address,
              address: device.address,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns the ESC/POS capability profiles bundled with the app.
  ///
  /// Falls back to a small built-in list when the capability catalogue cannot
  /// be read (for example when no asset bundle is available).
  static Future<List<PrinterCapabilityProfile>> getCapabilityProfiles() async {
    try {
      final raw = await CapabilityProfile.getAvailableProfiles();
      final profiles = <PrinterCapabilityProfile>[];

      for (final entry in raw) {
        if (entry is! Map) continue;
        final key = entry['key']?.toString().trim() ?? '';
        if (key.isEmpty) continue;

        final label = entry['name']?.toString().trim();
        profiles.add(
          PrinterCapabilityProfile(
            key: key,
            vendor: entry['vendor']?.toString().trim() ?? '',
            label: (label == null || label.isEmpty) ? key : label,
          ),
        );
      }

      if (profiles.isEmpty) return PrinterProfile.fallbackCapabilityProfiles;

      profiles.sort((a, b) {
        if (a.key == 'default') return -1;
        if (b.key == 'default') return 1;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
      return profiles;
    } catch (_) {
      return PrinterProfile.fallbackCapabilityProfiles;
    }
  }

  /// Scans for BLE devices
  /// Returns a Stream of ScanResults
  static Stream<List<ScanResult>> scanBleDevices({
    Duration timeout = const Duration(seconds: 4),
  }) {
    // Start scanning
    FlutterBluePlus.startScan(timeout: timeout);

    // Return the stream of results
    return FlutterBluePlus.scanResults;
  }

  static Future<void> stopBleScan() async {
    await FlutterBluePlus.stopScan();
  }
}
