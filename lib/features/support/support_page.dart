import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/config/remote_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';

const instagramUrl = 'https://www.instagram.com/ngodingdarirumah';
const tiktokUrl = 'https://www.tiktok.com/@ngodingdarirumah';

/// Bangun tampilan web. Dipanggil dengan callback status muat; bisa diganti di tes.
typedef SupportWebBuilder = Widget Function(
  BuildContext context, {
  required VoidCallback onLoaded,
  required VoidCallback onError,
});

/// Host sendiri -> izinkan di WebView; selain itu cegah & buka di luar app.
Future<NavigationDecision> decideSupportNavigation(
  String url, {
  Future<bool> Function(Uri) launcher = _launchExternal,
}) async {
  final uri = Uri.tryParse(url);
  // Hanya halaman Dukung tampil di WebView; landing & link lain dibuka di luar app.
  if (uri != null && _norm(uri) == _norm(Uri.parse(supportUrl))) {
    return NavigationDecision.navigate;
  }
  if (uri != null) {
    try {
      await launcher(uri);
    } catch (_) {}
  }
  return NavigationDecision.prevent;
}

Future<bool> _launchExternal(Uri u) =>
    launchUrl(u, mode: LaunchMode.externalApplication);

Widget _defaultWebBuilder(
  BuildContext context, {
  required VoidCallback onLoaded,
  required VoidCallback onError,
}) {
  final WebViewController controller;
  try {
    controller = _newController(onLoaded, onError);
  } catch (_) {
    // Platform WebView tidak tersedia -> konten lokal.
    WidgetsBinding.instance.addPostFrameCallback((_) => onError());
    return const SizedBox.shrink();
  }
  return WebViewWidget(controller: controller);
}

/// Hanya galat pada dokumen utama yang berarti gagal; resource lain (mis. favicon 404) diabaikan.
bool isMainDocumentError(Uri? requestUri) {
  if (requestUri == null) return false;
  return _norm(requestUri) == _norm(Uri.parse(supportUrl));
}

String _norm(Uri u) => u.removeFragment().toString().replaceFirst(RegExp(r'/$'), '');

WebViewController _newController(VoidCallback onLoaded, VoidCallback onError) {
  return WebViewController()
    ..setJavaScriptMode(JavaScriptMode.disabled)
    ..setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (r) => decideSupportNavigation(r.url),
      onPageFinished: (_) => onLoaded(),
      onWebResourceError: (e) {
        if (e.isForMainFrame ?? true) onError();
      },
      onHttpError: (e) {
        if ((e.response?.statusCode ?? 0) >= 400 &&
            isMainDocumentError(e.request?.uri)) {
          onError();
        }
      },
    ))
    ..loadRequest(Uri.parse(supportUrl));
}

/// Dukung Developer: halaman web; gagal muat/offline -> [SupportFallback].
class SupportPage extends StatefulWidget {
  final SupportWebBuilder webBuilder;
  const SupportPage({super.key, this.webBuilder = _defaultWebBuilder});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  bool _loading = true;
  bool _failed = false;
  Widget? _web;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dukung Developer'),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _failed
          ? const SupportFallback()
          : Stack(
              children: [
                // Dibuat sekali: membangun ulang = controller baru = muat ulang (kedip).
                _web ??= widget.webBuilder(
                  context,
                  onLoaded: () {
                    if (mounted) setState(() => _loading = false);
                  },
                  onError: () {
                    if (mounted) setState(() => _failed = true);
                  },
                ),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}

/// Konten Dukung lokal (dipakai saat web tidak bisa dimuat).
class SupportFallback extends StatelessWidget {
  const SupportFallback({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka tautan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme;
    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 40, 40),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Follow kami', style: t.titleMedium),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Instagram',
                      icon: AppIcons.instagram,
                      onPressed: () => _open(context, instagramUrl),
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      label: 'TikTok',
                      icon: AppIcons.tiktok,
                      onPressed: () => _open(context, tiktokUrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jasa Bikin Aplikasi', style: t.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Butuh aplikasi untuk usahamu? Kami bisa bantu buatkan.',
                      style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Hubungi via Instagram',
                      icon: AppIcons.instagram,
                      onPressed: () => _open(context, instagramUrl),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}
