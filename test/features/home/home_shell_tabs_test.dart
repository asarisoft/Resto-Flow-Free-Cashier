import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/home/home_shell.dart';

void main() {
  test('kasir only sees Pos and Products tabs', () {
    final tabs = visibleHomeTabs(
      canReports: false,
      canSettings: false,
      canUsers: false,
      canExpenses: false,
    );
    expect(tabs, [HomeTab.pos, HomeTab.products]);
  });

  test('owner sees every tab', () {
    final tabs = visibleHomeTabs(
      canReports: true,
      canSettings: true,
      canUsers: true,
      canExpenses: true,
    );
    expect(tabs, HomeTab.values);
  });

  test('expenses tab sits right after products', () {
    final tabs = visibleHomeTabs(
      canReports: false,
      canSettings: false,
      canUsers: false,
      canExpenses: true,
    );
    expect(tabs, [HomeTab.pos, HomeTab.products, HomeTab.expenses]);
  });

  test('optional tabs follow their own permission flag', () {
    final tabs = visibleHomeTabs(
      canReports: false,
      canSettings: true,
      canUsers: false,
      canExpenses: false,
    );
    expect(tabs, [HomeTab.pos, HomeTab.products, HomeTab.settings]);
  });
}
