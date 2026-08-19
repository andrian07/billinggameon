import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/customer.dart';
import '../../../models/payment_method.dart';
import '../../../models/saldo_option.dart';
import '../../payment/data/payment_method_repository.dart';
import '../../settings/data/saldo_repository.dart';
import '../data/customer_repository.dart';

class AddSaldoResult {
  final int customerId;
  final String customerName;
  final int saldoId;
  final int nominal;
  final int price;
  final int discount;
  final int paymentId;
  final String paymentMethodName;

  const AddSaldoResult({
    required this.customerId,
    required this.customerName,
    required this.saldoId,
    required this.nominal,
    required this.price,
    required this.discount,
    required this.paymentId,
    required this.paymentMethodName,
  });
}

class AddSaldoDialog extends StatefulWidget {
  const AddSaldoDialog({super.key});

  @override
  State<AddSaldoDialog> createState() => _AddSaldoDialogState();
}

class _AddSaldoDialogState extends State<AddSaldoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerRepository = CustomerRepository();
  final _paymentMethodRepository = PaymentMethodRepository();
  final _saldoRepository = SaldoRepository();

  Customer? _selectedCustomer;
  String? _customerError;
  PaymentMethod? _selectedPaymentMethod;
  SaldoOption? _selectedSaldo;
  String? _saldoError;

  bool _loading = true;
  String? _loadError;
  List<Customer> _customers = [];
  List<PaymentMethod> _paymentMethods = [];
  List<SaldoOption> _saldoOptions = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final customers = await _customerRepository.getAllCustomers();
      final paymentMethods = await _paymentMethodRepository
          .getPaymentMethods();
      final saldoOptions = await _saldoRepository.getAllSaldos();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _paymentMethods = paymentMethods;
        _selectedPaymentMethod = paymentMethods.isNotEmpty
            ? paymentMethods.first
            : null;
        _saldoOptions = saldoOptions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = "Gagal memuat data member/metode pembayaran/saldo.";
        _loading = false;
      });
    }
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    final customer = _selectedCustomer;
    final saldo = _selectedSaldo;

    setState(() {
      _customerError = customer == null ? "Pilih member terlebih dahulu" : null;
      _saldoError = saldo == null ? "Pilih paket saldo terlebih dahulu" : null;
    });

    if (!formValid || customer == null || saldo == null) return;

    Navigator.of(context).pop(
      AddSaldoResult(
        customerId: customer.id,
        customerName: customer.name,
        saldoId: saldo.id,
        nominal: saldo.nominal,
        price: saldo.price,
        discount: saldo.discount,
        paymentId: _selectedPaymentMethod!.id,
        paymentMethodName: _selectedPaymentMethod!.name,
      ),
    );
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
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : _loadError != null
            ? _buildLoadError()
            : _buildForm(),
      ),
    );
  }

  Widget _buildLoadError() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadOptions,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Coba Lagi"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 22),

            _label("Member"),
            const SizedBox(height: 8),
            Autocomplete<Customer>(
              displayStringForOption: (customer) => customer.name,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return _customers;
                final query = textEditingValue.text.toLowerCase();
                return _customers.where(
                  (customer) => customer.name.toLowerCase().contains(query),
                );
              },
              onSelected: (customer) => setState(() {
                _selectedCustomer = customer;
                _customerError = null;
              }),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AppText.body,
                  decoration: _inputDecoration(
                    hint: "Cari nama member",
                    prefixIcon: Icons.person_outline_rounded,
                    errorText: _customerError,
                  ),
                  onChanged: (_) => setState(() => _selectedCustomer = null),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return _buildOptionsCard<Customer>(
                  options: options,
                  onSelected: onSelected,
                  labelOf: (customer) => customer.name,
                );
              },
            ),

            const SizedBox(height: 20),
            _label("Nominal Saldo"),
            const SizedBox(height: 8),
            DropdownButtonFormField<SaldoOption>(
              initialValue: _selectedSaldo,
              dropdownColor: AppColors.card,
              style: AppText.body,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
              decoration: _inputDecoration(
                hint: "Pilih paket saldo",
                prefixIcon: Icons.account_balance_wallet_outlined,
                errorText: _saldoError,
              ),
              items: [
                for (final saldo in _saldoOptions)
                  DropdownMenuItem(
                    value: saldo,
                    child: Text(formatCurrency(saldo.nominal)),
                  ),
              ],
              onChanged: (value) => setState(() {
                _selectedSaldo = value;
                _saldoError = null;
              }),
            ),
            if (_selectedSaldo != null) ...[
              const SizedBox(height: 10),
              _buildSaldoSummary(_selectedSaldo!),
            ],

            const SizedBox(height: 20),
            _label("Metode Pembayaran"),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentMethod?>(
              initialValue: _selectedPaymentMethod,
              dropdownColor: AppColors.card,
              style: AppText.body,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
              decoration: _inputDecoration(
                prefixIcon: Icons.account_balance_wallet_outlined,
              ),
              items: [
                for (final method in _paymentMethods)
                  DropdownMenuItem(value: method, child: Text(method.name)),
              ],
              validator: (value) =>
                  value == null ? "Pilih metode pembayaran" : null,
              onChanged: (value) =>
                  setState(() => _selectedPaymentMethod = value),
            ),

            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                    ),
                    child: const Text("BATAL"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.savings_outlined, size: 20),
                    label: const Text("TAMBAH SALDO"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                      textStyle: AppText.button,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaldoSummary(SaldoOption saldo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _summaryRow("Diskon", formatCurrency(saldo.discount)),
          const SizedBox(height: 6),
          _summaryRow(
            "Harga Dibayar",
            formatCurrency(saldo.price),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.bodySecondary),
        Text(
          value,
          style: AppText.body.copyWith(
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            color: emphasize ? AppColors.primary : AppColors.text,
          ),
        ),
      ],
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
            color: AppColors.success.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.savings_outlined,
            color: AppColors.success,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tambah Saldo",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text("Buat transaksi top up saldo member", style: AppText.caption),
            ],
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsCard<T extends Object>({
    required Iterable<T> options,
    required void Function(T) onSelected,
    required String Function(T) labelOf,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: AppColors.card,
        elevation: 8,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Container(
          width: 372,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(labelOf(option), style: AppText.body),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? prefixText,
    IconData? prefixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      errorText: errorText,
      prefixText: prefixText,
      prefixStyle: AppText.body.copyWith(color: AppColors.textSecondary),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary)
          : null,
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}
