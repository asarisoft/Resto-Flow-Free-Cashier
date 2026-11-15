import 'dart:convert';

import 'package:crypto/crypto.dart';
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

  test('new hash uses pbkdf2 format', () {
    final h = PasswordHasher.hash('P@ssw0rd123', 'abcd');
    expect(h.startsWith('pbkdf2\$100000\$'), isTrue);
  });

  test('verify accepts right password, rejects wrong', () {
    final salt = PasswordHasher.generateSalt();
    final h = PasswordHasher.hash('secret-pass', salt);
    expect(PasswordHasher.verify('secret-pass', salt, h), isTrue);
    expect(PasswordHasher.verify('other-pass', salt, h), isFalse);
  });

  test('verify accepts legacy sha256(password+salt) hash', () {
    const salt = 'abcd';
    final legacy = sha256.convert(utf8.encode('P@ssw0rd123$salt')).toString();
    expect(PasswordHasher.verify('P@ssw0rd123', salt, legacy), isTrue);
    expect(PasswordHasher.verify('nope', salt, legacy), isFalse);
  });
}
