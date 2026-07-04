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
    );
  }
}
