import 'dart:io';

import '../../models/printer_profile.dart';
import 'printer_sender.dart';

class NetworkSender extends PrinterSender {
  @override
  bool get supportsConnectionProbe => true;

  @override
  Future<bool> connect(PrinterProfile profile) async {
    final ip = profile.ip;
    if (ip == null || ip.isEmpty) {
      throw Exception('IP Address is required for Network Printer');
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        profile.port ?? 9100,
        timeout: const Duration(seconds: 5),
      );
      return true;
    } catch (e) {
      throw Exception('Failed to connect to network printer: $e');
    } finally {
      socket?.destroy();
    }
  }

  @override
  Future<void> send(List<int> bytes, PrinterProfile profile) async {
    final ip = profile.ip;
    final port = profile.port ?? 9100;

    if (ip == null || ip.isEmpty) {
      throw Exception('IP Address is required for Network Printer');
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
    } catch (e) {
      throw Exception('Failed to connect to network printer: $e');
    } finally {
      socket?.destroy();
    }
  }
}
