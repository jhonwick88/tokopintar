import 'dart:developer' as dev;
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Win32 DOC_INFO_1W structure
final class DocInfo1W extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

typedef OpenPrinterWNative = Int32 Function(
  Pointer<Utf16> pPrinterName,
  Pointer<IntPtr> phPrinter,
  Pointer<Void> pDefault,
);
typedef OpenPrinterWDart = int Function(
  Pointer<Utf16> pPrinterName,
  Pointer<IntPtr> phPrinter,
  Pointer<Void> pDefault,
);

typedef StartDocPrinterWNative = Int32 Function(
  IntPtr hPrinter,
  Uint32 level,
  Pointer<DocInfo1W> pDocInfo,
);
typedef StartDocPrinterWDart = int Function(
  int hPrinter,
  int level,
  Pointer<DocInfo1W> pDocInfo,
);

typedef StartPagePrinterNative = Int32 Function(IntPtr hPrinter);
typedef StartPagePrinterDart = int Function(int hPrinter);

typedef WritePrinterNative = Int32 Function(
  IntPtr hPrinter,
  Pointer<Uint8> pBuf,
  Uint32 cbBuf,
  Pointer<Uint32> pcWritten,
);
typedef WritePrinterDart = int Function(
  int hPrinter,
  Pointer<Uint8> pBuf,
  int cbBuf,
  Pointer<Uint32> pcWritten,
);

typedef EndPagePrinterNative = Int32 Function(IntPtr hPrinter);
typedef EndPagePrinterDart = int Function(int hPrinter);

typedef EndDocPrinterNative = Int32 Function(IntPtr hPrinter);
typedef EndDocPrinterDart = int Function(int hPrinter);

typedef ClosePrinterNative = Int32 Function(IntPtr hPrinter);
typedef ClosePrinterDart = int Function(int hPrinter);

class WindowsRawPrinter {
  /// Sends raw ESC/POS byte sequence directly to a Windows spooler printer.
  /// Using datatype "RAW" bypasses Windows GDI page rendering, avoiding
  /// forced page height form-feeds and extra bottom blank space.
  static bool printRawBytes(
    String printerName,
    List<int> bytes, {
    String docName = 'Receipt',
    int copies = 1,
  }) {
    if (!Platform.isWindows) return false;
    if (bytes.isEmpty) return false;

    DynamicLibrary winspool;
    try {
      winspool = DynamicLibrary.open('winspool.drv');
    } catch (e) {
      dev.log('WindowsRawPrinter: Failed to open winspool.drv: $e');
      return false;
    }

    final openPrinter = winspool.lookupFunction<OpenPrinterWNative, OpenPrinterWDart>('OpenPrinterW');
    final startDocPrinter = winspool.lookupFunction<StartDocPrinterWNative, StartDocPrinterWDart>('StartDocPrinterW');
    final startPagePrinter = winspool.lookupFunction<StartPagePrinterNative, StartPagePrinterDart>('StartPagePrinter');
    final writePrinter = winspool.lookupFunction<WritePrinterNative, WritePrinterDart>('WritePrinter');
    final endPagePrinter = winspool.lookupFunction<EndPagePrinterNative, EndPagePrinterDart>('EndPagePrinter');
    final endDocPrinter = winspool.lookupFunction<EndDocPrinterNative, EndDocPrinterDart>('EndDocPrinter');
    final closePrinter = winspool.lookupFunction<ClosePrinterNative, ClosePrinterDart>('ClosePrinter');

    final pPrinterName = printerName.toNativeUtf16();
    final phPrinter = calloc<IntPtr>();

    try {
      final openRes = openPrinter(pPrinterName, phPrinter, nullptr);
      if (openRes == 0 || phPrinter.value == 0) {
        dev.log('WindowsRawPrinter: OpenPrinterW failed for "$printerName"');
        return false;
      }

      final hPrinter = phPrinter.value;
      final pDocName = docName.toNativeUtf16();
      final pDatatype = 'RAW'.toNativeUtf16();
      final pDocInfo = calloc<DocInfo1W>();
      pDocInfo.ref.pDocName = pDocName;
      pDocInfo.ref.pOutputFile = nullptr;
      pDocInfo.ref.pDatatype = pDatatype;

      try {
        final docId = startDocPrinter(hPrinter, 1, pDocInfo);
        if (docId <= 0) {
          dev.log('WindowsRawPrinter: StartDocPrinterW failed (id=$docId)');
          return false;
        }

        try {
          final pBuf = calloc<Uint8>(bytes.length);
          final pcWritten = calloc<Uint32>();
          final byteList = pBuf.asTypedList(bytes.length);
          byteList.setAll(0, bytes);

          try {
            for (int i = 0; i < copies; i++) {
              startPagePrinter(hPrinter);
              final writeRes = writePrinter(hPrinter, pBuf, bytes.length, pcWritten);
              endPagePrinter(hPrinter);
              if (writeRes == 0) {
                dev.log('WindowsRawPrinter: WritePrinter failed at copy $i');
                return false;
              }
            }
            dev.log('WindowsRawPrinter: Successfully printed ${bytes.length} bytes ($copies copies) to "$printerName"');
            return true;
          } finally {
            calloc.free(pBuf);
            calloc.free(pcWritten);
          }
        } finally {
          endDocPrinter(hPrinter);
        }
      } finally {
        calloc.free(pDocName);
        calloc.free(pDatatype);
        calloc.free(pDocInfo);
        closePrinter(hPrinter);
      }
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
    }
  }
}
