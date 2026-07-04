import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String invoiceNo;
  final DateTime date;
  final String cashier;
  final double subtotal;
  final double discount;
  final double grandTotal;
  final double tax;
  final double serviceCharge;
  final String paymentMethod; // cash, qris, bank, ewallet, split
  final double paidAmount;
  final double changeAmount;
  final String status; // completed, voided, refunded
  final String? voidReason;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? refundReason;
  final DateTime? refundedAt;
  final String? refundedBy;
  final List<SaleItemModel> items;

  SaleModel({
    required this.invoiceNo,
    required this.date,
    required this.cashier,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    this.tax = 0.0,
    this.serviceCharge = 0.0,
    required this.paymentMethod,
    required this.paidAmount,
    required this.changeAmount,
    this.status = 'completed',
    this.voidReason,
    this.voidedAt,
    this.voidedBy,
    this.refundReason,
    this.refundedAt,
    this.refundedBy,
    this.items = const [],
  });

  factory SaleModel.fromJson(Map<String, dynamic> json, [List<SaleItemModel> items = const []]) {
    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    return SaleModel(
      invoiceNo: json['invoice_no'] as String? ?? '',
      date: parseDateTime(json['date']),
      cashier: json['cashier'] as String? ?? 'Admin',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (json['service_charge'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (json['change_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'completed',
      voidReason: json['void_reason'] as String?,
      voidedAt: json['voided_at'] != null ? parseDateTime(json['voided_at']) : null,
      voidedBy: json['voided_by'] as String?,
      refundReason: json['refund_reason'] as String?,
      refundedAt: json['refunded_at'] != null ? parseDateTime(json['refunded_at']) : null,
      refundedBy: json['refunded_by'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_no': invoiceNo,
      'date': Timestamp.fromDate(date),
      'cashier': cashier,
      'subtotal': subtotal,
      'discount': discount,
      'grand_total': grandTotal,
      'tax': tax,
      'service_charge': serviceCharge,
      'payment_method': paymentMethod,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'status': status,
      'void_reason': voidReason,
      'voided_at': voidedAt != null ? Timestamp.fromDate(voidedAt!) : null,
      'voided_by': voidedBy,
      'refund_reason': refundReason,
      'refunded_at': refundedAt != null ? Timestamp.fromDate(refundedAt!) : null,
      'refunded_by': refundedBy,
    };
  }
}

class SaleItemModel {
  final String itemNo;
  final String itemUPC;
  final String itemName;
  final int qty;
  final double price;
  final double subtotal;
  final String note;
  final double discount;

  SaleItemModel({
    required this.itemNo,
    required this.itemUPC,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.subtotal,
    this.note = '',
    this.discount = 0.0,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      itemNo: json['itemno'] as String? ?? '',
      itemUPC: json['itemupc'] as String? ?? '',
      itemName: json['itemname'] as String? ?? '',
      qty: json['qty'] as int? ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String? ?? '',
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemno': itemNo,
      'itemupc': itemUPC,
      'itemname': itemName,
      'qty': qty,
      'price': price,
      'subtotal': subtotal,
      'note': note,
      'discount': discount,
    };
  }
}
