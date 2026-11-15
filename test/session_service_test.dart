import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read returns null when no session saved', () async {
    expect(await SessionService().read(), isNull);
  });

  test('save then read returns the saved id; clear removes it', () async {
    final svc = SessionService();
    await svc.save('u1');
    expect(await svc.read(), 'u1');
    await svc.clear();
    expect(await svc.read(), isNull);
  });

  test('save overwrites the previous session id', () async {
    final svc = SessionService();
    await svc.save('u1');
    await svc.save('u2');
    expect(await svc.read(), 'u2');
  });

  test('session is stored under the session_user_id key', () async {
    final svc = SessionService();
    await svc.save('u1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_user_id'), 'u1');
  });
}
