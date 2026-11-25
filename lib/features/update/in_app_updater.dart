import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/remote_config.dart';

/// Pembungkus `in_app_update` (mudah di-mock). Semua method: true = berhasil,
/// false = gagal / bukan dari Play Store.
class InAppUpdater {
  const InAppUpdater();

  Future<bool> immediate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      return await InAppUpdate.performImmediateUpdate() ==
          AppUpdateResult.success;
    } catch (_) {
      return false;
    }
  }

  Future<bool> flexible() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      return await InAppUpdate.startFlexibleUpdate() == AppUpdateResult.success;
    } catch (_) {
      return false;
    }
  }

  Future<void> complete() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {}
  }
}

final inAppUpdaterProvider = Provider<InAppUpdater>((ref) => const InAppUpdater());

Future<void> openPlayStore() async {
  try {
    await launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Wajib update: immediate; gagal -> buka Play Store.
Future<void> runRequiredUpdate(
  InAppUpdater updater, {
  Future<void> Function() fallback = openPlayStore,
}) async {
  if (!await updater.immediate()) await fallback();
}

/// Opsional: flexible; true = unduhan selesai & siap dipasang. Gagal -> diam.
Future<bool> runOptionalUpdate(InAppUpdater updater) => updater.flexible();
