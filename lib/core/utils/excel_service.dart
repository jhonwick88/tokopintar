import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
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

  /// Exports product items to Excel (.xlsx) file with barcode analysis status
  static Future<bool> exportProductsToExcel({
    required List<ItemModel> items,
    Map<int, String>? categoryNames,
    String filterName = 'Semua Produk',
  }) async {
    try {
      var excel = Excel.createExcel();
      const sheetName = 'Daftar Produk';
      Sheet sheetObject = excel[sheetName];
      excel.delete('Sheet1');

      final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'id_ID');
      final exportDate = dateFormat.format(DateTime.now());
      final withBarcodeCount = items.where((i) => i.itemUPC.trim().isNotEmpty).length;
      final noBarcodeCount = items.where((i) => i.itemUPC.trim().isEmpty).length;

      // Meta Header info
      sheetObject.cell(CellIndex.indexByString('A1')).value = TextCellValue('LAPORAN MASTER DATA PRODUK & STATUS BARCODE');
      sheetObject.cell(CellIndex.indexByString('A2')).value = TextCellValue('Filter: $filterName  |  Waktu Export: $exportDate');
      sheetObject.cell(CellIndex.indexByString('A3')).value = TextCellValue('Total Produk: ${items.length}  |  Ada Barcode: $withBarcodeCount  |  Tanpa Barcode: $noBarcodeCount');

      // Table headers
      final headers = [
        'No',
        'SKU (Kode Item)',
        'Barcode (UPC)',
        'Nama Produk',
        'Kategori',
        'Harga Jual (Rp)',
        'Stok Fisik',
        'Status Barcode',
      ];

      for (int c = 0; c < headers.length; c++) {
        final cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Rows
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final rowIdx = 5 + i;
        final hasBarcode = item.itemUPC.trim().isNotEmpty;
        final catName = categoryNames?[item.categoryId] ?? 'Kategori #${item.categoryId}';

        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value = IntCellValue(i + 1);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value = TextCellValue(item.itemNo);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value = TextCellValue(hasBarcode ? item.itemUPC : '-');
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value = TextCellValue(item.itemName);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value = TextCellValue(catName);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value = DoubleCellValue(item.price);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value = DoubleCellValue(item.obQuantity);
        
        final statusCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx));
        statusCell.value = TextCellValue(hasBarcode ? 'SUDAH ADA' : 'BELUM ADA');
        statusCell.cellStyle = CellStyle(
          bold: true,
          fontColorHex: hasBarcode ? ExcelColor.fromHexString('#166534') : ExcelColor.fromHexString('#991B1B'),
          backgroundColorHex: hasBarcode ? ExcelColor.fromHexString('#DCFCE7') : ExcelColor.fromHexString('#FEE2E2'),
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Column widths
      sheetObject.setColumnWidth(0, 8);
      sheetObject.setColumnWidth(1, 18);
      sheetObject.setColumnWidth(2, 22);
      sheetObject.setColumnWidth(3, 35);
      sheetObject.setColumnWidth(4, 20);
      sheetObject.setColumnWidth(5, 18);
      sheetObject.setColumnWidth(6, 14);
      sheetObject.setColumnWidth(7, 18);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final dateSlug = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final cleanFilter = filterName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        return await FileSaverHelper.saveFile(
          bytes: fileBytes,
          fileName: 'laporan_produk_${cleanFilter}_$dateSlug.xlsx',
          dialogTitle: 'Download Laporan Produk Excel',
          allowedExtensions: ['xlsx'],
        );
      }
      return false;
    } catch (e) {
      dev.log('Error exporting products to excel: $e');
      throw Exception('Gagal mengekspor data produk ke Excel: $e');
    }
  }
}
