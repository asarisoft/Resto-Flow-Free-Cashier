import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluetooth_serial_next/bluetooth_serial_next.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../printer/printer_service.dart';
import '../../core/theme/app_icons.dart';

class PrinterPairingPage extends ConsumerStatefulWidget {
  const PrinterPairingPage({super.key});

  @override
  ConsumerState<PrinterPairingPage> createState() => _PrinterPairingPageState();
}

class _PrinterPairingPageState extends ConsumerState<PrinterPairingPage> {
  PrinterService get _printer => ref.read(printerServiceProvider);
  List<BluetoothSerialDevice> _devices = [];
  bool _scanning = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    _devices = [];
    try {
      final devices = await _printer.scan();
      setState(() => _devices = devices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal scan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pairing Printer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pilih printer Bluetooth thermal Anda',
            style: textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_scanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Mencari printer...'),
                  ],
                ),
              ),
            ),
          if (!_scanning && _devices.isEmpty)
            Column(
              children: [
                const Icon(AppIcons.bluetoothOff,
                    size: AppIcons.hero, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text('Tidak ditemukan printer',
                    style: textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(AppIcons.refresh),
                  label: const Text('Scan Ulang'),
                  onPressed: _scan,
                ),
              ],
            ),
          ..._devices.map((d) => _deviceCard(d)),
        ],
      ),
    );
  }

  Widget _deviceCard(BluetoothSerialDevice device) {
    final textTheme = AppTypography.textTheme;
    final connected = _printer.device?.address != null &&
        _printer.device!.address == device.address;
    final name = device.name ?? 'Unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: connected ? AppColors.primary : AppColors.border,
          width: connected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected
                ? AppIcons.bluetoothConnected
                : AppIcons.bluetooth,
            color: connected
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(device.address,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_connecting)
            Semantics(
              label: 'Menghubungkan printer',
              liveRegion: true,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (connected)
            FilledButton(
              onPressed: () => _disconnect(),
              child: const Text('Putus'),
            )
          else
            OutlinedButton(
              onPressed: () => _connect(device),
              child: const Text('Hubungkan'),
            ),
        ],
      ),
    );
  }

  Future<void> _connect(BluetoothSerialDevice device) async {
    setState(() => _connecting = true);
    try {
      await _printer.connect(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer terhubung')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await _printer.disconnect();
    setState(() {});
  }
}
