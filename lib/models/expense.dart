class Expense {
  final int? id;
  final double amount;
  final int categoryId;
  final DateTime date;
  final String? note;

  Expense({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      categoryId: (map['categoryId'] ?? map['category_id'] ?? 1) as int,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }
}