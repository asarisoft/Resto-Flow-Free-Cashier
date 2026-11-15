import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/daos/profile_dao.dart';
import 'package:kasir_resto/models/resto_profile.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());
  test('get returns null before any save', () async {
    expect(await ProfileDao(db).get(), isNull);
  });
  test('save then get round-trips the profile', () async {
    final dao = ProfileDao(db);
    await dao.save(RestoProfile(name: 'Warung A', createdAt: DateTime.now()));
    expect((await dao.get())!.name, 'Warung A');
  });
}
