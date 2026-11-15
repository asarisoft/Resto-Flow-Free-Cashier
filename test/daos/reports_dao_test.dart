import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/daos/reports_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/models/transaction.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());
  test('sumRevenue and sumProfit sum only transactions in range', () async {
    final sales = SalesDao(db);
    final reports = ReportsDao(db);
    final n1 = await sales.getNextNumber();
    await sales.save(Transaction(number: n1, items: [], subtotal: 100, total: 100, paid: 100, profit: 40, createdAt: DateTime.now()));
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1));
    final end = now.add(const Duration(days: 1));
    expect(await reports.sumRevenue(start, end), 100);
    expect(await reports.sumProfit(start, end), 40);
    expect(await reports.countTransactions(start, end), 1);
  });
}
