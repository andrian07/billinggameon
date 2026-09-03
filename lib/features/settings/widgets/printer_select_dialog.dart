import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../services/printer_preference_storage.dart';
import '../../../services/receipt_printer_service.dart';

/// Lets the operator pick which printer receipts go to — either a **USB**
/// printer the OS reports, or a **LAN (network)** printer by IP. Auto-scans
/// both transports; a LAN printer on a static IP that discovery misses
/// (wired network, firewalled probe) can still be added by hand.
class PrinterSelectDialog extends StatefulWidget {
  const PrinterSelectDialog({super.key});

  @override
  State<PrinterSelectDialog> createState() => _PrinterSelectDialogState();
}

class _PrinterSelectDialogState extends State<PrinterSelectDialog> {
  final _storage = PrinterPreferenceStorage();

  bool _scanning = true;
  bool _testing = false;
  String? _error;

  /// Combined list: USB devices from the scan + network devices (from the
  /// subnet scan and/or added manually), de-duplicated by [_keyFor].
  final List<PrinterDevice> _printers = [];
  String? _selectedKey;

  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: "9100");
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  /// Stable identity for a device, used both as the radio group value and
  /// to match the saved [PrinterSelection].
  String _keyFor(PrinterDevice d) {
    if (d is UsbPrinterDevice) return "usb::${d.identifier}";
    if (d is NetworkPrinterDevice) return "net::${d.host}:${d.port}";
    return "other::${d.name}";
  }

  String _keyForSelection(PrinterSelection s) => s.isNetwork
      ? "net::${s.host}:${s.port}"
      : "usb::${s.identifier}";

  void _addOrKeep(PrinterDevice d) {
    final key = _keyFor(d);
    if (_printers.any((p) => _keyFor(p) == key)) return;
    _printers.add(d);
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _printers.clear();
    });

    final manager = PrinterManager();
    try {
      final saved = await _storage.getSelection();

      // Keep a saved LAN printer visible even if discovery can't see it.
      if (saved != null && saved.isNetwork) {
        _addOrKeep(
          NetworkPrinterDevice(
            name: saved.displayName,
            host: saved.host,
            port: saved.port,
          ),
        );
      }

      final devices = await manager
          .scanPrinters(
            types: {
              PrinterConnectionType.usb,
              PrinterConnectionType.network,
            },
            timeout: const Duration(seconds: 8),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      setState(() {
        for (final d in devices) {
          if (d is UsbPrinterDevice || d is NetworkPrinterDevice) _addOrKeep(d);
        }
        _selectedKey = saved != null ? _keyForSelection(saved) : null;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Gagal memindai printer: $e";
        _scanning = false;
      });
    } finally {
      unawaited(manager.dispose());
    }
  }

  void _addManualLan() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;
    if (host.isEmpty) {
      setState(() => _error = "Isi alamat IP printer LAN dulu.");
      return;
    }

    final device = NetworkPrinterDevice(name: host, host: host, port: port);
    setState(() {
      _error = null;
      _addOrKeep(device);
      _selectedKey = _keyFor(device);
      _hostController.clear();
      _showManual = false;
    });
  }

  Future<void> _testPrint() async {
    final key = _selectedKey;
    if (key == null || _printers.isEmpty) return;

    final device = _printers.firstWhere(
      (p) => _keyFor(p) == key,
      orElse: () => _printers.first,
    );

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      await ReceiptPrinterService().printTestReceipt(device);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Nota tes dikirim ke printer.")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Gagal tes cetak: $e");
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    PrinterSelection? selection;
    if (_selectedKey != null) {
      final device = _printers.firstWhere(
        (p) => _keyFor(p) == _selectedKey,
        orElse: () => _printers.first,
      );
      if (device is UsbPrinterDevice) {
        selection = PrinterSelection(
          kind: PrinterKind.usb,
          identifier: device.identifier,
          label: device.name,
        );
      } else if (device is NetworkPrinterDevice) {
        selection = PrinterSelection(
          kind: PrinterKind.network,
          identifier: "${device.host}:${device.port}",
          label: device.name == device.host ? null : device.name,
        );
      }
    }

    await _storage.setSelection(selection);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: _buildBody(),
            ),
            const SizedBox(height: 12),
            _buildManualLan(),
            const SizedBox(height: 8),
            _buildTestPrint(),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.print_outlined,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pilih Printer",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                "Printer USB atau LAN untuk cetak struk",
                style: AppText.caption,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: "Pindai ulang",
          onPressed: _scanning ? null : _scan,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_scanning) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("Memindai printer USB & LAN..."),
            ],
          ),
        ),
      );
    }

    final usb = _printers.whereType<UsbPrinterDevice>().toList();
    final lan = _printers.whereType<NetworkPrinterDevice>().toList();

    if (_error != null && _printers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          _error!,
          style: AppText.bodySecondary.copyWith(color: AppColors.danger),
        ),
      );
    }

    if (_printers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          "Tidak ada printer terdeteksi. Pastikan printer menyala & terhubung, "
          "atau tambahkan printer LAN secara manual di bawah.",
          style: AppText.bodySecondary,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: 8),
          ],
          if (usb.isNotEmpty) ...[
            _sectionLabel("USB"),
            for (final p in usb)
              _tile(
                device: p,
                title: p.name,
                subtitle: p.identifier,
                icon: Icons.usb_rounded,
              ),
          ],
          if (lan.isNotEmpty) ...[
            if (usb.isNotEmpty) const SizedBox(height: 8),
            _sectionLabel("LAN / Jaringan"),
            for (final p in lan)
              _tile(
                device: p,
                title: p.name == p.host ? "Printer LAN" : p.name,
                subtitle: "${p.host}:${p.port}",
                icon: Icons.lan_rounded,
              ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        text,
        style: AppText.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: .6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _tile({
    required PrinterDevice device,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final key = _keyFor(device);
    return RadioListTile<String>(
      value: key,
      groupValue: _selectedKey,
      onChanged: (value) => setState(() => _selectedKey = value),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: AppText.body)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Text(subtitle, style: AppText.caption),
      ),
    );
  }

  Widget _buildManualLan() {
    if (!_showManual) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _showManual = true),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text("Tambah printer LAN manual"),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Printer LAN manual",
            style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _hostController,
                  style: AppText.body,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: _fieldDecoration("Alamat IP (mis. 192.168.1.50)"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _portController,
                  style: AppText.body,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration("Port"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _showManual = false;
                  _hostController.clear();
                }),
                child: const Text("Batal"),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addManualLan,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text("Tambah"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      isDense: true,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildTestPrint() {
    final enabled = _selectedKey != null && !_testing && !_scanning;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: enabled ? _testPrint : null,
        icon: _testing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.receipt_long_outlined, size: 18),
        label: Text(_testing ? "Mencetak..." : "Tes cetak nota dummy"),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            child: const Text("BATAL"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _selectedKey == null ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 20),
            label: const Text("SIMPAN"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              elevation: 0,
              textStyle: AppText.button,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
