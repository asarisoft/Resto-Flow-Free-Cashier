import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/reports/transaction_detail_dialog.dart';
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:kasir_resto/printer/receipt_builder.dart';

void main() {
  final profile = RestoProfile(name: 'Warung Bapak', createdAt: DateTime(2026, 1, 1));

  Transaction txn({String status = 'paid'}) => Transaction(
        number: 7,
        items: const [
          TransactionItem(
              productId: 'p', name: 'Nasi Goreng', price: 15000, hpp: 6000, qty: 2),
        ],
        subtotal: 30000,
        total: 30000,
        paid: 30000,
        profit: 12000,
        status: status,
        voidReason: status == 'void' ? 'salah input' : null,
        createdAt: DateTime(2026, 11, 20, 10, 30),
      );

  group('ReceiptBuilder.shareText', () {
    test('dibungkus ``` (monospace WhatsApp) dan isinya sama dengan struk', () {
      final t = txn();
      final text = ReceiptBuilder.shareText(t, profile);

      expect(text.startsWith('```\n'), true);
      expect(text.endsWith('\n```'), true);
      final inner = text.substring(4, text.length - 4);
      expect(inner, ReceiptBuilder.buildText(t, profile).trimRight());
      expect(inner, contains('WARUNG BAPAK')); // nama resto dicetak kapital
      expect(inner, contains('Nasi Goreng'));
      expect(inner, contains('TOTAL'));
    });

    test('transaksi batal membawa penanda DIBATALKAN', () {
      expect(ReceiptBuilder.shareText(txn(status: 'void'), profile),
          contains('DIBATALKAN'));
    });
  });

  group('TransactionDetailDialog', () {
    Future<void> pump(WidgetTester tester, {VoidCallback? onShare}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) => TransactionDetailDialog(
                    txn: txn(), onReprint: () {}, onShare: onShare),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
    }

    testWidgets('tombol Bagikan tampil dan memanggil onShare', (tester) async {
      var shared = 0;
      await pump(tester, onShare: () => shared++);
      expect(find.text('Bagikan (WhatsApp)'), findsOneWidget);

      await tester.tap(find.text('Bagikan (WhatsApp)'));
      expect(shared, 1);
    });

    testWidgets('tanpa onShare tombol Bagikan tidak tampil', (tester) async {
      await pump(tester);
      expect(find.text('Bagikan (WhatsApp)'), findsNothing);
      expect(find.text('Cetak ulang'), findsOneWidget);
    });
  });
}
