class SupplierModel {
  final int? id;
  final String name;
  final String contactInfo;
  final String address;
  final String notes;

  SupplierModel({
    this.id,
    required this.name,
    this.contactInfo = '',
    this.address = '',
    this.notes = '',
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      contactInfo: json['contact_info'] as String? ?? '',
      address: json['address'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'contact_info': contactInfo,
      'address': address,
      'notes': notes,
    };
  }

  SupplierModel copyWith({
    int? id,
    String? name,
    String? contactInfo,
    String? address,
    String? notes,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      contactInfo: contactInfo ?? this.contactInfo,
      address: address ?? this.address,
      notes: notes ?? this.notes,
    );
  }
}
