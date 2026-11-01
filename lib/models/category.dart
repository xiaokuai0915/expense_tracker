class ExpenseCategory {
  final int? id;
  final String name;
  final String iconName;
  final String colorHex;

  ExpenseCategory({
    this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'iconName': iconName,
      'colorHex': colorHex,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconName: map['iconName'] ?? map['icon_name'] ?? 'category',
      colorHex: map['colorHex'] ?? map['color_hex'] ?? '#9E9E9E',
    );
  }
}