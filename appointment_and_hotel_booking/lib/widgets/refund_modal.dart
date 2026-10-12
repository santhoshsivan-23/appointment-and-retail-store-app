import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/appointment_model.dart';
import '../models/refund_model.dart';
import '../models/sale_model.dart';
import '../services/api_service.dart';

class RefundModalItem {
  final String key;
  final dynamic productId;
  final String productName;
  final double unitPrice;
  final int originalQuantity;
  final int previouslyRefunded;
  final int availableToRefund;
  final double lineDiscount;
  final double lineTotal;

  RefundModalItem({
    required this.key,
    this.productId,
    required this.productName,
    required this.unitPrice,
    required this.originalQuantity,
    required this.previouslyRefunded,
    required this.availableToRefund,
    required this.lineDiscount,
    required this.lineTotal,
  });
}

class RefundModal extends StatefulWidget {
  final String type; // 'sale' or 'appointment'
  final SaleModel? sale;
  final AppointmentModel? appointment;
  final Function(dynamic updatedTransaction, RefundRecordModel refundRecord) onRefundSuccess;

  const RefundModal({
    super.key,
    required this.type,
    this.sale,
    this.appointment,
    required this.onRefundSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required String type,
    SaleModel? sale,
    AppointmentModel? appointment,
    required Function(dynamic updatedTransaction, RefundRecordModel refundRecord) onRefundSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RefundModal(
        type: type,
        sale: sale,
        appointment: appointment,
        onRefundSuccess: onRefundSuccess,
      ),
    );
  }

  @override
  State<RefundModal> createState() => _RefundModalState();
}

class _RefundModalState extends State<RefundModal> {
  final Map<String, bool> _selectedMap = {};
  final Map<String, int> _refundQtyMap = {};
  String _selectedReason = 'Customer returned product';
  final TextEditingController _customNotesController = TextEditingController();
  String _refundMethod = 'cash';
  bool _isSubmitting = false;

  final List<String> _presetReasons = [
    'Customer returned product',
    'Defective or damaged item',
    'Service dissatisfaction',
    'Billing error / Price adjustment',
    'Customer cancelled item',
    'Other (specify in notes)',
  ];

  late List<RefundModalItem> _items;

  @override
  void initState() {
    super.initState();
    _initItems();
  }

  @override
  void dispose() {
    _customNotesController.dispose();
    super.dispose();
  }

  void _initItems() {
    final List<Map<String, dynamic>> rawItems = widget.type == 'sale'
        ? (widget.sale?.items ?? [])
        : (widget.appointment?.services ?? []);

    final List<RefundRecordModel> refundsList = widget.type == 'sale'
        ? (widget.sale?.refunds ?? [])
        : (widget.appointment?.refunds ?? []);

    // Calculate sum of already refunded units per item key
    final Map<String, int> prevMap = {};
    for (final ref in refundsList) {
      for (final it in ref.items) {
        final key = it.productId != null ? it.productId.toString() : it.productName;
        prevMap[key] = (prevMap[key] ?? 0) + it.quantity;
      }
    }

    _items = [];
    for (int idx = 0; idx < rawItems.length; idx++) {
      final raw = rawItems[idx];
      final pId = raw['product_id'] ?? raw['id'];
      final pName = (raw['product_name'] ?? raw['name'] ?? 'Item #${idx + 1}').toString();
      final unitPrice = double.tryParse((raw['unit_price'] ?? raw['price'])?.toString() ?? '0') ?? 0.0;
      final origQty = int.tryParse(raw['quantity']?.toString() ?? '1') ?? 1;
      final lineDisc = double.tryParse(raw['discount']?.toString() ?? '0') ?? 0.0;
      final key = pId != null ? pId.toString() : pName;
      final prevRefunded = prevMap[key] ?? 0;
      final available = (origQty - prevRefunded) > 0 ? (origQty - prevRefunded) : 0;

      final item = RefundModalItem(
        key: key,
        productId: pId,
        productName: pName,
        unitPrice: unitPrice,
        originalQuantity: origQty,
        previouslyRefunded: prevRefunded,
        availableToRefund: available,
        lineDiscount: lineDisc,
        lineTotal: double.tryParse(raw['line_total']?.toString() ?? '0') ?? (unitPrice * origQty - lineDisc),
      );

      _items.add(item);
      _selectedMap[key] = available > 0;
      _refundQtyMap[key] = available > 0 ? available : 0;
    }
  }

