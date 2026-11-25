# Landing Page KasirKita (kasirkita.asdev.id) — Plan

**Goal:** Satu halaman promosi statis yang membuat pemilik UMKM klik "Download di Google Play".

**Domain:** subdomain `kasirkita.asdev.id` (DNS CNAME ke Cloudflare Workers/Pages). Halaman Dukung (`web_netlify/index.html`, dipakai WebView app) dan `version.json` TIDAK dipindah; tetap di URL `remoteBaseUrl` sekarang, kecuali diputuskan lain (lihat Keputusan).

**Tech:** HTML + CSS statis satu file (tanpa framework), gambar WebP, hosting Cloudflare Pages. Folder baru `web_landing/`.

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
- [ ] **1. Kebijakan privasi** `web_landing/privacy.html` (wajib Play Store): data hanya lokal, izin Bluetooth/penyimpanan/kamera-galeri, cek koneksi hanya ke `version.json`, kontak.
- [ ] **2. Aset**: ekspor gambar dari editor screenshot Play Store (hero HP, 2 tablet) ke WebP ≤ 150KB; favicon dari `app_logo`; OG image 1200×630.
- [ ] **3. Halaman** `web_landing/index.html` sesuai struktur; meta SEO (title "KasirKita – Aplikasi Kasir Gratis & Offline untuk UMKM", description ≤ 155 char, OG/Twitter card, JSON-LD `SoftwareApplication` dengan harga 0).
- [ ] **3b. SEO / AEO / GEO** (mockup v6 sudah memuat poin 1–4):
  1. Kata kunci utama: "aplikasi kasir gratis", "kasir offline", "aplikasi kasir android", "aplikasi kasir UMKM/warung/cafe", "POS gratis", "cetak struk bluetooth". Pakai alami di H1, H2, deskripsi, alt gambar.
  2. Blok definisi "Apa itu KasirKita?" (1 kalimat jawaban langsung + tabel fakta) — mudah dikutip AI/answer engine.
  3. JSON-LD `@graph`: Organization (ASDEV.id + sameAs IG/TikTok), SoftwareApplication (harga 0 IDR, featureList, downloadUrl), HowTo (3 langkah), FAQPage (pertanyaan lengkap berisi nama brand).
  4. Meta description ≤155, canonical, OG/Twitter, `lang="id"`.
  5. `robots.txt` (izinkan GPTBot, ClaudeBot, PerplexityBot, Google-Extended), `sitemap.xml`, `llms.txt` (ringkasan fakta app + link).
  6. Daftarkan di Google Search Console + Bing Webmaster; uji Rich Results Test.
- [ ] **4. `_headers`**: cache panjang untuk gambar, CSP ketat, `X-Content-Type-Options`.
- [ ] **5. Deploy**: Cloudflare Pages project `kasirkita-landing`, custom domain `kasirkita.asdev.id`, cek HTTPS.
- [ ] **6. QA**: Lighthouse mobile, uji 360px & desktop, semua link (Play Store, IG, TikTok, privacy) jalan.
- [ ] **7. Isi URL privacy** di Play Console + `docs/SPEC.md`.

## Keputusan yang perlu user
1. Pindahkan juga halaman Dukung + `version.json` ke `kasirkita.asdev.id`? (Kalau ya: `remoteBaseUrl` di app berubah → harus rilis sebelum go-live, URL lama tetap hidup untuk versi lama.)
2. Hosting: Cloudflare Pages (saran) atau Netlify?
3. Tombol Play Store aktif sebelum app live? (Saran: "Segera hadir" sampai listing tayang.)
