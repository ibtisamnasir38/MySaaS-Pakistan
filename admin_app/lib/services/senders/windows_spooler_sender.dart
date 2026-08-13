import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../../models/printer_profile.dart';
import 'printer_sender.dart';

class WindowsSpoolerSender extends PrinterSender {
  @override
  bool get supportsConnectionProbe => true;

  @override
  Future<bool> connect(PrinterProfile profile) async {
    if (!Platform.isWindows) {
      throw Exception('Windows Spooler is only supported on Windows.');
    }

    final printerName = profile.printerName;
    if (printerName == null || printerName.isEmpty) {
      throw Exception('Printer Name is required for Windows Spooler');
    }

    final pPrinterName = printerName.toNativeUtf16();
    final phPrinter = calloc<HANDLE>();

    try {
      if (OpenPrinter(pPrinterName, phPrinter, nullptr) == 0) {
        throw Exception(
          'Failed to open printer: $printerName (Error: ${GetLastError()})',
        );
      }
      ClosePrinter(phPrinter.value);
      return true;
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
    }
  }

  @override
  Future<void> send(List<int> bytes, PrinterProfile profile) async {
    if (!Platform.isWindows) {
      throw Exception('Windows Spooler is only supported on Windows.');
    }

    final printerName = profile.printerName;
    if (printerName == null) {
      throw Exception('Printer Name is required for Windows Spooler');
    }

    final pPrinterName = printerName.toNativeUtf16();
    final phPrinter = calloc<HANDLE>();
    final pDocInfo = calloc<DOC_INFO_1>();

    try {
      // 1. Open Printer
      final openResult = OpenPrinter(pPrinterName, phPrinter, nullptr);
      if (openResult == 0) {
        throw Exception(
          'Failed to open printer: $printerName (Error: ${GetLastError()})',
        );
      }

      // 2. Start Doc
      pDocInfo.ref.pDocName = 'Receipt'.toNativeUtf16();
      pDocInfo.ref.pOutputFile = nullptr;
      pDocInfo.ref.pDatatype = 'RAW'.toNativeUtf16();

      final startDocResult = StartDocPrinter(phPrinter.value, 1, pDocInfo);
      if (startDocResult == 0) {
        ClosePrinter(phPrinter.value);
        throw Exception('Failed to start document (Error: ${GetLastError()})');
      }

      // 3. Start Page
      if (StartPagePrinter(phPrinter.value) == 0) {
        EndDocPrinter(phPrinter.value);
        ClosePrinter(phPrinter.value);
        throw Exception('Failed to start page');
      }

      // 4. Write Bytes
      // Allocate native memory for bytes
      final pBytes = calloc<Uint8>(bytes.length);
      final pBytesWritten = calloc<Uint32>();

      for (var i = 0; i < bytes.length; i++) {
        pBytes[i] = bytes[i];
      }

      final writeResult = WritePrinter(
        phPrinter.value,
        pBytes,
        bytes.length,
        pBytesWritten,
      );

      if (writeResult == 0) {
        // Cleanup on error
        EndPagePrinter(phPrinter.value);
        EndDocPrinter(phPrinter.value);
        ClosePrinter(phPrinter.value);
        calloc.free(pBytes);
        calloc.free(pBytesWritten);
        throw Exception('Failed to write to printer');
      }

      // 5. End Page & Doc
      EndPagePrinter(phPrinter.value);
      EndDocPrinter(phPrinter.value);
      ClosePrinter(phPrinter.value);

      calloc.free(pBytes);
      calloc.free(pBytesWritten);
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
      free(pDocInfo.ref.pDocName);
      free(pDocInfo.ref.pDatatype);
      calloc.free(pDocInfo);
    }
  }
}