  // ── Dynamic Live Calculation ──────────────────────────────────────────────
  Map<String, dynamic> _computeCalculation() {
    final double origTotalPaid = widget.type == 'sale'
        ? (widget.sale?.totalAmount ?? 0.0)
        : (widget.appointment?.totalAmount ?? 0.0);

    final double prevRefundedTotal = widget.type == 'sale'
        ? (widget.sale?.refundedAmount ?? 0.0)
        : (widget.appointment?.refundedAmount ?? 0.0);

    final double remainingRefundableBalance = (origTotalPaid - prevRefundedTotal) > 0
        ? (origTotalPaid - prevRefundedTotal)
        : 0.0;

    double refundSubtotal = 0.0;
    double lineDiscountsReversed = 0.0;
    double netLinesBeforeOverall = 0.0;
    int totalUnitsSelected = 0;
    int totalAvailableUnits = 0;
    final List<Map<String, dynamic>> activeItems = [];

    for (final it in _items) {
      totalAvailableUnits += it.availableToRefund;
      final isSelected = _selectedMap[it.key] ?? false;
      final qty = _refundQtyMap[it.key] ?? 0;

      if (isSelected && qty > 0) {
        totalUnitsSelected += qty;
        final itemSubtotal = it.unitPrice * qty;
        final lineDiscUnit = it.originalQuantity > 0 ? (it.lineDiscount / it.originalQuantity) : 0.0;
        final lineDiscReversed = lineDiscUnit * qty;
        final netLine = itemSubtotal - lineDiscReversed;

        refundSubtotal += itemSubtotal;
        lineDiscountsReversed += lineDiscReversed;
        netLinesBeforeOverall += netLine;

        activeItems.add({
          'key': it.key,
          'product_id': it.productId,
          'product_name': it.productName,
          'unit_price': it.unitPrice,
          'quantity': qty,
          'original_quantity': it.originalQuantity,
          'previously_refunded': it.previouslyRefunded,
          'remaining_quantity': it.availableToRefund - qty,
          'line_subtotal': itemSubtotal,
          'line_discount_reversed': lineDiscReversed,
        });
      }
    }

    final double origSubtotal = widget.type == 'sale'
        ? (widget.sale?.subtotal ?? origTotalPaid)
        : origTotalPaid;
    final double origItemDisc = widget.type == 'sale'
        ? (widget.sale?.itemDiscountTotal ?? 0.0)
        : 0.0;
    final double origOverallDisc = widget.type == 'sale'
        ? (widget.sale?.overallDiscount ?? 0.0)
        : 0.0;
    final double origTax = widget.type == 'sale'
        ? (widget.sale?.taxAmount ?? 0.0)
        : 0.0;

    final double overallDiscRatio = (origSubtotal - origItemDisc) > 0
        ? (origOverallDisc / (origSubtotal - origItemDisc))
        : 0.0;

    final double overallDiscReversed = netLinesBeforeOverall * overallDiscRatio;
    final double totalDiscountReversed = lineDiscountsReversed + overallDiscReversed;
    final double netTaxableRefund = (refundSubtotal - totalDiscountReversed) > 0
        ? (refundSubtotal - totalDiscountReversed)
        : 0.0;

    final double origTaxable = (origSubtotal - origItemDisc - origOverallDisc) > 0
        ? (origSubtotal - origItemDisc - origOverallDisc)
        : 0.0;
    final double effectiveGstRate = origTaxable > 0 ? (origTax / origTaxable) : 0.08;
    final double gstReversal = netTaxableRefund * effectiveGstRate;

    final bool isAllItemsRefunded = totalAvailableUnits > 0 && totalUnitsSelected == totalAvailableUnits;

    double totalRefundAmount = netTaxableRefund + gstReversal;
    if (isAllItemsRefunded) {
      totalRefundAmount = remainingRefundableBalance;
    }
    if (totalRefundAmount > remainingRefundableBalance) {
      totalRefundAmount = remainingRefundableBalance;
    }

    return {
      'origTotalPaid': origTotalPaid,
      'prevRefundedTotal': prevRefundedTotal,
      'remainingRefundableBalance': remainingRefundableBalance,
      'refundSubtotal': refundSubtotal,
      'lineDiscountsReversed': lineDiscountsReversed,
      'overallDiscReversed': overallDiscReversed,
      'totalDiscountReversed': totalDiscountReversed,
      'netTaxableRefund': netTaxableRefund,
      'gstReversal': gstReversal,
      'totalRefundAmount': totalRefundAmount,
      'isAllItemsRefunded': isAllItemsRefunded,
      'totalUnitsSelected': totalUnitsSelected,
      'activeItems': activeItems,
    };
  }

