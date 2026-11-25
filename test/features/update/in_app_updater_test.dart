import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/update/in_app_updater.dart';

class _Fake extends InAppUpdater {
  final bool ok;
  int immediateCalls = 0;
  _Fake(this.ok);
  @override
  Future<bool> immediate() async {
    immediateCalls++;
    return ok;
  }
}

void main() {
  test('required memanggil immediate, sukses -> tanpa fallback', () async {
    final u = _Fake(true);
    var fell = false;
    await runRequiredUpdate(u, fallback: () async => fell = true);
    expect(u.immediateCalls, 1);
    expect(fell, isFalse);
  });

  test('required gagal -> buka Play Store', () async {
    final u = _Fake(false);
    var fell = false;
    await runRequiredUpdate(u, fallback: () async => fell = true);
    expect(fell, isTrue);
  });
}
