class SettingsModel {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String receiptHeader;
  final String receiptFooter;
  final String restApiUrl;
  final String printerIp;
  final int printerPort;
  final String printerType; // LAN, Bluetooth, USB, Browser
  final String printerMacAddress;
  
  // Professional additions
  final String adminPin;
  final bool enableTax;
  final double taxPercentage;
  final bool enableServiceCharge;
  final double serviceChargePercentage;
  final int printerPaperSize; // 58 or 80
  final int printReceiptCopies;
  final bool autoPrintOnCheckout;
  final bool enableFloatingCalculator;

  SettingsModel({
    this.shopName = 'Toko Pintar',
    this.shopAddress = 'Jl. Kaliurang KM 5, Yogyakarta',
    this.shopPhone = '081234567890',
    this.receiptHeader = 'Selamat Datang di Toko Pintar!',
    this.receiptFooter = 'Terima Kasih atas Kunjungan Anda',
    this.restApiUrl = 'http://localhost:8080',
    this.printerIp = '192.168.1.100',
    this.printerPort = 9100,
    this.printerType = 'LAN',
    this.printerMacAddress = '',
    this.adminPin = '1234',
    this.enableTax = false,
    this.taxPercentage = 0.0,
    this.enableServiceCharge = false,
    this.serviceChargePercentage = 0.0,
    this.printerPaperSize = 58,
    this.printReceiptCopies = 1,
    this.autoPrintOnCheckout = false,
    this.enableFloatingCalculator = true,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      shopName: json['shop_name'] as String? ?? 'Toko Pintar',
      shopAddress: json['shop_address'] as String? ?? 'Jl. Kaliurang KM 5, Yogyakarta',
      shopPhone: json['shop_phone'] as String? ?? '081234567890',
      receiptHeader: json['receipt_header'] as String? ?? 'Selamat Datang di Toko Pintar!',
      receiptFooter: json['receipt_footer'] as String? ?? 'Terima Kasih atas Kunjungan Anda',
      restApiUrl: json['rest_api_url'] as String? ?? 'http://localhost:8080',
      printerIp: json['printer_ip'] as String? ?? '192.168.1.100',
      printerPort: json['printer_port'] as int? ?? 9100,
      printerType: json['printer_type'] as String? ?? 'LAN',
      printerMacAddress: json['printer_mac_address'] as String? ?? '',
      adminPin: json['admin_pin'] as String? ?? '1234',
      enableTax: json['enable_tax'] as bool? ?? false,
      taxPercentage: (json['tax_percentage'] as num?)?.toDouble() ?? 0.0,
      enableServiceCharge: json['enable_service_charge'] as bool? ?? false,
      serviceChargePercentage: (json['service_charge_percentage'] as num?)?.toDouble() ?? 0.0,
      printerPaperSize: json['printer_paper_size'] as int? ?? 58,
      printReceiptCopies: json['print_receipt_copies'] as int? ?? 1,
      autoPrintOnCheckout: json['auto_print_on_checkout'] as bool? ?? false,
      enableFloatingCalculator: json['enable_floating_calculator'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_name': shopName,
      'shop_address': shopAddress,
      'shop_phone': shopPhone,
      'receipt_header': receiptHeader,
      'receipt_footer': receiptFooter,
      'rest_api_url': restApiUrl,
      'printer_ip': printerIp,
      'printer_port': printerPort,
      'printer_type': printerType,
      'printer_mac_address': printerMacAddress,
      'admin_pin': adminPin,
      'enable_tax': enableTax,
      'tax_percentage': taxPercentage,
      'enable_service_charge': enableServiceCharge,
      'service_charge_percentage': serviceChargePercentage,
      'printer_paper_size': printerPaperSize,
      'print_receipt_copies': printReceiptCopies,
      'auto_print_on_checkout': autoPrintOnCheckout,
      'enable_floating_calculator': enableFloatingCalculator,
    };
  }

  SettingsModel copyWith({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? receiptHeader,
    String? receiptFooter,
    String? restApiUrl,
    String? printerIp,
    int? printerPort,
    String? printerType,
    String? printerMacAddress,
    String? adminPin,
    bool? enableTax,
    double? taxPercentage,
    bool? enableServiceCharge,
    double? serviceChargePercentage,
    int? printerPaperSize,
    int? printReceiptCopies,
    bool? autoPrintOnCheckout,
    bool? enableFloatingCalculator,
  }) {
    return SettingsModel(
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopPhone: shopPhone ?? this.shopPhone,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      restApiUrl: restApiUrl ?? this.restApiUrl,
      printerIp: printerIp ?? this.printerIp,
      printerPort: printerPort ?? this.printerPort,
      printerType: printerType ?? this.printerType,
      printerMacAddress: printerMacAddress ?? this.printerMacAddress,
      adminPin: adminPin ?? this.adminPin,
      enableTax: enableTax ?? this.enableTax,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      enableServiceCharge: enableServiceCharge ?? this.enableServiceCharge,
      serviceChargePercentage: serviceChargePercentage ?? this.serviceChargePercentage,
      printerPaperSize: printerPaperSize ?? this.printerPaperSize,
      printReceiptCopies: printReceiptCopies ?? this.printReceiptCopies,
      autoPrintOnCheckout: autoPrintOnCheckout ?? this.autoPrintOnCheckout,
      enableFloatingCalculator: enableFloatingCalculator ?? this.enableFloatingCalculator,
    );
  }
}
