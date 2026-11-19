import 'dart:async';
import 'dart:convert';
import 'package:bluetooth_serial_next/bluetooth_serial_next.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One shared printer connection for the whole app.
final printerServiceProvider = ChangeNotifierProvider<PrinterService>((ref) => PrinterService());

class PrinterService extends ChangeNotifier {
  BluetoothSerialDevice? _device;
  BluetoothSerialPort? _connection;

  BluetoothSerialDevice? get device => _device;
  bool get isConnected => _connection?.isOpen ?? false;

  Future<List<BluetoothSerialDevice>> scan() async {
    final bt = BluetoothSerial.instance;
    if (!await bt.requestPermissions(scan: true)) {
      throw Exception('Izin Bluetooth ditolak');
    }
    if (!await bt.requestEnable()) {
      throw Exception('Bluetooth tidak aktif');
    }
    return bt.discover().toList();
  }

  Future<void> connect(BluetoothSerialDevice device) async {
    final port = await BluetoothSerial.instance.open(device.address);
    _connection = port;
    _device = device;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _device = null;
    _connection = null;
    notifyListeners();
  }

  Future<void> printBytes(List<int> bytes) async {
    final port = _connection;
    if (port == null || !port.isOpen) {
      throw Exception('Printer tidak terhubung');
    }
    await port.write(Uint8List.fromList(bytes));
  }

  Future<void> printTest() => printBytes([...utf8.encode('Resto Flow\n'), 10, 10, 10]);

  @override
  void dispose() {
    _connection?.close();
    super.dispose();
  }
}
