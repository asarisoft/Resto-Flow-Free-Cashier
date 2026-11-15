import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_icons.dart';

void main() {
  test('size tokens', () {
    expect([AppIcons.sm, AppIcons.md, AppIcons.lg, AppIcons.xl, AppIcons.hero], [16, 20, 24, 32, 48]);
  });

  test('semantic icons come from the slim Lucide font', () {
    final all = <String, IconData>{
      'pos': AppIcons.pos, 'report': AppIcons.report, 'product': AppIcons.product,
      'expense': AppIcons.expense, 'users': AppIcons.users, 'settings': AppIcons.settings,
      'add': AppIcons.add, 'remove': AppIcons.remove, 'print': AppIcons.print,
      'backup': AppIcons.backup, 'restore': AppIcons.restore, 'login': AppIcons.login,
      'logout': AppIcons.logout, 'visible': AppIcons.visible, 'hidden': AppIcons.hidden,
    };
    all.forEach((name, icon) {
      expect(icon.fontFamily, startsWith('Lucide'), reason: name);
    });
  });

  test('no Material Icons.* left outside app_icons.dart', () {
    final re = RegExp(r'(^|[^A-Za-z])Icons\.');
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('app_icons.dart'))
        .where((f) => re.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty);
  });
}
