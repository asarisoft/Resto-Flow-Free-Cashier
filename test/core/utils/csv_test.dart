import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/utils/csv.dart';
import 'package:kasir_resto/features/expenses/expense_export.dart';
import 'package:kasir_resto/features/reports/report_export.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  group('buildCsv', () {
    test('starts with a BOM and uses CRLF line endings', () {
      final csv = buildCsv(['A', 'B'], [
        ['x', 1]
      ]);
      expect(csv.startsWith('﻿'), isTrue);
      expect(csv.substring(1), 'A,B\r\nx,1\r\n');
    });

    test('quotes cells with comma, quote or newline and doubles quotes', () {
      final csv = buildCsv(['A'], [
        ['a,b'],
        ['say "hi"'],
        ['line1\nline2'],
      ]);
      expect(csv, contains('"a,b"'));
      expect(csv, contains('"say ""hi"""'));
      expect(csv, contains('"line1\nline2"'));
    });

    test('neutralises spreadsheet formula injection in text cells', () {
      final csv = buildCsv(['A'], [
        ['=HYPERLINK("http://evil")'],
        ['+1+1'],
        ['-2+3'],
        ['@SUM(A1)'],
      ]);
      final rows = csv.substring(1).split('\r\n');
      expect(rows[1].startsWith("\"'=") || rows[1].startsWith("'="), isTrue, reason: rows[1]);
      expect(rows[2], "'+1+1");
      expect(rows[3], "'-2+3");
      expect(rows[4], "'@SUM(A1)");
    });

    test('negative numbers stay numeric (not treated as formulas)', () {
      final csv = buildCsv(['A'], [
        [-500]
      ]);
      expect(csv.substring(1), 'A\r\n-500\r\n');
    });

    test('null becomes an empty cell', () {
      expect(buildCsv(['A', 'B'], [
        [null, 'x']
      ]).substring(1), 'A,B\r\n,x\r\n');
    });
  });

  test('transactionsCsv has a row per transaction with int money and item summary', () {
    final txn = Transaction(
      number: 7,
      items: const [
        TransactionItem(productId: 'a', name: 'Nasi Goreng', price: 15000, hpp: 6000, qty: 2),
        TransactionItem(productId: 'b', name: 'Es Teh', price: 5000, hpp: 1000),
      ],
      subtotal: 35000,
      discount: 1000,
      total: 34000,
      paid: 50000,
      change: 16000,
      paymentMethod: 'qris',
      profit: 20000,
      createdAt: DateTime(2026, 11, 15, 10, 30),
    );
    final lines = transactionsCsv([txn]).substring(1).trim().split('\r\n');
    expect(lines.first, 'No,Tanggal,Metode,Item,Subtotal,Diskon,Total,Dibayar,Kembali,Laba');
    expect(lines[1], '7,2026-11-15 10:30,QRIS,Nasi Goreng x2; Es Teh x1,35000,1000,34000,50000,16000,20000');
  });

  test('expensesCsv has date, category, note, amount', () {
    final e = Expense(
        amount: 25000, category: 'Listrik', note: 'Token, bulan ini', date: DateTime(2026, 11, 1), createdAt: DateTime(2026, 11, 1));
    final lines = expensesCsv([e]).substring(1).trim().split('\r\n');
    expect(lines.first, 'Tanggal,Kategori,Catatan,Nominal');
    expect(lines[1], '2026-11-01,Listrik,"Token, bulan ini",25000');
  });
}
