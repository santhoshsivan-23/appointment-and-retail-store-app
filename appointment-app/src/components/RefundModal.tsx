import { useState, useMemo } from 'react';
import { toast } from 'react-toastify';
import {
  RotateCcw,
  X,
  Minus,
  Plus,
  ShieldCheck,
} from 'lucide-react';
import { saleApi, type RefundRecord } from '../api/saleApi';
import { appointmentApi } from '../api/appointmentApi';
import '../styles/refund_modal.css';

/* ── Currency / Number Formatter ───────────────────────── */
const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};

export interface NormalizedRefundItem {
  key: string;
  product_id?: number;
  product_name: string;
  unit_price: number;
  original_quantity: number;
  previously_refunded: number;
  available_to_refund: number;
  line_discount: number;
  line_total: number;
}

interface RefundModalProps {
  isOpen: boolean;
  onClose: () => void;
  type: 'sale' | 'appointment';
  transaction: any;
  onRefundSuccess: (updatedTransaction: any, refundRecord: RefundRecord) => void;
}

const PRESET_REASONS = [
  'Customer returned product',
  'Defective or damaged item',
  'Service dissatisfaction',
  'Billing error / Price adjustment',
  'Customer cancelled item',
  'Other (specify in notes)',
];

export default function RefundModal({
  isOpen,
  onClose,
  type,
  transaction,
  onRefundSuccess,
}: RefundModalProps) {
  if (!isOpen || !transaction) return null;

  /* ── 1. Normalize Items and Calculate Existing Refunds ─── */
  const items: NormalizedRefundItem[] = useMemo(() => {
    const rawItems: any[] = transaction.items || transaction.services || [];
    const refundsList: RefundRecord[] = transaction.refunds || [];

    // Calculate sum of already refunded units per item key
    const prevMap: Record<string, number> = {};
    for (const ref of refundsList) {
      if (Array.isArray(ref.items)) {
        for (const it of ref.items) {
          const key = String(it.product_id || it.product_name);
          prevMap[key] = (prevMap[key] || 0) + (Number(it.quantity) || 0);
        }
      }
    }

    return rawItems.map((raw, idx) => {
      const pId = raw.product_id || raw.id;
      const pName = raw.product_name || raw.name || `Item #${idx + 1}`;
      const unitPrice = Number(raw.unit_price !== undefined ? raw.unit_price : raw.price) || 0;
      const origQty = Number(raw.quantity) || 1;
      const lineDisc = Number(raw.discount) || 0;
      const key = String(pId || pName);
      const prevRefunded = prevMap[key] || 0;
      const available = Math.max(0, origQty - prevRefunded);

      return {
        key,
        product_id: pId,
        product_name: pName,
        unit_price: unitPrice,
        original_quantity: origQty,
        previously_refunded: prevRefunded,
        available_to_refund: available,
        line_discount: lineDisc,
        line_total: Number(raw.line_total) || unitPrice * origQty - lineDisc,
      };
    });
  }, [transaction]);

  /* ── 2. Selection & Quantity State ─────────────────────── */
  const [selectedMap, setSelectedMap] = useState<Record<string, boolean>>(() => {
    const map: Record<string, boolean> = {};
    items.forEach((it) => {
      // Default to selected if available to refund > 0
      map[it.key] = it.available_to_refund > 0;
    });
    return map;
  });

  const [quantityMap, setQuantityMap] = useState<Record<string, number>>(() => {
    const map: Record<string, number> = {};
    items.forEach((it) => {
      map[it.key] = it.available_to_refund;
    });
    return map;
  });

  const [reason, setReason] = useState<string>(PRESET_REASONS[0]);
  const [customNotes, setCustomNotes] = useState<string>('');
  const [refundMethod, setRefundMethod] = useState<string>(
    transaction.payment_method || 'cash'
  );
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  /* ── Toggle Selection Handlers ─────────────────────────── */
  const handleToggleSelect = (key: string) => {
    const item = items.find((i) => i.key === key);
    if (!item || item.available_to_refund <= 0) return;

    setSelectedMap((prev) => {
      const nextVal = !prev[key];
      // When turning on, ensure quantity is at least 1
      if (nextVal && (!quantityMap[key] || quantityMap[key] <= 0)) {
        setQuantityMap((qPrev) => ({ ...qPrev, [key]: item.available_to_refund }));
      }
      return { ...prev, [key]: nextVal };
    });
  };

  const handleSelectAll = () => {
    const newSelected: Record<string, boolean> = {};
    const newQty: Record<string, number> = {};
    items.forEach((it) => {
      if (it.available_to_refund > 0) {
        newSelected[it.key] = true;
        newQty[it.key] = it.available_to_refund;
      }
    });
    setSelectedMap(newSelected);
    setQuantityMap((prev) => ({ ...prev, ...newQty }));
  };

  const handleDeselectAll = () => {
    const newSelected: Record<string, boolean> = {};
    items.forEach((it) => {
      newSelected[it.key] = false;
    });
    setSelectedMap(newSelected);
  };

  const handleQtyChange = (key: string, delta: number) => {
    const item = items.find((i) => i.key === key);
    if (!item) return;
    const current = quantityMap[key] || 0;
    const nextQty = Math.max(1, Math.min(item.available_to_refund, current + delta));
    setQuantityMap((prev) => ({ ...prev, [key]: nextQty }));
    // Auto-select if changed
    if (!selectedMap[key]) {
      setSelectedMap((prev) => ({ ...prev, [key]: true }));
    }
  };

  /* ── 3. Dynamic Calculation Engine ─────────────────────── */
  const calculation = useMemo(() => {
    const origSubtotal =
      Number(transaction.subtotal) ||
      items.reduce((acc, it) => acc + it.unit_price * it.original_quantity, 0);
    const origItemDiscount = Number(transaction.item_discount_total) || 0;
    const origOverallDiscount = Number(transaction.overall_discount) || 0;
    const origTaxAmount = Number(transaction.tax_amount) || 0;
    const origTotalPaid = Number(transaction.total_amount) || 0;

    const netItemsTotal = Math.max(0, origSubtotal - origItemDiscount);
    const overallDiscountRatio =
      netItemsTotal > 0 ? origOverallDiscount / netItemsTotal : 0;
    const origTaxable = Math.max(0, netItemsTotal - origOverallDiscount);
    const taxRate =
      origTaxable > 0
        ? origTaxAmount / origTaxable
        : origTaxAmount > 0
        ? 0.08
        : 0;

    const prevRefunds: RefundRecord[] = transaction.refunds || [];
    const prevRefundedTotal = prevRefunds.reduce(
      (sum, rf) => sum + (Number(rf.total_refund_amount) || 0),
      0
    );

    let subtotalRefunded = 0;
    let lineDiscountReversedTotal = 0;
    const activeRefundItems: Array<{
      key: string;
      product_id?: number;
      product_name: string;
      quantity: number;
      unit_price: number;
      line_discount_reversed: number;
      overall_discount_reversed: number;
      total_discount_reversed: number;
      gst_reversed: number;
      line_refund_total: number;
    }> = [];

    for (const it of items) {
      if (!selectedMap[it.key]) continue;
      const q = quantityMap[it.key] || 0;
      if (q <= 0) continue;

      const baseGross = q * it.unit_price;
      const unitLineDiscount =
        it.original_quantity > 0 ? it.line_discount / it.original_quantity : 0;
      const lineDiscReversal = q * unitLineDiscount;
      const itemNetBeforeOverall = Math.max(0, baseGross - lineDiscReversal);
      const itemOverallDiscReversal = itemNetBeforeOverall * overallDiscountRatio;
      const itemTaxable = Math.max(0, itemNetBeforeOverall - itemOverallDiscReversal);
      const itemGst = Math.round(itemTaxable * taxRate * 100) / 100;
      const itemTotal = Math.round((itemTaxable + itemGst) * 100) / 100;

      subtotalRefunded += baseGross;
      lineDiscountReversedTotal += lineDiscReversal;

      activeRefundItems.push({
        key: it.key,
        product_id: it.product_id,
        product_name: it.product_name,
        quantity: q,
        unit_price: it.unit_price,
        line_discount_reversed: Math.round(lineDiscReversal * 100) / 100,
        overall_discount_reversed: Math.round(itemOverallDiscReversal * 100) / 100,
        total_discount_reversed:
          Math.round((lineDiscReversal + itemOverallDiscReversal) * 100) / 100,
        gst_reversed: itemGst,
        line_refund_total: itemTotal,
      });
    }

    const selectedNetLineSum = Math.max(
      0,
      subtotalRefunded - lineDiscountReversedTotal
    );
    const overallDiscountReversal = selectedNetLineSum * overallDiscountRatio;
    const totalDiscountReversed =
      Math.round((lineDiscountReversedTotal + overallDiscountReversal) * 100) / 100;
    const taxableRefund = Math.max(
      0,
      selectedNetLineSum - overallDiscountReversal
    );
    const gstReversal = Math.round(taxableRefund * taxRate * 100) / 100;
    let totalRefundAmount = Math.round((taxableRefund + gstReversal) * 100) / 100;

    // Check if this action fully refunds all remaining items
    let isAllItemsRefunded = true;
    for (const it of items) {
      const selectedQty = selectedMap[it.key] ? quantityMap[it.key] || 0 : 0;
      if (it.previously_refunded + selectedQty < it.original_quantity) {
        isAllItemsRefunded = false;
        break;
      }
    }

    // Exact cent matching on 100% full refund
    if (isAllItemsRefunded) {
      const remainingBalance =
        Math.round((origTotalPaid - prevRefundedTotal) * 100) / 100;
      if (remainingBalance > 0) {
        totalRefundAmount = remainingBalance;
      }
    }

    // Safety boundary
    if (prevRefundedTotal + totalRefundAmount > origTotalPaid + 0.01) {
      totalRefundAmount = Math.max(
        0,
        Math.round((origTotalPaid - prevRefundedTotal) * 100) / 100
      );
    }

    const remainingRefundableBalance = Math.max(
      0,
      Math.round((origTotalPaid - prevRefundedTotal) * 100) / 100
    );

    return {
      subtotalRefunded: Math.round(subtotalRefunded * 100) / 100,
      discountReversed: totalDiscountReversed,
      taxableRefund: Math.round(taxableRefund * 100) / 100,
      gstReversal,
      totalRefundAmount,
      activeRefundItems,
      isAllItemsRefunded,
      origTotalPaid,
      prevRefundedTotal,
      remainingRefundableBalance,
    };
  }, [items, selectedMap, quantityMap, transaction]);

  /* ── 4. Confirm Refund Action ───────────────────────────── */
  const handleConfirmRefund = async () => {
    if (calculation.activeRefundItems.length === 0) {
      toast.warning('Please select at least one item and quantity to refund.');
      return;
    }

    if (calculation.totalRefundAmount <= 0) {
      toast.warning('Refund amount must be greater than $0.00.');
      return;
    }

    const payload = {
      items: calculation.activeRefundItems.map((it) => ({
        product_id: it.product_id,
        product_name: it.product_name,
        quantity: it.quantity,
      })),
      reason: reason === 'Other (specify in notes)' ? customNotes || reason : reason,
      notes: customNotes,
      refund_method: refundMethod,
    };

    setIsSubmitting(true);
    try {
      if (type === 'sale') {
        const res = await saleApi.processRefund(transaction.id, payload);
        toast.success(
          `Refund of $${fmtMoney(
            calculation.totalRefundAmount
          )} processed successfully!`
        );
        onRefundSuccess(res.data?.sale || transaction, res.data?.data);
      } else {
        const res = await appointmentApi.processRefund(transaction.id, payload);
        toast.success(
          `Refund of $${fmtMoney(
            calculation.totalRefundAmount
          )} processed successfully!`
        );
        onRefundSuccess(
          res.data?.appointment || transaction,
          res.data?.data
        );
      }
      onClose();
    } catch (err: any) {
      const msg =
        err?.response?.data?.message || err?.message || 'Failed to process refund.';
      console.error('Error processing refund:', err);
      toast.error(msg);
    } finally {
      setIsSubmitting(false);
    }
  };

  const hasAnyItemsSelected = calculation.activeRefundItems.length > 0;

  return (
    <div className="refund-modal-overlay" onClick={onClose}>
      <div
        className="refund-modal-dialog"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
      >
        {/* ── Header ─────────────────────────────────────── */}
        <div className="refund-modal-header">
          <div>
            <div className="refund-modal-title-row">
              <h3 className="refund-modal-title">Process Order Refund</h3>
              <span className="refund-badge-pill">
                <RotateCcw size={12} />
                <span>
                  {calculation.isAllItemsRefunded ? 'Full Refund' : 'Partial / Full'}
                </span>
              </span>
            </div>
            <div className="refund-modal-meta">
              {type === 'sale'
                ? `Receipt #${String(transaction.id).padStart(4, '0')}`
                : `Appointment #APT-${String(transaction.id).padStart(4, '0')}`}{' '}
              • {transaction.customer_name || 'Walk-in Guest'}
            </div>
          </div>
          <button
            type="button"
            className="refund-close-icon-btn"
            onClick={onClose}
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        {/* ── Body ───────────────────────────────────────── */}
        <div className="refund-modal-body">
          {/* Summary Balance Banner */}
          <div className="refund-summary-banner">
            <div className="refund-summary-banner-item">
              <span className="refund-banner-label">Original Paid</span>
              <span className="refund-banner-val highlight-paid">
                ${fmtMoney(calculation.origTotalPaid)}
              </span>
            </div>
            <div className="refund-summary-banner-item">
              <span className="refund-banner-label">Already Refunded</span>
              <span className="refund-banner-val highlight-refunded">
                ${fmtMoney(calculation.prevRefundedTotal)}
              </span>
            </div>
            <div className="refund-summary-banner-item">
              <span className="refund-banner-label">Max Available</span>
              <span className="refund-banner-val highlight-available">
                ${fmtMoney(calculation.remainingRefundableBalance)}
              </span>
            </div>
          </div>

          {/* Section: Select Products to Refund */}
          <div>
            <div className="refund-section-header">
              <div className="refund-section-title">
                Select Items to Refund ({items.length})
              </div>
              <div className="refund-quick-actions">
                <button
                  type="button"
                  className="refund-quick-btn"
                  onClick={handleSelectAll}
                >
                  Select All
                </button>
                <button
                  type="button"
                  className="refund-quick-btn"
                  onClick={handleDeselectAll}
                >
                  Deselect All
                </button>
              </div>
            </div>

            <div className="refund-items-container" style={{ marginTop: '8px' }}>
              {items.map((it) => {
                const isSelected = !!selectedMap[it.key];
                const currentQty = quantityMap[it.key] || 0;
                const isFullyRefundedPrior = it.available_to_refund <= 0;
                const activeLine = calculation.activeRefundItems.find(
                  (a) => a.key === it.key
                );

                return (
                  <div
                    key={it.key}
                    className={`refund-item-card ${
                      isSelected ? 'is-selected' : ''
                    } ${isFullyRefundedPrior ? 'is-disabled' : ''}`}
                  >
                    <div className="refund-item-left">
                      <input
                        type="checkbox"
                        className="refund-checkbox"
                        checked={isSelected}
                        disabled={isFullyRefundedPrior}
                        onChange={() => handleToggleSelect(it.key)}
                      />
                      <div className="refund-item-info">
                        <span className="refund-item-name">{it.product_name}</span>
                        <div className="refund-item-meta">
                          <span>Unit: ${fmtMoney(it.unit_price)}</span>
                          <span className="refund-item-tag">
                            Purchased: ×{it.original_quantity}
                          </span>
                          {it.previously_refunded > 0 && (
                            <span className="refund-item-tag prior-refund">
                              Prior Refund: ×{it.previously_refunded}
                            </span>
                          )}
                          <span
                            style={{
                              color:
                                it.available_to_refund > 0
                                  ? '#059669'
                                  : '#94A3B8',
                              fontWeight: 600,
                            }}
                          >
                            {it.available_to_refund > 0
                              ? `Available: ${it.available_to_refund}`
                              : 'Fully Refunded'}
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="refund-item-right">
                      {/* Quantity Stepper */}
                      <div className="refund-stepper-control-wrap">
                        <span className="refund-stepper-control-label">Refund Qty:</span>
                        <div className="refund-qty-stepper">
                          <button
                            type="button"
                            className="refund-stepper-btn"
                            disabled={
                              isFullyRefundedPrior || !isSelected || currentQty <= 1
                            }
                            onClick={() => handleQtyChange(it.key, -1)}
                            aria-label="Decrease quantity"
                          >
                            <Minus size={13} />
                          </button>
                          <span className="refund-stepper-val">
                            {isSelected ? currentQty : 0}
                          </span>
                          <button
                            type="button"
                            className="refund-stepper-btn"
                            disabled={
                              isFullyRefundedPrior ||
                              !isSelected ||
                              currentQty >= it.available_to_refund
                            }
                            onClick={() => handleQtyChange(it.key, 1)}
                            aria-label="Increase quantity"
                          >
                            <Plus size={13} />
                          </button>
                        </div>
                      </div>

                      {/* Line Amount Preview */}
                      <div className="refund-line-amount-box">
                        <span className="refund-line-price">
                          $
                          {fmtMoney(
                            activeLine ? activeLine.line_refund_total : 0
                          )}
                        </span>
                        <div className="refund-line-subtext">
                          {isSelected ? `×${currentQty} refund` : 'Not selected'}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Refund Reason & Method */}
          <div className="refund-options-grid">
            <div className="refund-input-group">
              <label className="refund-input-label">Reason for Refund</label>
              <select
                className="refund-select"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              >
                {PRESET_REASONS.map((r) => (
                  <option key={r} value={r}>
                    {r}
                  </option>
                ))}
              </select>
            </div>

            <div className="refund-input-group">
              <label className="refund-input-label">Refund Payment Method</label>
              <select
                className="refund-select"
                value={refundMethod}
                onChange={(e) => setRefundMethod(e.target.value)}
              >
                <option value="cash">Cash Tender</option>
                <option value="card">Original Card Tender</option>
                <option value="qr">QR / Digital Transfer</option>
                <option value="store_credit">Store Credit / Voucher</option>
              </select>
            </div>
          </div>

          <div className="refund-input-group">
            <label className="refund-input-label">
              Audit Notes / Observations (Optional)
            </label>
            <input
              type="text"
              className="refund-input"
              placeholder="e.g. Returned sealed in original packaging; approved by manager."
              value={customNotes}
              onChange={(e) => setCustomNotes(e.target.value)}
            />
          </div>

          {/* Dynamic Calculation Live Breakdown */}
          <div className="refund-calc-card">
            <div className="refund-calc-row">
              <span>Selected Items Subtotal</span>
              <span style={{ fontWeight: 600, color: '#0F172A' }}>
                ${fmtMoney(calculation.subtotalRefunded)}
              </span>
            </div>

            {calculation.discountReversed > 0 && (
              <div className="refund-calc-row discount-row">
                <span>Applicable Discount Reversal</span>
                <span style={{ fontWeight: 600 }}>
                  -${fmtMoney(calculation.discountReversed)}
                </span>
              </div>
            )}

            <div className="refund-calc-row tax-row">
              <span>GST Reversal (8%)</span>
              <span style={{ fontWeight: 600 }}>
                +${fmtMoney(calculation.gstReversal)}
              </span>
            </div>

            <div className="refund-calc-divider" />

            <div className="refund-calc-total-row">
              <div>
                <span className="refund-calc-total-label">Total Refund to Customer</span>
                <div className="refund-audit-notice">
                  <ShieldCheck size={12} style={{ color: '#10B981' }} />
                  <span>
                    Original receipts & audit preserved • Guaranteed bounds
                  </span>
                </div>
              </div>
              <span className="refund-calc-total-val">
                ${fmtMoney(calculation.totalRefundAmount)}
              </span>
            </div>
          </div>
        </div>

        {/* ── Footer ─────────────────────────────────────── */}
        <div className="refund-modal-footer">
          <button
            type="button"
            className="refund-btn-cancel"
            onClick={onClose}
            disabled={isSubmitting}
          >
            Cancel
          </button>
          <button
            type="button"
            className="refund-btn-confirm"
            disabled={!hasAnyItemsSelected || isSubmitting || calculation.totalRefundAmount <= 0}
            onClick={handleConfirmRefund}
          >
            <RotateCcw size={15} />
            <span>
              {isSubmitting
                ? 'Processing Refund...'
                : `Confirm Refund ($${fmtMoney(calculation.totalRefundAmount)})`}
            </span>
          </button>
        </div>
      </div>
    </div>
  );
}
