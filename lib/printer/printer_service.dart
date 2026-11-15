import 'dart:async';
import 'dart:typed_data';
import 'package:bluetooth_serial_next/bluetooth_serial_next.dart';

class PrinterService {
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
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _device = null;
    _connection = null;
  }

  Future<void> printBytes(List<int> bytes) async {
    final port = _connection;
    if (port == null || !port.isOpen) {
      throw Exception('Printer tidak terhubung');
    }
    await port.write(Uint8List.fromList(bytes));
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
