import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  const PasswordHasher._();

  static const _iterations = 100000;
  static const _prefix = 'pbkdf2\$$_iterations\$';

  static String generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// PBKDF2-HMAC-SHA256, 32-byte output (one block), format `pbkdf2$100000$<hex>`.
  static String hash(String password, String salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var u = hmac.convert([...utf8.encode(salt), 0, 0, 0, 1]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    final hex = t.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$_prefix$hex';
  }

  /// Accepts PBKDF2 hashes and legacy `sha256(password+salt)` hashes.
  static bool verify(String password, String salt, String stored) {
    final expected = stored.startsWith(_prefix) ? hash(password, salt) : _legacy(password, salt);
    return _constantTimeEquals(expected, stored);
  }

  static bool isLegacy(String stored) => !stored.startsWith(_prefix);

  static String _legacy(String password, String salt) =>
      sha256.convert(utf8.encode('$password$salt')).toString();

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
