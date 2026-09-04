class ItemModel {
  final String itemNo;
  final String itemUPC;
  final String itemName;
  final String itemNameShort;
  final int categoryId;
  final double price; // mapped to def_unitprice1
  final double obQuantity;
  final String notes;
  final String attribute;
  final String unit1;
  final String unit2;
  final String unit3;
  final double ratio2;
  final double ratio3;
  final double defUnitPrice2;
  final double defUnitPrice3;

  ItemModel({
    required this.itemNo,
    required this.itemUPC,
    required this.itemName,
    this.itemNameShort = '',
    required this.categoryId,
    required this.price,
    this.obQuantity = 10.0,
    this.notes = '',
    this.attribute = '',
    this.unit1 = '',
    this.unit2 = '',
    this.unit3 = '',
    this.ratio2 = 0.0,
    this.ratio3 = 0.0,
    this.defUnitPrice2 = 0.0,
    this.defUnitPrice3 = 0.0,
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
      attribute: json['attribute'] as String? ?? '',
      unit1: json['unit1'] as String? ?? '',
      unit2: json['unit2'] as String? ?? '',
      unit3: json['unit3'] as String? ?? '',
      ratio2: (json['ratio2'] as num?)?.toDouble() ?? 0.0,
      ratio3: (json['ratio3'] as num?)?.toDouble() ?? 0.0,
      defUnitPrice2: (json['def_unitprice2'] as num?)?.toDouble() ?? 0.0,
      defUnitPrice3: (json['def_unitprice3'] as num?)?.toDouble() ?? 0.0,
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
      'attribute': attribute,
      'unit1': unit1,
      'unit2': unit2,
      'unit3': unit3,
      'ratio2': ratio2,
      'ratio3': ratio3,
      'def_unitprice2': defUnitPrice2,
      'def_unitprice3': defUnitPrice3,
    };
  }

  ItemModel copyWith({
    String? itemNo,
    String? itemUPC,
    String? itemName,
    String? itemNameShort,
    int? categoryId,
    double? price,
    double? obQuantity,
    String? notes,
    String? attribute,
    String? unit1,
    String? unit2,
    String? unit3,
    double? ratio2,
    double? ratio3,
    double? defUnitPrice2,
    double? defUnitPrice3,
  }) {
    return ItemModel(
      itemNo: itemNo ?? this.itemNo,
      itemUPC: itemUPC ?? this.itemUPC,
      itemName: itemName ?? this.itemName,
      itemNameShort: itemNameShort ?? this.itemNameShort,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      obQuantity: obQuantity ?? this.obQuantity,
      notes: notes ?? this.notes,
      attribute: attribute ?? this.attribute,
      unit1: unit1 ?? this.unit1,
      unit2: unit2 ?? this.unit2,
      unit3: unit3 ?? this.unit3,
      ratio2: ratio2 ?? this.ratio2,
      ratio3: ratio3 ?? this.ratio3,
      defUnitPrice2: defUnitPrice2 ?? this.defUnitPrice2,
      defUnitPrice3: defUnitPrice3 ?? this.defUnitPrice3,
    );
  }
}
