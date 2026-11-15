import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/users_dao.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/session_service.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late UsersDao dao;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTest();
    dao = UsersDao(db);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String?> sessionId() => SessionService().read();

  test('currentUserProvider is null with no session', () async {
    expect(await container.read(currentUserProvider.future), isNull);
    expect(container.read(isLoggedInProvider), false);
  });

  test('currentUserProvider is null when the session points to an unknown user',
      () async {
    await SessionService().save('missing-user');
    expect(await container.read(currentUserProvider.future), isNull);
    expect(container.read(isLoggedInProvider), false);
  });

  test('currentUserProvider returns the user from the saved session', () async {
    await dao.seedDefaultOwnerIfEmpty();
    await SessionService().save('admin');

    final user = await container.read(currentUserProvider.future);

    expect(user, isNotNull);
    expect(user!.id, 'admin');
    expect(user.username, 'admin');
    expect(user.role, 'owner');
    expect(user.active, true);
    expect(container.read(isLoggedInProvider), true);
  });

  test('login success saves the session and sets currentUserProvider', () async {
    await dao.seedDefaultOwnerIfEmpty();

    final ok = await container.read(loginProvider).login('admin', 'P@ssw0rd123');

    expect(ok, true);
    expect(await sessionId(), 'admin');
    final user = await container.read(currentUserProvider.future);
    expect(user?.username, 'admin');
    expect(container.read(isLoggedInProvider), true);
  });

  test('login with wrong password returns false and saves no session',
      () async {
    await dao.seedDefaultOwnerIfEmpty();

    final ok = await container.read(loginProvider).login('admin', 'salah');

    expect(ok, false);
    expect(await sessionId(), isNull);
    expect(await container.read(currentUserProvider.future), isNull);
    expect(container.read(isLoggedInProvider), false);
  });

  test('login with unknown username returns false', () async {
    await dao.seedDefaultOwnerIfEmpty();

    final ok = await container.read(loginProvider).login('tidak-ada', 'x');

    expect(ok, false);
    expect(await sessionId(), isNull);
  });

  test('login with a deactivated user returns false even with correct password',
      () async {
    final id = await dao.add(
      username: 'kasir1',
      password: 'pass123',
      role: 'kasir',
    );
    await dao.setActive(id, false);

    final ok = await container.read(loginProvider).login('kasir1', 'pass123');

    expect(ok, false);
    expect(await sessionId(), isNull);
    expect(await container.read(currentUserProvider.future), isNull);
  });

  test('currentUserProvider is null when a saved user is deactivated', () async {
    final id = await dao.add(
      username: 'kasir1',
      password: 'pass123',
      role: 'kasir',
    );
    await SessionService().save(id);
    await dao.setActive(id, false);

    expect(await container.read(currentUserProvider.future), isNull);
    expect(container.read(isLoggedInProvider), false);
  });

  test('logout clears the session and currentUserProvider', () async {
    await dao.seedDefaultOwnerIfEmpty();
    await container.read(loginProvider).login('admin', 'P@ssw0rd123');
    await container.read(currentUserProvider.future);
    expect(container.read(isLoggedInProvider), true);

    await container.read(loginProvider).logout();

    expect(await sessionId(), isNull);
    expect(await container.read(currentUserProvider.future), isNull);
    expect(container.read(isLoggedInProvider), false);
  });
}
