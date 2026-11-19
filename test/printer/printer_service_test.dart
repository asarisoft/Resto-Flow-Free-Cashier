import 'package:bluetooth_serial_next/bluetooth_serial_next.dart';
// ignore: implementation_imports
import 'package:bluetooth_serial_next/src/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/printer/printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBtHost extends BluetoothSerialHostApi {
  bool hasPermissionsResult = true;
  Object? openError;

  bool permissionChecked = false;
  final openedAddresses = <String>[];
  int _portId = 1;

  @override
  Future<void> reset() async {}

  @override
  Future<bool> hasPermissions(bool scan) async {
    permissionChecked = true;
    return hasPermissionsResult;
  }

  @override
  Future<NativeOpenResult> open(NativeOpenRequest request) async {
    final error = openError;
    if (error != null) throw error;
    openedAddresses.add(request.address);
    return NativeOpenResult(portId: _portId++, secure: false);
  }

  @override
  Future<void> close(int portId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBtHost host;
  late PrinterService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    host = _FakeBtHost();
    service = PrinterService(bluetooth: BluetoothSerial.withHostApi(host));
  });

  test('connect berhasil menyimpan address printer', () async {
    await service.connect(const BluetoothSerialDevice(address: 'AA:BB:CC'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('printer_address'), 'AA:BB:CC');
    expect(service.isConnected, isTrue);
  });

  test('disconnect menghapus address tersimpan', () async {
    await service.connect(const BluetoothSerialDevice(address: 'AA:BB:CC'));
    await service.disconnect();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('printer_address'), isNull);
    expect(service.isConnected, isFalse);
  });

  test('tryAutoConnect tidak membuka koneksi kalau address kosong', () async {
    await service.tryAutoConnect();

    expect(host.openedAddresses, isEmpty);
    expect(service.isConnected, isFalse);
  });

  test('tryAutoConnect tidak mencoba kalau izin Bluetooth belum diberikan',
      () async {
    SharedPreferences.setMockInitialValues({'printer_address': 'AA:BB:CC'});
    host.hasPermissionsResult = false;

    await service.tryAutoConnect();

    expect(host.openedAddresses, isEmpty);
    expect(service.isConnected, isFalse);
  });

  test('connect gagal saat start tidak melempar error', () async {
    SharedPreferences.setMockInitialValues({'printer_address': 'AA:BB:CC'});
    host.openError =
        const SerialException(SerialError.connectionFailed, 'printer mati');

    await service.tryAutoConnect();

    expect(service.isConnected, isFalse);
  });

  test('skenario kasir: app restart menyambung ulang printer terakhir',
      () async {
    await service.connect(const BluetoothSerialDevice(
        address: 'AA:BB:CC', name: 'Printer Dapur'));

    // "Restart": instance baru membaca address tersimpan lalu connect ulang.
    final restarted =
        PrinterService(bluetooth: BluetoothSerial.withHostApi(host));
    await restarted.tryAutoConnect();

    expect(restarted.isConnected, isTrue);
    expect(restarted.device?.address, 'AA:BB:CC');
    expect(host.openedAddresses, ['AA:BB:CC', 'AA:BB:CC']);
  });
}
