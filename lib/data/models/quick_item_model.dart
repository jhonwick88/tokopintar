class QuickItemModel {
  final String id;
  final String itemNo;
  final String itemName;
  final String? iconName;
  final String? colorHex;
  final int displayOrder;
  final bool isActive;

  QuickItemModel({
    required this.id,
    required this.itemNo,
    required this.itemName,
    this.iconName,
    this.colorHex,
    required this.displayOrder,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_no': itemNo,
      'item_name': itemName,
      'icon_name': iconName,
      'color_hex': colorHex,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }

  factory QuickItemModel.fromJson(Map<String, dynamic> json) {
    return QuickItemModel(
      id: json['id'] as String? ?? '',
      itemNo: json['item_no'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      iconName: json['icon_name'] as String?,
      colorHex: json['color_hex'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  QuickItemModel copyWith({
    String? id,
    String? itemNo,
    String? itemName,
    String? iconName,
    String? colorHex,
    int? displayOrder,
    bool? isActive,
  }) {
    return QuickItemModel(
      id: id ?? this.id,
      itemNo: itemNo ?? this.itemNo,
      itemName: itemName ?? this.itemName,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}
