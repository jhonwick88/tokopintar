class ItemModel {
  final String itemNo;
  final String itemUPC;
  final String itemName;
  final String itemNameShort;
  final int categoryId;
  final double price; // mapped to def_unitprice1
  final double obQuantity;
  final String notes;

  ItemModel({
    required this.itemNo,
    required this.itemUPC,
    required this.itemName,
    this.itemNameShort = '',
    required this.categoryId,
    required this.price,
    this.obQuantity = 10.0,
    this.notes = '',
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      itemNo: json['itemno'] as String? ?? '',
      itemUPC: json['itemupc'] as String? ?? '',
      itemName: json['itemname'] as String? ?? '',
      itemNameShort: json['itemname_short'] as String? ?? '',
      categoryId: json['categoryid'] as int? ?? 0,
      price: (json['def_unitprice1'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
      obQuantity: (json['obquantity'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemno': itemNo,
      'itemupc': itemUPC,
      'itemname': itemName,
      'itemname_short': itemNameShort,
      'categoryid': categoryId,
      'def_unitprice1': price,
      'obquantity': obQuantity,
      'notes': notes,
    };
  }
}
