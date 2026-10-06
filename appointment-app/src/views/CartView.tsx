import { useState, useEffect, useCallback } from 'react';
import { toast } from 'react-toastify';
import {
  LayoutGrid,
  Tag,
  PlusCircle,
  CheckCircle,
  ShoppingCart,
  UserPlus,
  UserCheck,
  Edit2,
  Trash2,
  Minus,
  Plus,
  X,
  CreditCard,
  Banknote,
  QrCode,
  Wallet,
  Printer,
  History,
  CheckCircle2,
  AlertCircle,
  Search,
  Save,
  UserMinus,
  ChevronRight,
  ChevronLeft,
} from 'lucide-react';
import { productApi, type Product } from '../api/productApi';
import { categoryApi, type Category } from '../api/categoryApi';
import { customerApi, type Customer } from '../api/customerApi';
import { saleApi, type Sale, formatReceiptNumber, getPaymentMethodLabel } from '../api/saleApi';
import '../styles/cart_pos.css';

/* ── Safe Currency / Number Formatter ─────────────────── */
const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};
/* ── Cart Item Model ──────────────────────────────────── */
export interface LocalCartItem {
  product: Product;
  quantity: number;
  discount: number; // Dollar amount discount for this line
  lineTotal: number;
}

interface CartViewProps {
  preloadCustomer?: Customer | null;
  preloadProducts?: Product[] | null;
  preloadAppointmentId?: number | null;
  preloadStaffName?: string | null;
  onNavigateToSalesHistory?: () => void;
  mobileViewMode?: 'pos' | 'cart';
  onMobileViewModeChange?: (mode: 'pos' | 'cart') => void;
  onCartCountChange?: (count: number) => void;
}

