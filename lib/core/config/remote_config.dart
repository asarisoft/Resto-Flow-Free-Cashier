/// Situs KasirKita (landing, /dukung, /version.json) di Cloudflare Pages.
/// Bisa diganti saat run untuk testing: --dart-define=REMOTE_BASE_URL=https://...
const remoteBaseUrl = String.fromEnvironment('REMOTE_BASE_URL',
    defaultValue: 'https://kasirkita.asdev.id');

/// Halaman Dukung Developer yang dibuka WebView.
const supportUrl = '$remoteBaseUrl/dukung';

const playStoreUrl =
    'https://play.google.com/store/apps/details?id=id.asdev.kasirkita';
