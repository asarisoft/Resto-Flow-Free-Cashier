/// Situs Kasir Ceria (landing, /dukung, /version.json) di Cloudflare Pages (kasirceria.pages.dev).
/// Bisa diganti saat run untuk testing: --dart-define=REMOTE_BASE_URL=https://...
const remoteBaseUrl = String.fromEnvironment('REMOTE_BASE_URL',
    defaultValue: 'https://kasirceria.pages.dev');

/// Halaman Dukung Developer yang dibuka WebView.
const supportUrl = '$remoteBaseUrl/dukung';

const playStoreUrl =
    'https://play.google.com/store/apps/details?id=id.asdev.kasirceria';
