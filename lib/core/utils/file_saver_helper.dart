import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/web_download.dart';

class FileSaverHelper {
  /// Universally saves bytes to a file across Web, Android, Windows, macOS, Linux.
  /// Returns `true` if saved successfully, or `false` if user cancelled.
  static Future<bool> saveFile({
    required List<int> bytes,
    required String fileName,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    try {
      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);
        return true;
      }

      final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      final Uri? uri = await FilePicker.saveFile(
        dialogTitle: dialogTitle ?? 'Simpan File',
        fileName: fileName,
        bytes: uint8,
        type: (allowedExtensions != null && allowedExtensions.isNotEmpty)
            ? FileType.custom
            : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (uri == null) {
        return false;
      }

      // If scheme is file on desktop, verify bytes exist
      if (uri.scheme == 'file' && (!kIsWeb && !Platform.isAndroid && !Platform.isIOS)) {
        final file = File(uri.toFilePath());
        if (!await file.exists() || (await file.length()) == 0) {
          await file.writeAsBytes(uint8);
        }
      }

      return true;
    } catch (e) {
      dev.log('FileSaverHelper error: $e');
      rethrow;
    }
  }
}
