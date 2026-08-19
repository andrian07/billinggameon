import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../services/printer_preference_storage.dart';

/// Lets the operator pick which Windows printer entry receipts should go
/// to, instead of the app guessing from the print spooler's list — see
/// [ReceiptPrinterService]. Shows every entry the spooler reports
/// (including virtual ones like "Send to OneNote") so a wrong auto-pick is
/// visible and fixable here, rather than just failing silently at print
/// time.
class PrinterSelectDialog extends StatefulWidget {
  const PrinterSelectDialog({super.key});

  @override
  State<PrinterSelectDialog> createState() => _PrinterSelectDialogState();
}

class _PrinterSelectDialogState extends State<PrinterSelectDialog> {
  final _storage = PrinterPreferenceStorage();

  bool _scanning = true;
  String? _error;
  List<UsbPrinterDevice> _printers = [];
  String? _selectedIdentifier;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });

    final manager = PrinterManager();
    try {
      final saved = await _storage.getSelectedPrinterIdentifier();
      final printers = await manager
          .scanPrinters(types: {PrinterConnectionType.usb})
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _printers = printers.whereType<UsbPrinterDevice>().toList();
        _selectedIdentifier = saved;
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

  Future<void> _save() async {
    await _storage.setSelectedPrinterIdentifier(_selectedIdentifier);
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
        width: 440,
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
              constraints: const BoxConstraints(maxHeight: 360),
              child: _buildBody(),
            ),
            const SizedBox(height: 20),
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
                "Printer yang dipakai untuk cetak struk",
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
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
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
          "Tidak ada printer USB ditemukan. Pastikan printer terhubung dan menyala.",
          style: AppText.bodySecondary,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final printer in _printers)
            RadioListTile<String>(
              value: printer.identifier,
              groupValue: _selectedIdentifier,
              onChanged: (value) =>
                  setState(() => _selectedIdentifier = value),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              title: Text(printer.name, style: AppText.body),
              subtitle: Text(printer.identifier, style: AppText.caption),
            ),
        ],
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
            onPressed: _selectedIdentifier == null ? null : _save,
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