export default function CartView({
  preloadCustomer,
  preloadProducts,
  preloadAppointmentId,
  preloadStaffName,
  onNavigateToSalesHistory,
  mobileViewMode = 'pos',
  onMobileViewModeChange,
  onCartCountChange,
}: CartViewProps) {
  /* ── State ────────────────────────────────────────────── */
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  // Filter
  const [selectedCategoryId, setSelectedCategoryId] = useState<number | null>(null);

  // Cart
  const [cart, setCart] = useState<LocalCartItem[]>([]);
  const [overallDiscount, setOverallDiscount] = useState<number>(0);
  const [overallDiscountInput, setOverallDiscountInput] = useState<string>('0.00');

  // Customer
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
  const [tempNewCustomer, setTempNewCustomer] = useState<{ name: string; phone: string } | null>(null);
  const [currentAppointmentId, setCurrentAppointmentId] = useState<number | null>(null);
  const [currentStaffName, setCurrentStaffName] = useState<string | null>(null);

  // Modals
  const [showCustomerModal, setShowCustomerModal] = useState<boolean>(false);
  const [discountModalIdx, setDiscountModalIdx] = useState<number | null>(null);
  const [itemDiscountInput, setItemDiscountInput] = useState<string>('0.00');
  const [showPaymentModal, setShowPaymentModal] = useState<boolean>(false);
  const [completedSale, setCompletedSale] = useState<Sale | null>(null);

  // Sync total item count to parent for Mobile Bottom Nav badge
  useEffect(() => {
    const totalCount = cart.reduce((sum, item) => sum + item.quantity, 0);
    onCartCountChange?.(totalCount);
  }, [cart, onCartCountChange]);

  // Payment Modal State
  const [selectedMethod, setSelectedMethod] = useState<'cash' | 'card' | 'qr' | 'other'>('cash');
  const [amountTendered, setAmountTendered] = useState<number>(0);
  const [amountTenderedInput, setAmountTenderedInput] = useState<string>('0.00');
  const [transactionNotes, setTransactionNotes] = useState<string>('');
  const [isProcessingPayment, setIsProcessingPayment] = useState<boolean>(false);

  // Customer Dialog State
  const [phoneSearchQuery, setPhoneSearchQuery] = useState<string>('');
  const [isSearchingCustomer, setIsSearchingCustomer] = useState<boolean>(false);
  const [customerSearchResults, setCustomerSearchResults] = useState<Customer[]>([]);
  const [searchMessage, setSearchMessage] = useState<string | null>(null);
  const [newName, setNewName] = useState<string>('');
  const [newPhone, setNewPhone] = useState<string>('');
  const [newCustError, setNewCustError] = useState<string | null>(null);

  /* ── Initial Data Loading ─────────────────────────────── */
  const loadInitialData = useCallback(async () => {
    setIsLoading(true);
    try {
      const [prodRes, catRes] = await Promise.all([
        productApi.getAll(),
        categoryApi.getAll(),
      ]);

      // Normalize products numeric price and category_id
      const normalizedProducts: Product[] = (prodRes.data?.data ?? []).map((p: any) => ({
        ...p,
        price: Number(p.price) || 0,
        category_id: p.category_id !== null && p.category_id !== undefined ? Number(p.category_id) : null,
      }));

      setProducts(normalizedProducts);
      setCategories(catRes.data?.data ?? []);

      // Check preloads
      if (preloadCustomer && preloadCustomer.name && preloadCustomer.name !== 'Walk-in') {
        setSelectedCustomer(preloadCustomer);
      }
      if (preloadAppointmentId) {
        setCurrentAppointmentId(preloadAppointmentId);
      }
      if (preloadStaffName) {
        setCurrentStaffName(preloadStaffName);
      }
      if (preloadProducts && preloadProducts.length > 0) {
        const initialCart: LocalCartItem[] = [];
        for (const p of preloadProducts) {
          const unitPrice = Number(p.price) || 0;
          const existing = initialCart.find((it) => it.product.id === p.id);
          if (existing) {
            existing.quantity += 1;
            existing.lineTotal = Math.max(0, unitPrice * existing.quantity - existing.discount);
          } else {
            initialCart.push({
              product: { ...p, price: unitPrice },
              quantity: 1,
              discount: 0,
              lineTotal: unitPrice,
            });
          }
        }
        setCart(initialCart);
      }
    } catch (err) {
      console.error('Error loading products/categories:', err);
      toast.error('Failed to load products and categories');
    } finally {
      setIsLoading(false);
    }
  }, [preloadCustomer, preloadProducts, preloadAppointmentId, preloadStaffName]);

  useEffect(() => {
    loadInitialData();
  }, [loadInitialData]);

  /* ── Financial Calculations ───────────────────────────── */
  const subtotal = cart.reduce((acc, item) => acc + (Number(item.product.price) || 0) * item.quantity, 0);
  const itemDiscountTotal = cart.reduce((acc, item) => acc + (Number(item.discount) || 0), 0);
  const taxableAmount = Math.max(0, subtotal - itemDiscountTotal - overallDiscount);
  const tax = taxableAmount * 0.08;
  const grandTotal = taxableAmount + tax;

  /* ── Cart Operations ──────────────────────────────────── */
  const handleAddToCart = (product: Product) => {
    const unitPrice = Number(product.price) || 0;
    setCart((prev) => {
      const existingIdx = prev.findIndex((it) => it.product.id === product.id);
      if (existingIdx !== -1) {
        const updated = [...prev];
        const item = updated[existingIdx];
        const newQty = item.quantity + 1;
        const lineDiscount = Number(item.discount) || 0;
        updated[existingIdx] = {
          ...item,
          quantity: newQty,
          lineTotal: Math.max(0, unitPrice * newQty - lineDiscount),
        };
        return updated;
      } else {
        return [
          ...prev,
          {
            product: { ...product, price: unitPrice },
            quantity: 1,
            discount: 0,
            lineTotal: unitPrice,
          },
        ];
      }
    });
  };

  const handleUpdateQuantity = (idx: number, delta: number) => {
    setCart((prev) => {
      const updated = [...prev];
      const item = updated[idx];
      const newQty = item.quantity + delta;
      if (newQty <= 0) {
        updated.splice(idx, 1);
      } else {
        const unitPrice = Number(item.product.price) || 0;
        const lineDiscount = Number(item.discount) || 0;
        updated[idx] = {
          ...item,
          quantity: newQty,
          lineTotal: Math.max(0, unitPrice * newQty - lineDiscount),
        };
      }
      return updated;
    });
  };

  const handleApplyItemDiscount = () => {
    if (discountModalIdx === null) return;
    const disc = parseFloat(itemDiscountInput) || 0;
    setCart((prev) => {
      const updated = [...prev];
      const item = updated[discountModalIdx];
      if (item) {
        const unitPrice = Number(item.product.price) || 0;
        const maxDisc = unitPrice * item.quantity;
        const validDiscount = Math.max(0, Math.min(disc, maxDisc));
        updated[discountModalIdx] = {
          ...item,
          discount: validDiscount,
          lineTotal: Math.max(0, maxDisc - validDiscount),
        };
      }
      return updated;
    });
    setDiscountModalIdx(null);
  };

  const handleOverallDiscountChange = (val: string) => {
    setOverallDiscountInput(val);
    const parsed = parseFloat(val) || 0;
    setOverallDiscount(Math.max(0, parsed));
  };

  const handleClearCart = () => {
    setCart([]);
    setOverallDiscount(0);
    setOverallDiscountInput('0.00');
    toast.info('Cart cleared');
  };

  /* ── Customer Dialog Handlers ─────────────────────────── */
  const handleOpenCustomerModal = () => {
    setPhoneSearchQuery('');
    setCustomerSearchResults([]);
    setSearchMessage(null);
    setNewName('');
    setNewPhone('');
    setNewCustError(null);
    setShowCustomerModal(true);
  };

  const handleSearchCustomer = async () => {
    const q = phoneSearchQuery.trim();
    if (!q) {
      setSearchMessage('Please enter a phone number to search.');
      setCustomerSearchResults([]);
      return;
    }
    setIsSearchingCustomer(true);
    setSearchMessage(null);
    try {
      const res = await customerApi.getAll(q);
      const list = res.data?.data ?? [];
      const cleanQ = q.replace(/\D/g, '');
      const filtered = list.filter((c) => {
        const cleanPhone = (c.phone || '').replace(/\D/g, '');
        return cleanPhone.includes(cleanQ) || (c.phone && c.phone.includes(q));
      });
      const finalResults = filtered.length > 0 ? filtered : list;
      setCustomerSearchResults(finalResults);
      if (finalResults.length === 0) {
        setSearchMessage(`No customer found with phone "${q}".`);
        if (!newPhone) {
          setNewPhone(q);
        }
      }
    } catch {
      setSearchMessage('Error searching customer. Please try again.');
    } finally {
      setIsSearchingCustomer(false);
    }
  };

  const handleAssignExistingCustomer = (c: Customer) => {
    setSelectedCustomer(c);
    setTempNewCustomer(null);
    setShowCustomerModal(false);
    toast.success(`Assigned customer "${c.name}"`);
  };

  const handleSaveTempNewCustomer = () => {
    const name = newName.trim();
    const phone = newPhone.trim();
    if (!name) {
      setNewCustError('Customer Name is required.');
      return;
    }
    if (!phone) {
      setNewCustError('Phone Number is required.');
      return;
    }
    setTempNewCustomer({ name, phone });
    setSelectedCustomer(null);
    setShowCustomerModal(false);
    toast.success(`Temporary customer "${name}" assigned to cart.`);
  };

  const handleRemoveCustomer = () => {
    setSelectedCustomer(null);
    setTempNewCustomer(null);
    setCurrentAppointmentId(null);
    setCurrentStaffName(null);
    setShowCustomerModal(false);
    toast.info('Customer removed. Order will checkout as Walk-in Customer.');
  };

  /* ── Payment & Checkout ───────────────────────────────── */
  const handleOpenPayment = () => {
    setSelectedMethod('cash');
    setAmountTendered(grandTotal);
    setAmountTenderedInput(fmtMoney(grandTotal));
    setTransactionNotes('');
    setShowPaymentModal(true);
  };

  const handleConfirmPayment = async () => {
    setIsProcessingPayment(true);
    try {
      let custId: number | null = null;
      let custName = 'Walk-in';
      let custPhone = '';

      if (selectedCustomer) {
        custId = selectedCustomer.id;
        custName = selectedCustomer.name;
        custPhone = selectedCustomer.phone;
      } else if (tempNewCustomer) {
        try {
          const res = await customerApi.create({
            name: tempNewCustomer.name,
            phone: tempNewCustomer.phone,
            is_walk_in: false,
          });
          const created = res.data?.data;
          if (created) {
            custId = created.id;
            custName = created.name;
            custPhone = created.phone;
          } else {
            custName = tempNewCustomer.name;
            custPhone = tempNewCustomer.phone;
          }
        } catch {
          custName = tempNewCustomer.name;
          custPhone = tempNewCustomer.phone;
        }
        setTempNewCustomer(null);
      }

      const tendered = selectedMethod === 'cash' ? amountTendered : grandTotal;
      const change = selectedMethod === 'cash' ? Math.max(0, tendered - grandTotal) : 0;

      const salePayload = {
        business_id: 1,
        appointment_id: currentAppointmentId,
        customer_id: custId,
        customer_name: custName,
        customer_phone: custPhone,
        staff_id: null,
        staff_name: currentStaffName ?? '',
        subtotal,
        item_discount_total: itemDiscountTotal,
        overall_discount: overallDiscount,
        tax_amount: tax,
        total_amount: grandTotal,
        payment_method: selectedMethod,
        amount_tendered: tendered,
        change_amount: change,
        items: cart.map((ci) => ({
          product_id: ci.product.id,
          product_name: ci.product.name,
          unit_price: Number(ci.product.price) || 0,
          quantity: ci.quantity,
          discount: Number(ci.discount) || 0,
          line_total: Number(ci.lineTotal) || 0,
        })),
        notes: transactionNotes,
      };

      const res = await saleApi.create(salePayload);
      const sale = res.data?.data;

      if (sale) {
        setShowPaymentModal(false);
        setCompletedSale(sale);
        toast.success('Sale completed and recorded!');
      } else {
        toast.error('Failed to complete sale');
      }
    } catch {
      toast.error('Error processing transaction');
    } finally {
      setIsProcessingPayment(false);
    }
  };

  const handleResetForNewSale = () => {
    setCart([]);
    setOverallDiscount(0);
    setOverallDiscountInput('0.00');
    setSelectedCustomer(null);
    setTempNewCustomer(null);
    setCurrentAppointmentId(null);
    setCurrentStaffName(null);
    setCompletedSale(null);
  };

  /* ── Filtered Products ────────────────────────────────── */
  const filteredProducts = selectedCategoryId === null
    ? products
    : products.filter((p) => Number(p.category_id) === Number(selectedCategoryId));

  // Active customer labels
  const hasActiveCustomer = Boolean(selectedCustomer || tempNewCustomer);
  const activeCustomerName = selectedCustomer?.name ?? tempNewCustomer?.name ?? '';
  const activeCustomerPhone = selectedCustomer?.phone ?? tempNewCustomer?.phone ?? '';

  // Cash change calculation
  const cashChange = amountTendered - grandTotal;

  /* ── Render ───────────────────────────────────────────── */
  if (isLoading) {
    return (
      <div style={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center' }}>
        <div className="table-loader-spinner" style={{ borderColor: '#E11D48', borderTopColor: 'transparent', width: '32px', height: '32px' }} />
      </div>
    );
  }

  return (
    <div className={`cart-pos-container cart-pos-container--mobile-${mobileViewMode}`}>
      {/* ── Mobile Mode Switcher Bar ──────────────────────── */}
      {/* <div className="cart-mobile-mode-bar">
        <button
          type="button"
          className={`cart-mobile-mode-btn ${mobileViewMode === 'pos' ? 'cart-mobile-mode-btn--active' : ''
            }`}
          onClick={() => onMobileViewModeChange?.('pos')}
        >
          <LayoutGrid size={15} />
          <span>POS Catalog</span>
        </button>
        <button
          type="button"
          className={`cart-mobile-mode-btn ${mobileViewMode === 'cart' ? 'cart-mobile-mode-btn--active' : ''
            }`}
          onClick={() => onMobileViewModeChange?.('cart')}
        >
          <ShoppingCart size={15} />
          <span>Cart Register</span>
          {cart.length > 0 && (
            <span className="cart-mobile-mode-badge">
              {cart.reduce((s, i) => s + i.quantity, 0)}
            </span>
          )}
        </button>
      </div> */}

      {/* ── Left: Catalog Section ──────────────────────────── */}
      <section className="cart-catalog-section">
        {/* Category Filter Bar */}
        <div className="cart-category-bar">
          <button
            type="button"
            className={`cart-cat-tab ${selectedCategoryId === null ? 'cart-cat-tab--active' : ''}`}
            onClick={() => setSelectedCategoryId(null)}
          >
            <LayoutGrid size={15} color={selectedCategoryId === null ? '#F97316' : '#64748B'} />
            <span>All Items</span>
          </button>
          {categories.map((cat) => (
            <button
              key={cat.id}
              type="button"
              className={`cart-cat-tab ${selectedCategoryId === cat.id ? 'cart-cat-tab--active' : ''}`}
              onClick={() => setSelectedCategoryId(cat.id)}
            >
              <Tag size={14} color={selectedCategoryId === cat.id ? '#0F172A' : '#64748B'} />
              <span>{cat.name}</span>
            </button>
          ))}
        </div>

        {/* Product Catalog Grid */}
        <div className="cart-product-grid-wrap">
          {filteredProducts.length === 0 ? (
            <div style={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', color: '#94A3B8', fontSize: '13px' }}>
              No products found in this category.
            </div>
          ) : (
            <div className="cart-product-grid">
              {filteredProducts.map((p) => {
                const inCart = cart.some((it) => it.product.id === p.id);
                return (
                  <div
                    key={p.id}
                    className={`cart-product-card ${inCart ? 'cart-product-card--in-cart' : ''}`}
                    onClick={() => handleAddToCart(p)}
                  >
                    <span className="cart-product-card__name">{p.name}</span>
                    {p.product_type !== 'normal' && (
                      <span className="cart-product-card__type-badge">{p.product_type}</span>
                    )}
                    <div className="cart-product-card__bottom">
                      <span className="cart-product-card__price">${fmtMoney(p.price)}</span>
                      <span className="cart-product-card__icon-btn">
                        {inCart ? <CheckCircle size={20} /> : <PlusCircle size={20} />}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Mobile Floating Bar for POS Mode */}
        {cart.length > 0 && (
          <div className="cart-mobile-floating-bar">
            <div className="cart-mobile-floating-bar__info">
              <span className="cart-mobile-floating-bar__count">
                {cart.reduce((s, i) => s + i.quantity, 0)}{' '}
                {cart.reduce((s, i) => s + i.quantity, 0) === 1
                  ? 'item'
                  : 'items'}
              </span>
              <span className="cart-mobile-floating-bar__total">
                ${fmtMoney(grandTotal)}
              </span>
            </div>
            <button
              type="button"
              className="cart-mobile-floating-bar__btn"
              onClick={() => onMobileViewModeChange?.('cart')}
            >
              <span>View Cart</span>
              <ChevronRight size={16} />
            </button>
          </div>
        )}
      </section>

      {/* ── Right: Cart Register Section ───────────────────── */}
      <aside className="cart-register-panel">
        {/* Register Top Header */}
        <div className="cart-register-header">
          <div className="cart-register-title-wrap">
            <button
              type="button"
              className="cart-mobile-back-catalog-btn"
              onClick={() => onMobileViewModeChange?.('pos')}
              title="Back to Product Catalog"
            >
              <ChevronLeft size={16} />
              <span>Catalog</span>
            </button>
            <span className="cart-register-title">Register ({cart.length})</span>
          </div>
          {cart.length > 0 && (
            <button type="button" className="cart-register-clear-btn" onClick={handleClearCart}>
              Clear All
            </button>
          )}
        </div>

        {/* Customer Box */}
        <div className="cart-customer-box">
          {!hasActiveCustomer ? (
            <button
              type="button"
              className="cart-customer-add-btn"
              onClick={handleOpenCustomerModal}
            >
              <div className="cart-customer-icon-wrap">
                <UserPlus size={15} />
              </div>
              <span>Add Customer</span>
            </button>
          ) : (
            <div className="cart-customer-card" onClick={handleOpenCustomerModal}>
              <div className="cart-customer-avatar">
                {activeCustomerName ? activeCustomerName[0].toUpperCase() : 'C'}
              </div>
              <div className="cart-customer-info">
                <div className="cart-customer-name-row">
                  <span className="cart-customer-name">{activeCustomerName}</span>
                  {tempNewCustomer && <span className="cart-customer-badge">New (Temp)</span>}
                  {currentAppointmentId && !tempNewCustomer && (
                    <span className="cart-customer-badge">Apt #{currentAppointmentId}</span>
                  )}
                </div>
                {activeCustomerPhone && (
                  <div className="cart-customer-phone">{activeCustomerPhone}</div>
                )}
              </div>
              <Edit2 size={15} color="#E11D48" />
            </div>
          )}
        </div>

        {/* Cart Item Rows */}
        <div className="cart-items-wrap">
          {cart.length === 0 ? (
            <div className="cart-items-empty">
              <ShoppingCart size={40} color="#CBD5E1" />
              <div style={{ fontSize: '13px', fontWeight: 600, color: '#64748B' }}>Cart is empty</div>
              <div style={{ fontSize: '11px', color: '#94A3B8' }}>Tap items on the left to add</div>
            </div>
          ) : (
            cart.map((item, idx) => (
              <div key={item.product.id} className="cart-item-row">
                <div className="cart-item-info">
                  <div className="cart-item-title">{item.product.name}</div>
                  <div className="cart-item-pricing">
                    <span>${fmtMoney(item.product.price)}</span>
                    {item.discount > 0 && (
                      <span className="cart-item-discount-tag">-${fmtMoney(item.discount)}</span>
                    )}
                  </div>
                </div>

                {/* Discount button */}
                <button
                  type="button"
                  className={`cart-item-discount-btn ${item.discount > 0 ? 'cart-item-discount-btn--active' : ''}`}
                  title="Line Discount"
                  onClick={() => {
                    setDiscountModalIdx(idx);
                    setItemDiscountInput(fmtMoney(item.discount));
                  }}
                >
                  <Tag size={15} />
                </button>

                {/* Quantity Controls */}
                <div className="cart-qty-ctrls">
                  <button
                    type="button"
                    className="cart-qty-btn"
                    onClick={() => handleUpdateQuantity(idx, -1)}
                    title={item.quantity === 1 ? 'Remove' : 'Decrease'}
                  >
                    {item.quantity === 1 ? <Trash2 size={13} color="#E11D48" /> : <Minus size={13} />}
                  </button>
                  <span className="cart-qty-count">{item.quantity}</span>
                  <button
                    type="button"
                    className="cart-qty-btn"
                    onClick={() => handleUpdateQuantity(idx, 1)}
                    title="Increase"
                  >
                    <Plus size={13} />
                  </button>
                </div>

                {/* Line Total */}
                <div className="cart-item-line-total">${fmtMoney(item.lineTotal)}</div>
              </div>
            ))
          )}
        </div>

        {/* Financial Summary & Checkout Button */}
        <div className="cart-summary-section">
          <div className="cart-summary-row">
            <span>Subtotal</span>
            <span className="cart-summary-val">${fmtMoney(subtotal)}</span>
          </div>

          {itemDiscountTotal > 0 && (
            <div className="cart-summary-row">
              <span>Item Discounts</span>
              <span className="cart-summary-val cart-summary-val--discount">
                -${fmtMoney(itemDiscountTotal)}
              </span>
            </div>
          )}

          <div className="cart-summary-row">
            <span>Overall Discount</span>
            <div className="cart-discount-input-wrap">
              <span className="cart-discount-prefix">-$</span>
              <input
                type="number"
                step="0.01"
                min="0"
                className="cart-discount-input"
                value={overallDiscountInput}
                onChange={(e) => handleOverallDiscountChange(e.target.value)}
              />
            </div>
          </div>

          <div className="cart-summary-row">
            <span>Tax (8%)</span>
            <span className="cart-summary-val">${fmtMoney(tax)}</span>
          </div>

          <div className="cart-grand-total-row">
            <span className="cart-grand-total-label">Grand Total</span>
            <span className="cart-grand-total-amount">${fmtMoney(grandTotal)}</span>
          </div>

          <button
            type="button"
            className="cart-checkout-btn"
            disabled={cart.length === 0}
            onClick={handleOpenPayment}
          >
            <Banknote size={18} />
            <span>Proceed to Payment (${fmtMoney(grandTotal)})</span>
          </button>
        </div>
      </aside>

      {/* ── MODAL 1: Customer Selection Dialog (720px) ────── */}
      {showCustomerModal && (
        <div className="cart-modal-overlay" onClick={() => setShowCustomerModal(false)}>
          <div className="cust-dialog" onClick={(e) => e.stopPropagation()} role="dialog">
            {/* Header */}
            <div className="cust-dialog__header">
              <div>
                <h3 className="cust-dialog__title">Customer Selection</h3>
                <p className="cust-dialog__desc">
                  Search existing customer by phone or register a new customer for this order.
                </p>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                {hasActiveCustomer && (
                  <button
                    type="button"
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '7px 12px',
                      background: '#FFF1F2',
                      border: '1px solid #FDA4AF',
                      borderRadius: '8px',
                      color: '#E11D48',
                      fontSize: '12px',
                      fontWeight: 600,
                      cursor: 'pointer',
                    }}
                    onClick={handleRemoveCustomer}
                  >
                    <UserMinus size={15} />
                    <span>Remove Customer</span>
                  </button>
                )}
                <button
                  type="button"
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}
                  onClick={() => setShowCustomerModal(false)}
                >
                  <X size={20} />
                </button>
              </div>
            </div>

            {/* Currently Assigned Banner */}
            {hasActiveCustomer && (
              <div className="cust-assigned-banner">
                <UserCheck size={16} />
                <span>Currently Assigned: <strong>{activeCustomerName}</strong> {activeCustomerPhone ? `(${activeCustomerPhone})` : ''}</span>
                <span style={{ marginLeft: 'auto', fontStyle: 'italic', fontSize: '11px' }}>
                  {tempNewCustomer ? 'Temporary in Memory' : 'Existing in Database'}
                </span>
              </div>
            )}

            {/* Two Columns */}
            <div className="cust-dialog__columns">
              {/* LEFT: Existing Customer Search */}
              <div className="cust-col">
                <div className="cust-col__header">
                  <div style={{ padding: '6px', borderRadius: '8px', background: '#EEF2FF', color: '#4F46E5', display: 'flex' }}>
                    <Search size={16} />
                  </div>
                  <span className="cust-col__title">Existing Customer</span>
                </div>
                <p style={{ fontSize: '12px', color: '#64748B', margin: '2px 0 10px' }}>
                  Enter phone number to search database and assign customer.
                </p>

                <div className="cust-search-row">
                  <input
                    type="tel"
                    className="cust-search-input"
                    placeholder="Enter Phone Number..."
                    value={phoneSearchQuery}
                    onChange={(e) => setPhoneSearchQuery(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleSearchCustomer()}
                  />
                  <button
                    type="button"
                    className="cust-search-btn"
                    disabled={isSearchingCustomer}
                    onClick={handleSearchCustomer}
                  >
                    {isSearchingCustomer ? (
                      <span className="table-loader-spinner" style={{ width: '14px', height: '14px', borderColor: '#fff', borderTopColor: 'transparent' }} />
                    ) : (
                      'Search'
                    )}
                  </button>
                </div>

                <div className="cust-results-list">
                  {customerSearchResults.length > 0 ? (
                    customerSearchResults.map((c) => {
                      const isCurrent = selectedCustomer?.id === c.id;
                      return (
                        <div
                          key={c.id}
                          className={`cust-result-item ${isCurrent ? 'cust-result-item--active' : ''}`}
                        >
                          <div
                            style={{
                              width: '30px',
                              height: '30px',
                              borderRadius: '50%',
                              background: '#4F46E5',
                              color: '#fff',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              fontWeight: 700,
                              fontSize: '12px',
                              marginRight: '10px',
                            }}
                          >
                            {c.name ? c.name[0].toUpperCase() : 'C'}
                          </div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ fontSize: '13px', fontWeight: 600, color: '#0F172A' }}>{c.name}</div>
                            <div style={{ fontSize: '11.5px', color: '#64748B' }}>{c.phone}</div>
                          </div>
                          <button
                            type="button"
                            className={`cust-result-assign-btn ${isCurrent ? 'cust-result-assign-btn--active' : ''}`}
                            onClick={() => handleAssignExistingCustomer(c)}
                          >
                            {isCurrent ? 'Assigned' : 'Assign'}
                          </button>
                        </div>
                      );
                    })
                  ) : searchMessage ? (
                    <div style={{ padding: '12px', borderRadius: '8px', background: '#FFFBEB', border: '1px solid #FDE68A', color: '#92400E', fontSize: '12px' }}>
                      {searchMessage}
                    </div>
                  ) : (
                    <div style={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', color: '#94A3B8', fontSize: '12px', textAlign: 'center' }}>
                      Enter phone number above to search existing customers.
                    </div>
                  )}
                </div>
              </div>

              <div className="cust-col-divider" />

              {/* RIGHT: New Customer */}
              <div className="cust-col">
                <div className="cust-col__header">
                  <div style={{ padding: '6px', borderRadius: '8px', background: '#FFF1F2', color: '#E11D48', display: 'flex' }}>
                    <UserPlus size={16} />
                  </div>
                  <span className="cust-col__title">New Customer</span>
                </div>
                <p style={{ fontSize: '12px', color: '#64748B', margin: '2px 0 12px' }}>
                  Enter name and phone. Stored in memory; saved to DB when order completes.
                </p>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <div>
                    <label style={{ fontSize: '12px', fontWeight: 600, color: '#334155', display: 'block', marginBottom: '4px' }}>
                      Customer Name *
                    </label>
                    <input
                      type="text"
                      className="cust-search-input"
                      style={{ width: '100%', boxSizing: 'border-box' }}
                      placeholder="Enter full name..."
                      value={newName}
                      onChange={(e) => setNewName(e.target.value)}
                    />
                  </div>

                  <div>
                    <label style={{ fontSize: '12px', fontWeight: 600, color: '#334155', display: 'block', marginBottom: '4px' }}>
                      Phone Number *
                    </label>
                    <input
                      type="tel"
                      className="cust-search-input"
                      style={{ width: '100%', boxSizing: 'border-box' }}
                      placeholder="Enter phone number..."
                      value={newPhone}
                      onChange={(e) => setNewPhone(e.target.value)}
                    />
                  </div>

                  <div style={{ padding: '10px', borderRadius: '8px', background: '#F8FAFC', border: '1px solid #E2E8F0', display: 'flex', gap: '6px', marginTop: '4px' }}>
                    <AlertCircle size={15} color="#64748B" style={{ flexShrink: 0, marginTop: '2px' }} />
                    <span style={{ fontSize: '11px', color: '#64748B', lineHeight: '1.4' }}>
                      Customer info will not be saved to DB yet. Only after order payment is completed will it be stored in the database.
                    </span>
                  </div>

                  {newCustError && (
                    <div style={{ fontSize: '11.5px', color: '#E11D48', fontWeight: 600 }}>{newCustError}</div>
                  )}

                  <button
                    type="button"
                    style={{
                      marginTop: '6px',
                      padding: '11px',
                      background: '#E11D48',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      fontSize: '13px',
                      fontWeight: 600,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '6px',
                      cursor: 'pointer',
                    }}
                    onClick={handleSaveTempNewCustomer}
                  >
                    <Save size={15} />
                    <span>Save Customer</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── MODAL 2: Line Discount Popover ───────────────── */}
      {discountModalIdx !== null && (
        <div className="cart-modal-overlay" onClick={() => setDiscountModalIdx(null)}>
          <div
            style={{
              width: '320px',
              background: '#fff',
              borderRadius: '12px',
              padding: '20px',
              boxShadow: '0 20px 40px rgba(0,0,0,0.18)',
            }}
            onClick={(e) => e.stopPropagation()}
            role="dialog"
          >
            <h4 style={{ margin: '0 0 4px', fontSize: '15px', fontWeight: 700, color: '#0F172A' }}>
              Discount: {cart[discountModalIdx]?.product.name}
            </h4>
            <div style={{ fontSize: '12.5px', color: '#64748B', marginBottom: '14px' }}>
              Unit Price: ${fmtMoney(cart[discountModalIdx]?.product.price)} × {cart[discountModalIdx]?.quantity}
            </div>

            <div style={{ position: 'relative', marginBottom: '16px' }}>
              <span style={{ position: 'absolute', left: '10px', top: '9px', fontSize: '13px', color: '#64748B', fontWeight: 600 }}>
                $
              </span>
              <input
                type="number"
                step="0.01"
                min="0"
                style={{
                  width: '100%',
                  height: '38px',
                  padding: '0 12px 0 24px',
                  background: '#F1F5F9',
                  border: '1px solid #CBD5E1',
                  borderRadius: '8px',
                  fontSize: '13px',
                  outline: 'none',
                  boxSizing: 'border-box',
                }}
                value={itemDiscountInput}
                onChange={(e) => setItemDiscountInput(e.target.value)}
                autoFocus
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <button
                type="button"
                style={{ padding: '8px 14px', background: '#F1F5F9', border: 'none', borderRadius: '8px', fontSize: '12.5px', cursor: 'pointer' }}
                onClick={() => setDiscountModalIdx(null)}
              >
                Cancel
              </button>
              <button
                type="button"
                style={{ padding: '8px 16px', background: '#E11D48', color: '#fff', border: 'none', borderRadius: '8px', fontSize: '12.5px', fontWeight: 600, cursor: 'pointer' }}
                onClick={handleApplyItemDiscount}
              >
                Apply
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── MODAL 3: Payment Checkout Modal (520px) ───────── */}
      {showPaymentModal && (
        <div className="cart-modal-overlay">
          <div className="payment-dialog" role="dialog">
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <h3 style={{ margin: 0, fontSize: '20px', fontWeight: 800, color: '#0F172A', fontFamily: 'var(--font-display)' }}>
                Complete Payment
              </h3>
              <button
                type="button"
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}
                onClick={() => setShowPaymentModal(false)}
              >
                <X size={20} />
              </button>
            </div>

            {/* Total Due Banner */}
            <div className="payment-total-banner">
              <div style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '1px', opacity: 0.8 }}>TOTAL DUE</div>
              <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', marginTop: '4px' }}>
                ${fmtMoney(grandTotal)}
              </div>
            </div>

            {/* Payment Method Selector */}
            <label style={{ fontSize: '13px', fontWeight: 600, color: '#1E293B', marginBottom: '8px', display: 'block' }}>
              Payment Method
            </label>
            <div className="payment-methods-grid">
              <div
                className={`payment-method-card ${selectedMethod === 'cash' ? 'payment-method-card--active' : ''}`}
                onClick={() => setSelectedMethod('cash')}
              >
                <Banknote size={24} />
                <span>Cash</span>
              </div>
              <div
                className={`payment-method-card ${selectedMethod === 'card' ? 'payment-method-card--active' : ''}`}
                onClick={() => setSelectedMethod('card')}
              >
                <CreditCard size={24} />
                <span>Card</span>
              </div>
              <div
                className={`payment-method-card ${selectedMethod === 'qr' ? 'payment-method-card--active' : ''}`}
                onClick={() => setSelectedMethod('qr')}
              >
                <QrCode size={24} />
                <span>QR Code</span>
              </div>
              <div
                className={`payment-method-card ${selectedMethod === 'other' ? 'payment-method-card--active' : ''}`}
                onClick={() => setSelectedMethod('other')}
              >
                <Wallet size={24} />
                <span>Other</span>
              </div>
            </div>

            {/* Cash details */}
            {selectedMethod === 'cash' && (
              <div>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#1E293B', marginBottom: '6px', display: 'block' }}>
                  Amount Tendered
                </label>
                <div style={{ position: 'relative' }}>
                  <span style={{ position: 'absolute', left: '10px', top: '9px', fontSize: '13px', color: '#64748B', fontWeight: 600 }}>$</span>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    style={{
                      width: '100%',
                      height: '38px',
                      padding: '0 12px 0 24px',
                      background: '#F1F5F9',
                      border: '1px solid #CBD5E1',
                      borderRadius: '8px',
                      fontSize: '13px',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                    value={amountTenderedInput}
                    onChange={(e) => {
                      setAmountTenderedInput(e.target.value);
                      setAmountTendered(parseFloat(e.target.value) || 0);
                    }}
                  />
                </div>

                {/* Quick tender chips */}
                <div className="tender-chips-row">
                  {[grandTotal, 20, 50, 100, 200].map((amt, i) => (
                    <button
                      key={i}
                      type="button"
                      className="tender-chip"
                      onClick={() => {
                        const val = amt === grandTotal ? grandTotal : amt;
                        setAmountTendered(val);
                        setAmountTenderedInput(fmtMoney(val));
                      }}
                    >
                      {amt === grandTotal ? 'Exact' : `$${amt}`}
                    </button>
                  ))}
                </div>

                {/* Change Due alert */}
                <div className={`payment-change-alert ${cashChange >= 0 ? 'payment-change-alert--due' : 'payment-change-alert--insufficient'}`}>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>
                    {cashChange >= 0 ? 'Change Due' : 'Insufficient'}
                  </span>
                  <span style={{ fontSize: '18px', fontWeight: 800, fontFamily: 'var(--font-display)' }}>
                    ${fmtMoney(Math.abs(cashChange))}
                  </span>
                </div>
              </div>
            )}

            {/* Transaction Notes */}
            <div style={{ marginTop: '6px' }}>
              <label style={{ fontSize: '12px', fontWeight: 600, color: '#64748B', marginBottom: '4px', display: 'block' }}>
                Transaction Notes (optional)
              </label>
              <input
                type="text"
                placeholder="Order or table notes..."
                style={{
                  width: '100%',
                  height: '36px',
                  padding: '0 12px',
                  background: '#F1F5F9',
                  border: '1px solid #CBD5E1',
                  borderRadius: '8px',
                  fontSize: '13px',
                  outline: 'none',
                  boxSizing: 'border-box',
                }}
                value={transactionNotes}
                onChange={(e) => setTransactionNotes(e.target.value)}
              />
            </div>

            {/* Confirm Payment button */}
            <button
              type="button"
              className="payment-confirm-btn"
              disabled={isProcessingPayment || (selectedMethod === 'cash' && cashChange < 0)}
              onClick={handleConfirmPayment}
            >
              {isProcessingPayment ? (
                <span className="table-loader-spinner" style={{ width: '16px', height: '16px', borderColor: '#fff', borderTopColor: 'transparent' }} />
              ) : (
                <>
                  <CheckCircle2 size={18} />
                  <span>Confirm Payment & Save Sale</span>
                </>
              )}
            </button>
          </div>
        </div>
      )}

      {/* ── MODAL 4: Receipt Detail Modal (420px) ─────────── */}
      {completedSale && (
        <div className="cart-modal-overlay">
          <div className="receipt-dialog" role="dialog">
            <div className="receipt-icon-circle">
              <CheckCircle size={36} />
            </div>

            <div className="receipt-dialog-title">Payment Successful!</div>
            <div className="receipt-dialog-number">
              {formatReceiptNumber(completedSale.id, completedSale.created_at)}
            </div>

            <div className="receipt-content-box">
              <div className="receipt-row">
                <span>Customer</span>
                <span className="receipt-row__val">
                  {completedSale.customer_name || 'Walk-in'}
                </span>
              </div>
              {completedSale.customer_phone && (
                <div className="receipt-row">
                  <span>Phone</span>
                  <span className="receipt-row__val">{completedSale.customer_phone}</span>
                </div>
              )}
              {completedSale.staff_name && (
                <div className="receipt-row">
                  <span>Staff</span>
                  <span className="receipt-row__val">{completedSale.staff_name}</span>
                </div>
              )}
              <div className="receipt-row">
                <span>Payment</span>
                <span className="receipt-row__val">
                  {getPaymentMethodLabel(completedSale.payment_method)}
                </span>
              </div>

              {/* Items List */}
              <div className="receipt-items-list">
                <div style={{ fontSize: '11px', fontWeight: 700, color: '#64748B', textTransform: 'uppercase' }}>
                  Items
                </div>
                {completedSale.items.map((it, idx) => (
                  <div key={idx} className="receipt-item-line">
                    <span style={{ color: '#334155' }}>
                      {it.product_name} × {it.quantity}
                    </span>
                    <span style={{ fontWeight: 600, color: '#0F172A' }}>
                      ${fmtMoney(it.line_total)}
                    </span>
                  </div>
                ))}
              </div>

              {/* Financials */}
              <div className="receipt-row">
                <span>Subtotal</span>
                <span className="receipt-row__val">${fmtMoney(completedSale.subtotal)}</span>
              </div>
              {Number(completedSale.item_discount_total) > 0 && (
                <div className="receipt-row">
                  <span>Item Discounts</span>
                  <span className="receipt-row__val" style={{ color: '#E11D48' }}>
                    -${fmtMoney(completedSale.item_discount_total)}
                  </span>
                </div>
              )}
              {Number(completedSale.overall_discount) > 0 && (
                <div className="receipt-row">
                  <span>Overall Discount</span>
                  <span className="receipt-row__val" style={{ color: '#E11D48' }}>
                    -${fmtMoney(completedSale.overall_discount)}
                  </span>
                </div>
              )}
              <div className="receipt-row">
                <span>Tax (8%)</span>
                <span className="receipt-row__val">${fmtMoney(completedSale.tax_amount)}</span>
              </div>
              <div className="receipt-row" style={{ marginTop: '4px', paddingTop: '4px', borderTop: '1px solid #E2E8F0' }}>
                <span style={{ fontWeight: 800, fontSize: '14px', color: '#0F172A' }}>GRAND TOTAL</span>
                <span style={{ fontWeight: 800, fontSize: '18px', color: '#E11D48', fontFamily: 'var(--font-display)' }}>
                  ${fmtMoney(completedSale.total_amount)}
                </span>
              </div>

              {completedSale.payment_method === 'cash' && (
                <>
                  <div className="receipt-row" style={{ marginTop: '4px' }}>
                    <span>Amount Paid</span>
                    <span className="receipt-row__val">${fmtMoney(completedSale.amount_tendered)}</span>
                  </div>
                  <div className="receipt-row">
                    <span>Change</span>
                    <span className="receipt-row__val" style={{ color: '#10B981' }}>
                      ${fmtMoney(completedSale.change_amount)}
                    </span>
                  </div>
                </>
              )}
            </div>

            {/* Actions */}
            <div className="receipt-actions-row">
              <button
                type="button"
                className="receipt-btn receipt-btn--print"
                onClick={() => toast.success('Receipt sent to printer')}
              >
                <Printer size={15} />
                <span>Print</span>
              </button>

              {onNavigateToSalesHistory && (
                <button
                  type="button"
                  className="receipt-btn receipt-btn--history"
                  onClick={() => {
                    handleResetForNewSale();
                    onNavigateToSalesHistory();
                  }}
                >
                  <History size={15} />
                  <span>Sales History</span>
                </button>
              )}

              <button
                type="button"
                className="receipt-btn receipt-btn--new"
                onClick={handleResetForNewSale}
              >
                <ShoppingCart size={15} />
                <span>New Sale</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
