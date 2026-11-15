class ReportSummary {
  final int totalRevenue;
  final int totalProfit;
  final int transactionCount;
  final int averagePerTransaction;

  const ReportSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.transactionCount,
    required this.averagePerTransaction,
  });
}
