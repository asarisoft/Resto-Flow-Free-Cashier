class Shift {
  final String id;
  final DateTime openedAt;
  final String openedBy;
  final int openingCash;
  final DateTime? closedAt;
  final String? closedBy;
  final int? countedCash;
  final int? expectedCash;

  const Shift({
    required this.id,
    required this.openedAt,
    required this.openedBy,
    required this.openingCash,
    this.closedAt,
    this.closedBy,
    this.countedCash,
    this.expectedCash,
  });

  bool get isOpen => closedAt == null;
}
