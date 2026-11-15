class Expense {
  final String? id;
  final String? category;
  final String? note;
  final int amount;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    this.id,
    this.category,
    this.note,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  Expense copyWith({
    String? id,
    String? category,
    String? note,
    int? amount,
    DateTime? date,
    DateTime? createdAt,
  }) =>
      Expense(
        id: id ?? this.id,
        category: category ?? this.category,
        note: note ?? this.note,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        createdAt: createdAt ?? this.createdAt,
      );
}
