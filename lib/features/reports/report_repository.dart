class ReportSummary {
  final int totalRevenue;
  final int totalProfit;
  final int totalExpense;
  final int transactionCount;
  final int averagePerTransaction;

  const ReportSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalExpense,
    required this.transactionCount,
    required this.averagePerTransaction,
  });

  int get netProfit => totalProfit - totalExpense;
}
