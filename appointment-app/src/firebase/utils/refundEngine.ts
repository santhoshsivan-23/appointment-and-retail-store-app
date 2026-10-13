import type { RefundItem, RefundRecord } from '../../api/saleApi';

export interface RefundCalculationResult {
  subtotal_refunded: number;
  discount_reversed_total: number;
  gst_reversed_total: number;
  total_refund_amount: number;
  items: RefundItem[];
  is_fully_refunded: boolean;
  refund_type: 'partial' | 'full';
}

/**
 * Re-implements backend refund mathematical breakdown with line and overall discount reversal,
 * GST/tax clawback, boundary checks, and full refund reconciliation.
 */
export function calculateRefundDetails(
  originalTransaction: any,
  refundItems: Array<{ product_id?: number; product_name?: string; quantity: number }>,
  existingRefunds: RefundRecord[] = []
): RefundCalculationResult {
  const prevRefundedMap: Record<string, number> = {};
  let totalPrevRefundAmount = 0;

  for (const ref of existingRefunds) {
    totalPrevRefundAmount += Number(ref.total_refund_amount) || 0;
    if (Array.isArray(ref.items)) {
      for (const it of ref.items) {
        const key = String(it.product_id || it.product_name).toLowerCase();
        prevRefundedMap[key] = (prevRefundedMap[key] || 0) + (Number(it.quantity) || 0);
      }
    }
  }

  const origItems = originalTransaction.items || originalTransaction.services || [];
  const origSubtotal =
    Number(originalTransaction.subtotal) ||
    origItems.reduce(
      (acc: number, it: any) =>
        acc +
        (Number(it.unit_price !== undefined ? it.unit_price : it.price) || 0) *
          (Number(it.quantity) || 1),
      0
    );
  const origItemDiscount = Number(originalTransaction.item_discount_total) || 0;
  const origOverallDiscount = Number(originalTransaction.overall_discount) || 0;
  const origTaxAmount = Number(originalTransaction.tax_amount) || 0;
  const origTotalAmount = Number(originalTransaction.total_amount) || 0;

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

  let subtotalRefunded = 0;
  let lineDiscountReversedTotal = 0;
  const processedRefundItems: RefundItem[] = [];

  for (const reqItem of refundItems) {
    const qtyToRefund = Number(reqItem.quantity) || 0;
    if (qtyToRefund <= 0) continue;

    const orig = origItems.find(
      (it: any) =>
        (reqItem.product_id &&
          (it.product_id === reqItem.product_id || it.id === reqItem.product_id)) ||
        (it.product_name &&
          reqItem.product_name &&
          it.product_name.toLowerCase() === reqItem.product_name.toLowerCase()) ||
        (it.name &&
          reqItem.product_name &&
          it.name.toLowerCase() === reqItem.product_name.toLowerCase())
    );

    if (!orig) {
      throw new Error(
        `Item "${reqItem.product_name || reqItem.product_id}" not found in original transaction.`
      );
    }

    const origQty = Number(orig.quantity) || 1;
    const unitPrice =
      Number(orig.unit_price !== undefined ? orig.unit_price : orig.price) || 0;
    const origLineDiscount = Number(orig.discount) || 0;
    const key = String(orig.product_id || orig.id || orig.product_name || orig.name).toLowerCase();
    const prevQty = prevRefundedMap[key] || 0;
    const maxRefundable = origQty - prevQty;

    if (qtyToRefund > maxRefundable) {
      throw new Error(
        `Cannot refund ${qtyToRefund} × "${
          orig.product_name || orig.name
        }". Only ${maxRefundable} remaining.`
      );
    }

    const itemBaseGross = qtyToRefund * unitPrice;
    const unitLineDiscount = origQty > 0 ? origLineDiscount / origQty : 0;
    const itemLineDiscountReversal = qtyToRefund * unitLineDiscount;
    const itemNetBeforeOverall = Math.max(0, itemBaseGross - itemLineDiscountReversal);

    const itemOverallDiscountReversal =
      itemNetBeforeOverall * overallDiscountRatio;
    const itemTaxable = Math.max(
      0,
      itemNetBeforeOverall - itemOverallDiscountReversal
    );
    const itemGstReversal = Math.round(itemTaxable * taxRate * 100) / 100;
    const itemRefundTotal = Math.round((itemTaxable + itemGstReversal) * 100) / 100;

    subtotalRefunded += itemBaseGross;
    lineDiscountReversedTotal += itemLineDiscountReversal;

    processedRefundItems.push({
      product_id: orig.product_id || orig.id || undefined,
      product_name: orig.product_name || orig.name || 'Item',
      unit_price: unitPrice,
      quantity: qtyToRefund,
      original_quantity: origQty,
      previously_refunded: prevQty,
      remaining_quantity: origQty - prevQty - qtyToRefund,
      line_discount_reversed: Math.round(itemLineDiscountReversal * 100) / 100,
      overall_discount_reversed:
        Math.round(itemOverallDiscountReversal * 100) / 100,
      total_discount_reversed:
        Math.round(
          (itemLineDiscountReversal + itemOverallDiscountReversal) * 100
        ) / 100,
      gst_reversed: itemGstReversal,
      refund_amount: itemRefundTotal,
    });
  }

  if (processedRefundItems.length === 0) {
    throw new Error('Please select at least one item and quantity to refund.');
  }

  const selectedNetLineSum = Math.max(
    0,
    subtotalRefunded - lineDiscountReversedTotal
  );
  const overallDiscountReversedTotal =
    selectedNetLineSum * overallDiscountRatio;
  const totalDiscountReversed =
    Math.round((lineDiscountReversedTotal + overallDiscountReversedTotal) * 100) /
    100;
  const taxableRefund = Math.max(
    0,
    selectedNetLineSum - overallDiscountReversedTotal
  );
  const gstReversedTotal = Math.round(taxableRefund * taxRate * 100) / 100;
  let totalRefundAmount =
    Math.round((taxableRefund + gstReversedTotal) * 100) / 100;

  // Check if this results in full refund of all items
  let isAllItemsFullyRefunded = true;
  for (const orig of origItems) {
    const origQty = Number(orig.quantity) || 1;
    const key = String(
      orig.product_id || orig.id || orig.product_name || orig.name
    ).toLowerCase();
    const prevQty = prevRefundedMap[key] || 0;
    const currentRefItem = processedRefundItems.find(
      (p) =>
        String(p.product_id || p.product_name).toLowerCase() === key
    );
    const thisRefQty = currentRefItem ? currentRefItem.quantity : 0;
    if (prevQty + thisRefQty < origQty) {
      isAllItemsFullyRefunded = false;
      break;
    }
  }

  if (isAllItemsFullyRefunded) {
    const remainingPaidBalance =
      Math.round((origTotalAmount - totalPrevRefundAmount) * 100) / 100;
    if (remainingPaidBalance > 0) {
      totalRefundAmount = remainingPaidBalance;
    }
  }

  // Strict boundary cap
  if (totalPrevRefundAmount + totalRefundAmount > origTotalAmount + 0.01) {
    totalRefundAmount = Math.max(
      0,
      Math.round((origTotalAmount - totalPrevRefundAmount) * 100) / 100
    );
  }

  return {
    subtotal_refunded: Math.round(subtotalRefunded * 100) / 100,
    discount_reversed_total: totalDiscountReversed,
    gst_reversed_total: gstReversedTotal,
    total_refund_amount: totalRefundAmount,
    items: processedRefundItems,
    is_fully_refunded: isAllItemsFullyRefunded,
    refund_type: isAllItemsFullyRefunded ? 'full' : 'partial',
  };
}
