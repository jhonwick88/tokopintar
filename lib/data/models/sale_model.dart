class SaleModel {
  final String? id;
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
  final int? customerId;
  final List<SaleItemModel> items;
  final List<SalesPaymentModel> payments;

  SaleModel({
    this.id,
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
    this.customerId,
    this.items = const [],
    this.payments = const [],
  });

  factory SaleModel.fromJson(
    Map<String, dynamic> json, [
    List<SaleItemModel> items = const [],
  ]) {
    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    List<SaleItemModel> parsedItems = List.from(items);
    if (json['items'] != null && json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<SalesPaymentModel> parsedPayments = [];
    if (json['payments'] != null && json['payments'] is List) {
      parsedPayments = (json['payments'] as List)
          .map((e) => SalesPaymentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return SaleModel(
      id: json['id'] as String?,
      invoiceNo:
          json['receipt_no'] as String? ?? json['invoice_no'] as String? ?? '',
      date: parseDateTime(json['sale_date'] ?? json['date']),
      cashier:
          json['cashier_id'] as String? ??
          json['cashier'] as String? ??
          'Admin',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      grandTotal:
          (json['total'] as num?)?.toDouble() ??
          (json['grand_total'] as num?)?.toDouble() ??
          0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (json['service_charge'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paidAmount:
          (json['cash_tendered'] as num?)?.toDouble() ??
          (json['paid_amount'] as num?)?.toDouble() ??
          0.0,
      changeAmount:
          (json['change_due'] as num?)?.toDouble() ??
          (json['change_amount'] as num?)?.toDouble() ??
          0.0,
      status: ((json['is_void'] as num?)?.toInt() == 1)
          ? 'voided'
          : (json['status'] as String? ?? 'completed'),
      voidReason: json['void_reason'] as String?,
      voidedAt: json['voided_at'] != null
          ? parseDateTime(json['voided_at'])
          : null,
      voidedBy: json['voided_by'] as String?,
      refundReason: json['refund_reason'] as String?,
      refundedAt: json['refunded_at'] != null
          ? parseDateTime(json['refunded_at'])
          : null,
      refundedBy: json['refunded_by'] as String?,
      customerId: (json['customer_id'] as num?)?.toInt(),
      items: parsedItems,
      payments: parsedPayments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'receipt_no': invoiceNo,
      'sale_date': date.toIso8601String(),
      'cashier_id': cashier,
      'subtotal': subtotal,
      'discount': discount,
      'total': grandTotal,
      'tax': tax,
      'service_charge': serviceCharge,
      'payment_method': paymentMethod,
      'cash_tendered': paidAmount,
      'change_due': changeAmount,
      'is_void': status == 'voided' ? 1 : 0,
      'status': status,
      if (voidReason != null) 'void_reason': voidReason,
      if (voidedAt != null) 'voided_at': voidedAt?.toIso8601String(),
      if (voidedBy != null) 'voided_by': voidedBy,
      if (refundReason != null) 'refund_reason': refundReason,
      if (refundedAt != null) 'refunded_at': refundedAt?.toIso8601String(),
      if (refundedBy != null) 'refunded_by': refundedBy,
      if (customerId != null) 'customer_id': customerId,
      'items': items.map((e) => e.toJson()).toList(),
      if (payments.isNotEmpty)
        'payments': payments.map((e) => e.toJson()).toList(),
    };
  }
}

class SalesPaymentModel {
  final int? id;
  final String? invoiceNo;
  final String paymentMethod;
  final double amount;
  final String? paymentDate;

  SalesPaymentModel({
    this.id,
    this.invoiceNo,
    required this.paymentMethod,
    required this.amount,
    this.paymentDate,
  });

  factory SalesPaymentModel.fromJson(Map<String, dynamic> json) {
    return SalesPaymentModel(
      id: (json['id'] as num?)?.toInt(),
      invoiceNo: json['invoiceno'] as String?,
      paymentMethod: json['payment_method'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['payment_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (invoiceNo != null) 'invoiceno': invoiceNo,
      'payment_method': paymentMethod,
      'amount': amount,
      if (paymentDate != null) 'payment_date': paymentDate,
    };
  }
}

class SaleItemModel {
  final int? id;
  final String itemNo;
  final String itemUPC;
  final String itemName;
  final int qty;
  final double price;
  final double subtotal;
  final String note;
  final double discount;
  final String unitName;
  final double ratio;

  SaleItemModel({
    this.id,
    required this.itemNo,
    required this.itemUPC,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.subtotal,
    this.note = '',
    this.discount = 0.0,
    this.unitName = '',
    this.ratio = 0.0,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      id: (json['id'] as num?)?.toInt(),
      itemNo: json['itemno'] as String? ?? '',
      itemUPC: json['itemupc'] as String? ?? '',
      itemName: json['itemname'] as String? ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal:
          (json['total'] as num?)?.toDouble() ??
          (json['subtotal'] as num?)?.toDouble() ??
          0.0,
      note: json['note'] as String? ?? '',
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      unitName: json['unit_name'] as String? ?? '',
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'itemno': itemNo,
      'itemupc': itemUPC,
      'itemname': itemName,
      'qty': qty,
      'price': price,
      'total': subtotal,
      'note': note,
      'discount': discount,
      if (unitName.isNotEmpty) 'unit_name': unitName,
      if (ratio > 0) 'ratio': ratio,
    };
  }
}
