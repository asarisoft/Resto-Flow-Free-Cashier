# Landing Page KasirKita (kasirkita.asdev.id) — Plan

**Goal:** Satu halaman promosi statis yang membuat pemilik UMKM klik "Download di Google Play".

**Domain:** subdomain `kasirkita.asdev.id` (DNS CNAME ke Cloudflare Workers/Pages). Satu situs: landing `/`, `/privasi`, `/dukung` (WebView app), `/version.json` (cek versi). `web_netlify/` dihapus; `remoteBaseUrl` app = `https://kasirkita.asdev.id`.

**Tech:** HTML + CSS statis (tanpa framework), GSAP + Lenis, hosting Cloudflare Pages (Workers tidak bisa CNAME dari DNS luar). Folder baru `web_landing/`.

**Gaya:** Soft Clay sama dengan app & screenshot Play Store (krem, peach, mint, butter, lilac, oranye `#C2410C`; Outfit + Work Sans). Maskot dari `assets/images/login_hero.webp`.

## Global Constraints
- Bahasa Indonesia, ramah UMKM, tanpa jargon.
- Tanpa tracker pihak ketiga; analytics opsional Cloudflare Web Analytics (tanpa cookie).
- Lighthouse mobile ≥ 90 (performa, aksesibilitas, SEO). Kontras teks ≥ 4.5:1.
- Lebar HP 360px tanpa scroll samping.
- Tombol utama: link Play Store `https://play.google.com/store/apps/details?id=id.asdev.kasirkita`.
- Klaim harus benar: gratis, offline, data di HP, backup manual. Jangan janji cloud sync.

## Struktur halaman
1. **Hero** — maskot + "Kasir gratis untuk warung & cafe", sub "Bisa offline. Data aman di HP Anda.", tombol Google Play, mockup HP slide Kasir.
2. **Masalah → solusi** — 3 kartu: catat manual ribet / aplikasi kasir mahal / takut internet mati.
3. **Fitur** (grid 6): kasir cepat & cari produk, struk Bluetooth 58/80mm, laporan omzet & laba, pengeluaran & shift, multi user Owner/Kasir, backup & pindah HP.
4. **Tablet juga bisa** — screenshot tablet Kasir/Laporan.
5. **Cara mulai** (3 langkah nyata): install → buat akun Owner → isi menu & mulai jualan.
6. **FAQ**: benar gratis? perlu internet? data disimpan di mana? ganti HP gimana? printer apa yang didukung? bisa request fitur?
7. **CTA akhir** + footer: ASDEV.id, Instagram/TikTok @ngodingdarirumah, Kebijakan Privasi, Dukung Developer.

## Tasks
- [x] **1. Kebijakan privasi** `web_landing/privacy.html` (wajib Play Store): data hanya lokal, izin Bluetooth/penyimpanan/kamera-galeri, cek koneksi hanya ke `version.json`, kontak.
- [x] **2. Aset**: ekspor gambar dari editor screenshot Play Store (hero HP, 2 tablet) ke WebP ≤ 150KB; favicon dari `app_logo`; OG image 1200×630.
- [x] **3. Halaman** `web_landing/index.html` sesuai struktur; meta SEO (title "KasirKita – Aplikasi Kasir Gratis & Offline untuk UMKM", description ≤ 155 char, OG/Twitter card, JSON-LD `SoftwareApplication` dengan harga 0).
- [x] **3b. SEO / AEO / GEO** (mockup v6 sudah memuat poin 1–4):
  1. Kata kunci utama: "aplikasi kasir gratis", "kasir offline", "aplikasi kasir android", "aplikasi kasir UMKM/warung/cafe", "POS gratis", "cetak struk bluetooth". Pakai alami di H1, H2, deskripsi, alt gambar.
  2. Blok definisi "Apa itu KasirKita?" (1 kalimat jawaban langsung + tabel fakta) — mudah dikutip AI/answer engine.
  3. JSON-LD `@graph`: Organization (ASDEV.id + sameAs IG/TikTok), SoftwareApplication (harga 0 IDR, featureList, downloadUrl), HowTo (3 langkah), FAQPage (pertanyaan lengkap berisi nama brand).
  4. Meta description ≤155, canonical, OG/Twitter, `lang="id"`.
  5. `robots.txt` (izinkan GPTBot, ClaudeBot, PerplexityBot, Google-Extended), `sitemap.xml`, `llms.txt` (ringkasan fakta app + link).
  6. Daftarkan di Google Search Console + Bing Webmaster; uji Rich Results Test.
- [x] **4. `_headers`**: cache panjang untuk gambar, CSP ketat, `X-Content-Type-Options`.
- [ ] **5. Deploy**: Cloudflare Pages project `kasirkita-landing`, custom domain `kasirkita.asdev.id`, cek HTTPS.
- [ ] **6. QA**: Lighthouse mobile, uji 360px & desktop, semua link (Play Store, IG, TikTok, privacy) jalan.
- [ ] **7. Isi URL privacy** di Play Console + `docs/SPEC.md`.

## Keputusan yang perlu user
1. ~~Pindah Dukung + version.json~~ → ya, sudah (domain harus aktif sebelum rilis app).
2. ~~Hosting~~ → Cloudflare Pages + CNAME Biznet Gio.
3. ~~Tombol Play~~ → popup "Sedang ditinjau Google Play" (`PLAY_LIVE=false` di index.html).
