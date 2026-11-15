import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/expenses/expense_form_dialog.dart';

void main() {
  group('parseExpenseAmount', () {
    test('accepts a positive integer', () {
      expect(parseExpenseAmount('65000'), 65000);
    });

    test('trims surrounding whitespace', () {
      expect(parseExpenseAmount(' 25000 '), 25000);
    });

    test('rejects non-integer input', () {
      expect(parseExpenseAmount('12abc'), isNull);
      expect(parseExpenseAmount('12.500'), isNull);
      expect(parseExpenseAmount(''), isNull);
    });

    test('rejects negative and zero amounts', () {
      expect(parseExpenseAmount('-5000'), isNull);
      expect(parseExpenseAmount('0'), isNull);
    });
  });
}
