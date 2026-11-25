import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/config/remote_config.dart';
import 'package:kasir_resto/features/support/support_page.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  test('isMainDocumentError: hanya dokumen utama', () {
    expect(isMainDocumentError(Uri.parse('$remoteBaseUrl/favicon.ico')), isFalse);
    expect(isMainDocumentError(Uri.parse('$remoteBaseUrl/')), isTrue);
    expect(isMainDocumentError(Uri.parse(remoteBaseUrl)), isTrue);
    expect(isMainDocumentError(null), isFalse);
  });

  testWidgets('web gagal dimuat -> konten lokal tampil', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SupportPage(
        webBuilder: (context, {required onLoaded, required onError}) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onError());
          return const SizedBox.shrink();
        },
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SupportFallback), findsOneWidget);
    expect(find.text('Follow kami'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Jasa Bikin Aplikasi'), findsOneWidget);
    expect(find.text('Hubungi via Instagram'), findsOneWidget);
  });

  testWidgets('web dibuat sekali, tidak dibuat ulang setelah selesai muat (anti kedip)', (tester) async {
    var builds = 0;
    late VoidCallback done;
    await tester.pumpWidget(MaterialApp(
      home: SupportPage(
        webBuilder: (context, {required onLoaded, required onError}) {
          builds++;
          done = onLoaded;
          return const Text('web');
        },
      ),
    ));
    done();
    await tester.pump();
    await tester.pump();
    expect(builds, 1);
  });

  testWidgets('saat memuat tampil indikator, selesai -> hilang', (tester) async {
    late VoidCallback done;
    await tester.pumpWidget(MaterialApp(
      home: SupportPage(
        webBuilder: (context, {required onLoaded, required onError}) {
          done = onLoaded;
          return const Text('web');
        },
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    done();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SupportFallback), findsNothing);
  });

  test('navigasi: host sendiri izinkan, instagram dicegah & dibuka luar', () async {
    final launched = <Uri>[];
    Future<bool> fake(Uri u) async {
      launched.add(u);
      return true;
    }

    expect(
      await decideSupportNavigation('https://kasirkita.asdeveloper-id.workers.dev/',
          launcher: fake),
      NavigationDecision.navigate,
    );
    expect(launched, isEmpty);

    expect(
      await decideSupportNavigation('https://instagram.com/asdev.id',
          launcher: fake),
      NavigationDecision.prevent,
    );
    expect(launched.single.host, 'instagram.com');
  });
}
