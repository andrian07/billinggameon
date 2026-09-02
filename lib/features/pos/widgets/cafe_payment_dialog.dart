import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cafe_promo.dart';
import '../../../models/cart_item.dart';
import '../../../models/customer.dart';
import '../../../models/payment_method.dart';
import '../../../services/session_storage.dart';
import '../../customer/data/customer_repository.dart';
import '../../payment/data/payment_method_repository.dart';
import '../../promo/data/cafe_promo_repository.dart';
import '../data/cafe_repository.dart';

class CafePaymentResult {
  final int transactionCafeId;
  final String paymentMethodName;
  final int? table;
  final int? customerId;
  final String? customerName;
  final int tax;
  final int discountPercent;
  final bool printKitchenTicket;

  const CafePaymentResult({
    required this.transactionCafeId,
    required this.paymentMethodName,
    this.table,
    this.customerId,
    this.customerName,
    this.tax = 0,
    this.discountPercent = 0,
    this.printKitchenTicket = false,
  });
}

/// Payment popup for the POS/cafe checkout flow — collects table and
/// payment method, then submits the cart to Cafe/save_transaction_cafe.
/// The server computes the authoritative total; the summary shown here is
/// for the cashier's reference only.
class CafePaymentDialog extends StatefulWidget {
  final List<CartItem> items;
  final int subtotal;
  final String? initialCustomerName;

  const CafePaymentDialog({
    super.key,
    required this.items,
    required this.subtotal,
    this.initialCustomerName,
  });

  @override
  State<CafePaymentDialog> createState() => _CafePaymentDialogState();
}

class _CafePaymentDialogState extends State<CafePaymentDialog> {
  final _cafeRepository = CafeRepository();
  final _customerRepository = CustomerRepository();
  final _paymentMethodRepository = PaymentMethodRepository();
  final _cafePromoRepository = CafePromoRepository();
  final _sessionStorage = SessionStorage();

  final _tableController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _discountController = TextEditingController();
  final _promoNoteController = TextEditingController();

  bool _loadingOptions = true;
  String? _loadError;
  List<PaymentMethod> _paymentMethods = [];
  List<Customer> _customers = [];
  List<CafePromo> _cafePromos = [];

