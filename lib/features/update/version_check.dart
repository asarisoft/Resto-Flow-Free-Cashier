import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/remote_config.dart';

enum UpdateStatus { ok, optional, required }

class RemoteVersion {
  final int minVersionCode;
  final int latestVersionCode;
  final String message;

  const RemoteVersion({
    required this.minVersionCode,
    required this.latestVersionCode,
    required this.message,
  });

  /// Field hilang / tipe salah / bukan map -> null (dianggap tidak ada update).
  static RemoteVersion? tryParse(Object? json) {
    if (json is! Map) return null;
    final min = json['min_version_code'];
    final latest = json['latest_version_code'];
    if (min is! int || latest is! int) return null;
    final msg = json['message'];
    return RemoteVersion(
      minVersionCode: min,
      latestVersionCode: latest,
      message: msg is String ? msg : '',
    );
  }
}

UpdateStatus decideUpdate(int current, RemoteVersion? remote) {
  if (remote == null) return UpdateStatus.ok;
  if (current < remote.minVersionCode) return UpdateStatus.required;
  if (current < remote.latestVersionCode) return UpdateStatus.optional;
  return UpdateStatus.ok;
}

/// versionCode app saat ini (buildNumber). Gagal baca -> 0 tidak dipakai; lempar.
final currentVersionCodeProvider = FutureProvider<int>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return int.parse(info.buildNumber);
});

/// Ambil version.json; error apa pun / timeout 5 dtk -> null (offline-first).
final remoteVersionProvider = FutureProvider<RemoteVersion?>((ref) async {
  try {
    final res = await http
        .get(Uri.parse('$remoteBaseUrl/version.json'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    return RemoteVersion.tryParse(jsonDecode(res.body));
  } catch (_) {
    return null;
  }
});

/// Hasil keputusan + pesan. Gagal apa pun -> ok.
final updateDecisionProvider =
    FutureProvider<({UpdateStatus status, String message})>((ref) async {
  try {
    final remote = await ref.watch(remoteVersionProvider.future);
    final current = await ref.watch(currentVersionCodeProvider.future);
    return (status: decideUpdate(current, remote), message: remote?.message ?? '');
  } catch (_) {
    return (status: UpdateStatus.ok, message: '');
  }
});