  // ── Handle Refund Submission ──────────────────────────────────────────────
  Future<void> _handleSubmit(Map<String, dynamic> calc) async {
    final List<Map<String, dynamic>> activeItems = calc['activeItems'];
    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item with quantity > 0.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'items': activeItems.map((e) => {
        'product_id': e['product_id'],
        'product_name': e['product_name'],
        'unit_price': e['unit_price'],
        'quantity': e['quantity'],
      }).toList(),
      'reason': _selectedReason == 'Other (specify in notes)'
          ? (_customNotesController.text.trim().isNotEmpty ? _customNotesController.text.trim() : 'Other')
          : _selectedReason,
      'notes': _customNotesController.text.trim(),
      'refund_method': _refundMethod,
    };

    try {
      final ApiResponse res;
      if (widget.type == 'sale') {
        res = await ApiService.processSaleRefund(widget.sale!.id, payload);
      } else {
        res = await ApiService.processAppointmentRefund(widget.appointment!.id, payload);
      }

      if (!mounted) return;

      if (res.success) {
        final refundRecord = RefundRecordModel.fromJson(Map<String, dynamic>.from(res.data['data']));
        final updatedTx = widget.type == 'sale'
            ? SaleModel.fromJson(Map<String, dynamic>.from(res.data['sale'] ?? {}))
            : AppointmentModel.fromJson(Map<String, dynamic>.from(res.data['appointment'] ?? {}));

        widget.onRefundSuccess(updatedTx, refundRecord);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(
              'Refund of \$${(calc['totalRefundAmount'] as double).toStringAsFixed(2)} processed successfully!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE11D48),
            content: Text(res.message),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: const Color(0xFFE11D48), content: Text('Error processing refund: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calc = _computeCalculation();
    final double origTotalPaid = calc['origTotalPaid'];
    final double prevRefundedTotal = calc['prevRefundedTotal'];
    final double remainingRefundableBalance = calc['remainingRefundableBalance'];
    final double refundSubtotal = calc['refundSubtotal'];
    final double totalDiscountReversed = calc['totalDiscountReversed'];
    final double gstReversal = calc['gstReversal'];
    final double totalRefundAmount = calc['totalRefundAmount'];
    final bool isAllItemsRefunded = calc['isAllItemsRefunded'];
    final int totalUnitsSelected = calc['totalUnitsSelected'];

    final String identifier = widget.type == 'sale'
        ? widget.sale?.receiptNumber ?? '#REC'
        : '#APT-${(widget.appointment?.id ?? 0).toString().padLeft(4, '0')}';
    final String customer = widget.type == 'sale'
        ? (widget.sale?.customerName.isNotEmpty == true ? widget.sale!.customerName : 'Walk-in Guest')
        : (widget.appointment?.customerName.isNotEmpty == true ? widget.appointment!.customerName : 'Walk-in Guest');

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Process Order Refund',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFFE4E6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.replay, size: 11, color: Color(0xFFBE123C)),
                                const SizedBox(width: 3),
                                Text(
                                  isAllItemsRefunded ? 'Full Refund' : 'Partial / Full',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFBE123C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$identifier • $customer',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── 2. Scrollable Content ──────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary Balance Banner
                    Row(
                      children: [
                        Expanded(
                          child: _buildBannerCard('Original Paid', '\$${origTotalPaid.toStringAsFixed(2)}', const Color(0xFF0F172A), const Color(0xFFF8FAFC)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBannerCard('Already Refunded', '\$${prevRefundedTotal.toStringAsFixed(2)}', const Color(0xFFE11D48), const Color(0xFFFFF1F2)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBannerCard('Max Available', '\$${remainingRefundableBalance.toStringAsFixed(2)}', const Color(0xFF059669), const Color(0xFFECFDF5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section Title: Select Products to Refund
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Products & Quantities',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '$totalUnitsSelected units selected',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Items List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final it = _items[idx];
                        final isSelected = _selectedMap[it.key] ?? false;
                        final qty = _refundQtyMap[it.key] ?? 0;
                        final isFullyRefunded = it.availableToRefund == 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isFullyRefunded
                                ? const Color(0xFFF8FAFC)
                                : (isSelected ? const Color(0xFFFFF5F5) : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected && !isFullyRefunded
                                  ? const Color(0xFFFECDD3)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              Checkbox(
                                value: isSelected && !isFullyRefunded,
                                activeColor: const Color(0xFFE11D48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: isFullyRefunded
                                    ? null
                                    : (val) {
                                        setState(() {
                                          _selectedMap[it.key] = val ?? false;
                                          if ((val ?? false) && qty == 0) {
                                            _refundQtyMap[it.key] = it.availableToRefund;
                                          }
                                        });
                                      },
                              ),
                              const SizedBox(width: 4),

                              // Product Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.productName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isFullyRefunded ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '\$${it.unitPrice.toStringAsFixed(2)} ea',
                                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '• Orig: ×${it.originalQuantity}',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                        ),
                                        if (it.previouslyRefunded > 0) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '• Ref: ×${it.previouslyRefunded}',
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFE11D48)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Stepper Controls or Fully Refunded Tag
                              if (isFullyRefunded)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Fully Refunded',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    // Minus
                                    _buildStepperBtn(
                                      icon: Icons.remove,
                                      enabled: isSelected && qty > 0,
                                      onTap: () {
                                        setState(() {
                                          if (qty > 1) {
                                            _refundQtyMap[it.key] = qty - 1;
                                          } else if (qty == 1) {
                                            _refundQtyMap[it.key] = 0;
                                            _selectedMap[it.key] = false;
                                          }
                                        });
                                      },
                                    ),
                                    // Current Qty
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 28),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$qty',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    // Plus
                                    _buildStepperBtn(
                                      icon: Icons.add,
                                      enabled: isSelected && qty < it.availableToRefund,
                                      onTap: () {
                                        setState(() {
                                          if (qty < it.availableToRefund) {
                                            _refundQtyMap[it.key] = qty + 1;
                                            _selectedMap[it.key] = true;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    // Item Line Total
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        '\$${(it.unitPrice * qty).toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Live Calculation Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildCalcRow('Items Subtotal', '+\$${refundSubtotal.toStringAsFixed(2)}'),
                          if (totalDiscountReversed > 0)
                            _buildCalcRow('Discounts Reversed', '-\$${totalDiscountReversed.toStringAsFixed(2)}', valueColor: const Color(0xFFE11D48)),
                          if (gstReversal > 0)
                            _buildCalcRow('GST (8%) Reversal', '+\$${gstReversal.toStringAsFixed(2)}'),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Refund Amount',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Net calculated reversal',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Text(
                                '\$${totalRefundAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE11D48),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Refund Reason Dropdown
                    Text(
                      'Reason for Refund',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedReason,
                          isExpanded: true,
                          items: _presetReasons.map((r) {
                            return DropdownMenuItem<String>(
                              value: r,
                              child: Text(r, style: GoogleFonts.inter(fontSize: 12.5)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedReason = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Custom Notes
                    TextField(
                      controller: _customNotesController,
                      style: GoogleFonts.inter(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Additional notes or audit memo (optional)',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Payment Method Selector
                    Text(
                      'Refund Method',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildMethodBtn('Cash', 'cash', Icons.payments_outlined),
                        const SizedBox(width: 8),
                        _buildMethodBtn('Card', 'card', Icons.credit_card_outlined),
                        const SizedBox(width: 8),
                        _buildMethodBtn('QR Code', 'qr', Icons.qr_code_2_outlined),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. Footer ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF475569), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 16),
                      label: Text(
                        _isSubmitting
                            ? 'Processing...'
                            : 'Confirm Refund (\$${totalRefundAmount.toStringAsFixed(2)})',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _isSubmitting || totalUnitsSelected == 0 || totalRefundAmount <= 0
                          ? null
                          : () => _handleSubmit(calc),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCard(String label, String value, Color valColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: valColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperBtn({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: enabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 14, color: enabled ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodBtn(String label, String val, IconData icon) {
    final isSelected = _refundMethod == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _refundMethod = val),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF1F2) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFE11D48) : const Color(0xFFCBD5E1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
