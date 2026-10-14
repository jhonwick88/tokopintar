import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/item_model.dart';
import 'dart:developer' as dev;
import 'file_saver_helper.dart';

class ExcelService {
  /// Generates and saves an empty Excel template for product import across multi-devices
  static Future<bool> generateProductTemplate() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Headers
      sheetObject.cell(CellIndex.indexByString('A1')).value = TextCellValue('SKU');
      sheetObject.cell(CellIndex.indexByString('B1')).value = TextCellValue('Barcode (UPC)');
      sheetObject.cell(CellIndex.indexByString('C1')).value = TextCellValue('Nama Produk');
      sheetObject.cell(CellIndex.indexByString('D1')).value = TextCellValue('Kategori ID (opsional, default: 0)');
      sheetObject.cell(CellIndex.indexByString('E1')).value = TextCellValue('Harga Jual');
      sheetObject.cell(CellIndex.indexByString('F1')).value = TextCellValue('Stok Awal (opsional, default: 10)');
      
      // Instruction row
      sheetObject.cell(CellIndex.indexByString('A2')).value = TextCellValue('SKU-1234');
      sheetObject.cell(CellIndex.indexByString('B2')).value = TextCellValue('0123456789');
      sheetObject.cell(CellIndex.indexByString('C2')).value = TextCellValue('Produk Contoh');
      sheetObject.cell(CellIndex.indexByString('D2')).value = IntCellValue(0);
      sheetObject.cell(CellIndex.indexByString('E2')).value = IntCellValue(15000);
      sheetObject.cell(CellIndex.indexByString('F2')).value = IntCellValue(100);

      var fileBytes = excel.save();
      if (fileBytes != null) {
        return await FileSaverHelper.saveFile(
          bytes: fileBytes,
          fileName: 'template_produk.xlsx',
          dialogTitle: 'Download Template Produk Excel',
          allowedExtensions: ['xlsx'],
        );
      }
      return false;
    } catch (e) {
      dev.log('Error generating template: $e');
      throw Exception('Gagal membuat template: $e');
    }
  }

  /// Opens a file picker, reads the Excel file, and returns a list of ItemModels across multi-devices
  static Future<List<ItemModel>> importProductsFromExcel() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (files.isEmpty) {
        return [];
      }

      final pickedFile = files.first;
      final bytes = await pickedFile.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Tidak dapat membaca data file Excel atau file kosong.');
      }

      var excel = Excel.decodeBytes(bytes);
      List<ItemModel> parsedItems = [];

      for (var table in excel.tables.keys) {
        var rows = excel.tables[table]?.rows;
        if (rows == null || rows.isEmpty) continue;

        // Skip header row (index 0)
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty) continue;

          // Safely extract string values
          String sku = row.isNotEmpty ? row[0]?.value?.toString().trim() ?? '' : '';
          String barcode = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          String name = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
          
          if (name.isEmpty) continue; // Name is required

          int categoryId = 0;
          if (row.length > 3 && row[3]?.value != null) {
            categoryId = int.tryParse(row[3]!.value.toString()) ?? 0;
          }

          double price = 0.0;
          if (row.length > 4 && row[4]?.value != null) {
             price = double.tryParse(row[4]!.value.toString()) ?? 0.0;
          }

          double stock = 10.0;
          if (row.length > 5 && row[5]?.value != null) {
             stock = double.tryParse(row[5]!.value.toString()) ?? 10.0;
          }

          parsedItems.add(ItemModel(
            itemNo: sku,
            itemUPC: barcode,
            itemName: name,
            categoryId: categoryId,
            price: price,
            obQuantity: stock,
          ));
        }
        
        // Break after the first valid sheet
        break;
      }

      return parsedItems;
    } catch (e) {
      dev.log('Error importing excel: $e');
      throw Exception('Gagal membaca file Excel: $e');
    }
  }
}