  PaymentMethod? _selectedPaymentMethod;
  CafePromo? _selectedPromo;
  /// Set only when the typed customer name exactly matches a registered
  /// Customer — an unmatched/edited name is still sent as free text via
  /// [_customerNameController], just without a linked [Customer.id].
  int? _selectedCustomerId;
  bool _printKitchenTicket = false;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _customerNameController.text = widget.initialCustomerName ?? '';
    _loadOptions();
  }

  @override
  void dispose() {
    _tableController.dispose();
    _customerNameController.dispose();
    _discountController.dispose();
    _promoNoteController.dispose();
    super.dispose();
  }

  int get _discountPercent {
    final value = int.tryParse(_discountController.text.trim()) ?? 0;
    return value.clamp(0, 100);
  }

  /// Subtotal gabungan item di keranjang yang produknya termasuk cakupan promo
  /// terpilih (item utama + addon). Dipakai untuk preview - server yang otoritatif.
  int get _promoEligibleSubtotal {
    final promo = _selectedPromo;
    if (promo == null) return 0;
    final ids = promo.productIds.toSet();
    var sum = 0;
    for (final item in widget.items) {
      if (ids.contains(item.product.id)) {
        sum += item.product.price * item.quantity;
      }
      for (final addon in item.addons) {
        if (ids.contains(addon.product.id)) sum += addon.lineTotal;
      }
    }
    return sum;
  }

  /// Potongan dari promo cafe = subtotal item promo - harga promo (min 0).
  /// Hanya berlaku kalau produk promo memang ada di keranjang.
  int get _promoDiscount {
    final promo = _selectedPromo;
    if (promo == null) return 0;
    final eligible = _promoEligibleSubtotal;
    if (eligible <= 0) return 0;
    return (eligible - promo.price).clamp(0, eligible);
  }

  int get _subtotalAfterPromo => widget.subtotal - _promoDiscount;

  int get _discountAmount =>
      (_subtotalAfterPromo * _discountPercent / 100).round();

  int get _totalAfterDiscount => _subtotalAfterPromo - _discountAmount;

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _loadError = null;
    });

    try {
      final customerResult = await _customerRepository.getCustomers(
        page: 1,
        perPage: 200,
      );
      final paymentMethods = await _paymentMethodRepository
          .getPaymentMethods();
      // promo cafe opsional - kalau gagal dimuat, checkout tetap bisa jalan tanpa promo
      List<CafePromo> cafePromos = const [];
      try {
        cafePromos = await _cafePromoRepository.getAllPromos();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _customers = customerResult.customers;
        _paymentMethods = paymentMethods;
        _cafePromos = cafePromos;
        _selectedPaymentMethod = paymentMethods.isNotEmpty
            ? paymentMethods.first
            : null;
        _loadingOptions = false;
      });
    } on CustomerRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingOptions = false;
      });
    } on PaymentMethodRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingOptions = false;
      });
    }
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomerId = customer.id;
      _customerNameController.text = customer.name;
    });
  }

  Future<void> _submit() async {
    final paymentMethod = _selectedPaymentMethod;
    if (paymentMethod == null) return;

    final promo = _selectedPromo;
    if (promo != null) {
      if (_promoEligibleSubtotal <= 0) {
        setState(() => _submitError =
            "Produk untuk promo \"${promo.name}\" tidak ada di keranjang");
        return;
      }
      if (_promoNoteController.text.trim().isEmpty) {
        setState(() => _submitError = "Keterangan promo wajib diisi");
        return;
      }
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final session = await _sessionStorage.getSession();
      final createdBy = session?['username']?.toString() ?? "";
      final paidBy = int.tryParse(session?['id']?.toString() ?? "") ?? 0;
      final table = int.tryParse(_tableController.text.trim());
      final customerName = _customerNameController.text.trim();
      final customerId =
          _selectedCustomerId != null &&
              _customers.any(
                (c) => c.id == _selectedCustomerId && c.name == customerName,
              )
          ? _selectedCustomerId
          : null;

      final transactionCafeId = await _cafeRepository.submitTransactionCafe(
        customerId: customerId,
        promoId: promo?.id,
        promoNote: promo != null ? _promoNoteController.text.trim() : null,
        paymentId: paymentMethod.id,
        table: table,
        customerName: customerName.isNotEmpty ? customerName : null,
        tax: 0,
        discountPercent: _discountPercent.toDouble(),
        createdBy: createdBy,
        paidBy: paidBy,
        items: widget.items,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        CafePaymentResult(
          transactionCafeId: transactionCafeId,
          paymentMethodName: paymentMethod.name,
          table: table,
          customerId: customerId,
          customerName: customerName.isNotEmpty ? customerName : null,
          tax: 0,
          discountPercent: _discountPercent,
          printKitchenTicket: _printKitchenTicket,
        ),
      );
    } on CafeRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.message;
      });
    }
  }

  Widget _buildPromoSection() {
    final promo = _selectedPromo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label("Promo Cafe (opsional)"),
        const SizedBox(height: 8),
        DropdownButtonFormField<CafePromo?>(
          initialValue: promo,
          isExpanded: true,
          style: AppText.body,
          decoration: _inputDecoration(prefixIcon: Icons.local_offer_outlined),
          items: [
            const DropdownMenuItem<CafePromo?>(
              value: null,
              child: Text("Tanpa promo"),
            ),
            for (final p in _cafePromos)
              DropdownMenuItem<CafePromo?>(
                value: p,
                child: Text(
                  "${p.name} — ${formatCurrency(p.price)}",
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _selectedPromo = value;
            if (value == null) _promoNoteController.clear();
          }),
        ),
        if (promo != null) ...[
          const SizedBox(height: 6),
          Text(
            _promoEligibleSubtotal > 0
                ? "Item promo: ${formatCurrency(_promoEligibleSubtotal)} → ${formatCurrency(promo.price)}  (hemat ${formatCurrency(_promoDiscount)})"
                : "Produk promo ini belum ada di keranjang",
            style: AppText.caption.copyWith(
              color: _promoEligibleSubtotal > 0
                  ? AppColors.success
                  : AppColors.danger,
            ),
          ),
          const SizedBox(height: 10),
          _label("Keterangan Promo (wajib)"),
          const SizedBox(height: 8),
          TextField(
            controller: _promoNoteController,
            style: AppText.body,
            minLines: 1,
            maxLines: 3,
            decoration: _inputDecoration(
              hint: "mis. pelanggan reguler / arahan supervisor",
              prefixIcon: Icons.notes_rounded,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: screenSize.height * 0.9,
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 24),
                if (_loadError != null) ...[
                  _buildInlineError(_loadError!, onRetry: _loadOptions),
                  const SizedBox(height: 20),
                ],
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: _buildFormColumn()),
                      const SizedBox(width: 28),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      const SizedBox(width: 28),
                      Expanded(flex: 5, child: _buildSummaryColumn()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label("Item Pesanan"),
        const SizedBox(height: 10),
        _buildItemsList(),

        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _label("Nomor Meja"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tableController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: AppText.body,
                    decoration: _inputDecoration(
                      hint: "Takeaway / Meja 1",
                      prefixIcon: Icons.table_bar_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      loading: _loadingOptions,
                    ),
                    items: [
                      for (final method in _paymentMethods)
                        DropdownMenuItem(
                          value: method,
                          child: Text(method.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedPaymentMethod = value);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        if (_cafePromos.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPromoSection(),
        ],

        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _label("Diskon (%)"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    style: AppText.body,
                    decoration: _inputDecoration(
                      hint: "0",
                      prefixIcon: Icons.percent_rounded,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _label("Nama Customer (opsional)"),
                  const SizedBox(height: 8),
                  Autocomplete<Customer>(
                    initialValue: TextEditingValue(
                      text: _customerNameController.text,
                    ),
                    displayStringForOption: (customer) => customer.name,
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return _customers;
                      final query = textEditingValue.text.toLowerCase();
                      return _customers.where(
                        (c) => c.name.toLowerCase().contains(query),
                      );
                    },
                    onSelected: _selectCustomer,
                    fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: AppText.body,
                        decoration: _inputDecoration(
                          hint: "Mis. Budi, atau cari member",
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        // Keep the outer controller (used on submit and as
                        // the held-transaction prefill) in sync with
                        // whatever the field actually shows, free text
                        // included.
                        onChanged: (value) => setState(
                          () => _customerNameController.text = value,
                        ),
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
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(
            () => _printKitchenTicket = !_printKitchenTicket,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _printKitchenTicket,
                  activeColor: AppColors.primary,
                  onChanged: (v) =>
                      setState(() => _printKitchenTicket = v ?? false),
                ),
                Expanded(
                  child: Text(
                    "Cetak struk dapur juga",
                    style: AppText.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    return Container(
      padding: const EdgeInsets.all(12),
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: widget.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return Row(
            children: [
              Expanded(
                child: Text(
                  "${item.product.name} x${item.quantity}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body,
                ),
              ),
              Text(
                formatCurrency(item.lineTotal),
                style: AppText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _label("Rincian Tagihan"),
            const SizedBox(height: 10),
            _buildBillingSummary(),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_submitError != null) ...[
              const SizedBox(height: 20),
              _buildInlineError(_submitError!, onRetry: _submit),
            ],
            const SizedBox(height: 20),
            _buildConfirmButton(),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                child: const Text("BATAL"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBillingSummary() {
    final itemCount = widget.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withValues(alpha: .08),
            AppColors.background,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _kv(Icons.shopping_bag_outlined, "Jumlah Item", "$itemCount item"),
          const SizedBox(height: 10),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 10),
          _kv(
            Icons.receipt_long_outlined,
            "Subtotal",
            formatCurrency(widget.subtotal),
          ),
          if (_selectedPromo != null && _promoDiscount > 0) ...[
            const SizedBox(height: 10),
            _kv(
              Icons.local_offer_outlined,
              "Promo (${_selectedPromo!.name})",
              "-${formatCurrency(_promoDiscount)}",
              valueColor: AppColors.danger,
            ),
          ],
          if (_discountPercent > 0) ...[
            const SizedBox(height: 10),
            _kv(
              Icons.percent_rounded,
              "Diskon ($_discountPercent%)",
              "-${formatCurrency(_discountAmount)}",
              valueColor: AppColors.danger,
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Total Bayar",
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                formatCurrency(_totalAfterDiscount),
                style: AppText.title.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: (AppText.title.fontSize ?? 18) + 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String message, {required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.danger.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text("Coba Lagi"),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final enabled =
        !_loadingOptions && !_submitting && _selectedPaymentMethod != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: enabled
              ? const [AppColors.success, Color(0xFF15803D)]
              : [AppColors.textHint, AppColors.textHint],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: .35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: InkWell(
          onTap: enabled ? _submit : null,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_submitting)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 10),
                Text(
                  _submitting ? "MEMPROSES..." : "KONFIRMASI PEMBAYARAN",
                  style: AppText.button.copyWith(letterSpacing: .4),
                ),
              ],
            ),
          ),
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
            color: AppColors.warning.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.payments_outlined,
            color: AppColors.warning,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Proses Pembayaran",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text("Konfirmasi transaksi cafe/POS", style: AppText.caption),
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

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
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

  Widget _kv(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textHint),
            const SizedBox(width: 8),
            Text(label, style: AppText.bodySecondary),
          ],
        ),
        Text(
          value,
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    IconData? prefixIcon,
    bool loading = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary)
          : null,
      suffixIcon: loading
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
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
    );
  }
}
