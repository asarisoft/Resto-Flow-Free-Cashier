import 'dart:async';
import 'dart:convert';
import 'package:bluetooth_serial_next/bluetooth_serial_next.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One shared printer connection for the whole app.
final printerServiceProvider = ChangeNotifierProvider<PrinterService>((ref) => PrinterService());

class PrinterService extends ChangeNotifier {
  PrinterService({BluetoothSerial? bluetooth})
      : _bluetooth = bluetooth ?? BluetoothSerial.instance;

  static const _savedAddressKey = 'printer_address';

  final BluetoothSerial _bluetooth;
  BluetoothSerialDevice? _device;
  BluetoothSerialPort? _connection;

  BluetoothSerialDevice? get device => _device;
  bool get isConnected => _connection?.isOpen ?? false;

  Future<List<BluetoothSerialDevice>> scan() async {
    if (!await _bluetooth.requestPermissions(scan: true)) {
      throw Exception('Izin Bluetooth ditolak');
    }
    if (!await _bluetooth.requestEnable()) {
      throw Exception('Bluetooth tidak aktif');
    }
    return _bluetooth.discover().toList();
  }

  Future<void> connect(BluetoothSerialDevice device) async {
    final port = await _bluetooth.open(device.address);
    _connection = port;
    _device = device;
    await _saveAddress(device.address);
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _device = null;
    _connection = null;
    await _clearAddress();
    notifyListeners();
  }

  /// Coba sambung diam-diam ke printer terakhir saat app start.
  /// Tidak blokir UI; tanpa izin / tanpa address / gagal = abaikan (log saja).
  Future<void> tryAutoConnect() async {
    try {
      if (!await _bluetooth.hasPermissions()) return;
      final address = await _readAddress();
      if (address == null || address.isEmpty) return;
      final port = await _bluetooth.open(address, requestPermission: false);
      _connection = port;
      _device = BluetoothSerialDevice(address: address);
      notifyListeners();
    } catch (e) {
      debugPrint('Auto-reconnect printer gagal: $e');
    }
  }

  Future<void> printBytes(List<int> bytes) async {
    final port = _connection;
    if (port == null || !port.isOpen) {
      throw Exception('Printer tidak terhubung');
    }
    await port.write(Uint8List.fromList(bytes));
  }

  Future<void> printTest() => printBytes([...utf8.encode('KasirKita\n'), 10, 10, 10]);

  Future<void> _saveAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedAddressKey, address);
  }

  Future<String?> _readAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedAddressKey);
  }

  Future<void> _clearAddress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedAddressKey);
  }

  @override
  void dispose() {
    _connection?.close();
    super.dispose();
  }
}
