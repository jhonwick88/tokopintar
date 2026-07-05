class ItemModel {
  final String itemNo;
  final String itemUPC;
  final String itemName;
  final int categoryId;
  final double price;
  final double obQuantity;

  ItemModel({
    required this.itemNo,
    required this.itemUPC,
    required this.itemName,
    required this.categoryId,
    required this.price,
    this.obQuantity = 10.0,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      itemNo: json['itemno'] as String? ?? '',
      itemUPC: json['itemupc'] as String? ?? '',
      itemName: json['itemname'] as String? ?? '',
      categoryId: json['categoryid'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      obQuantity: (json['obquantity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemno': itemNo,
      'itemupc': itemUPC,
      'itemname': itemName,
      'categoryid': categoryId,
      'price': price,
      'obquantity': obQuantity,
    };
  }
}
