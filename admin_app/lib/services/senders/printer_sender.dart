import '../../models/printer_profile.dart';

abstract class PrinterSender {
  Future<void> send(List<int> bytes, PrinterProfile profile);

  /// Whether [connect] actually reaches the device, so a failure is
  /// meaningful. Transports that cannot be probed without printing leave this
  /// false and callers should not report "connection OK" for them.
  bool get supportsConnectionProbe => false;

  /// Performs connection test / status check if applicable.
  ///
  /// Throws with a human-readable message when the device cannot be reached.
  Future<bool> connect(PrinterProfile profile) async => true;

  /// Disconnects if maintaining persistent connection
  Future<void> disconnect() async {}
}
