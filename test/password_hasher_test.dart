import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/password_hasher.dart';

void main() {
  test('hash is deterministic for same password+salt', () {
    final salt = PasswordHasher.generateSalt();
    final a = PasswordHasher.hash('P@ssw0rd123', salt);
    final b = PasswordHasher.hash('P@ssw0rd123', salt);
    expect(a, b);
  });

  test('different passwords produce different hashes', () {
    final salt = PasswordHasher.generateSalt();
    expect(PasswordHasher.hash('a', salt), isNot(PasswordHasher.hash('b', salt)));
  });
}
