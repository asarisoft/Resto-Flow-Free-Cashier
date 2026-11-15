import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/models/app_user.dart';

void main() {
  test('Role.fromDb round-trips', () {
    expect(Role.fromDb('owner'), Role.owner);
    expect(Role.owner.toDb(), 'owner');
  });
  test('AppUser.roleEnum reflects stored role string', () {
    final u = AppUser(id: '1', username: 'admin', role: 'owner', active: true);
    expect(u.roleEnum, Role.owner);
  });
}

