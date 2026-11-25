import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/remote_config.dart';

enum UpdateStatus { ok, optional, required }

enum UpdateLevel { info, critical }

String _clip(Object? v, int max) {
  if (v is! String) return '';
  final t = v.trim();
  return t.length > max ? t.substring(0, max) : t;
}

class RemoteVersion {
  final int minVersionCode;
  final int latestVersionCode;
  final String message;
  final UpdateLevel level;
  final String title;
  final String changesTitle;
  final List<String> changes;

  const RemoteVersion({
    required this.minVersionCode,
    required this.latestVersionCode,
    required this.message,
    this.level = UpdateLevel.info,
    this.title = '',
    this.changesTitle = '',
    this.changes = const [],
  });

  /// Field hilang / tipe salah / bukan map -> null (dianggap tidak ada update).
  /// Field tambahan opsional: salah tipe -> default; teks dipotong (teks polos).
  static RemoteVersion? tryParse(Object? json) {
    if (json is! Map) return null;
    final min = json['min_version_code'];
    final latest = json['latest_version_code'];
    if (min is! int || latest is! int) return null;
    final raw = json['changes'];
    final changes = raw is List
        ? raw
            .whereType<String>()
            .map((e) => _clip(e, 80))
            .where((e) => e.isNotEmpty)
            .take(5)
            .toList()
        : <String>[];
    return RemoteVersion(
      minVersionCode: min,
      latestVersionCode: latest,
      message: _clip(json['message'], 300),
      level: json['level'] == 'critical' ? UpdateLevel.critical : UpdateLevel.info,
      title: _clip(json['title'], 60),
      changesTitle: _clip(json['changes_title'], 40),
      changes: changes,
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

/// Hasil keputusan + isi layar update. Gagal apa pun -> ok.
class UpdateDecision {
  final UpdateStatus status;
  final RemoteVersion? remote;
  const UpdateDecision(this.status, [this.remote]);

  String get message => remote?.message ?? '';
}

final updateDecisionProvider = FutureProvider<UpdateDecision>((ref) async {
  try {
    final remote = await ref.watch(remoteVersionProvider.future);
    final current = await ref.watch(currentVersionCodeProvider.future);
    return UpdateDecision(decideUpdate(current, remote), remote);
  } catch (_) {
    return const UpdateDecision(UpdateStatus.ok);
  }
});

/// Info versi app terpasang (nama + build). Bisa dioverride di tes.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());
