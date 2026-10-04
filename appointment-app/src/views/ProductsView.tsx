import { useState, useEffect, useCallback } from 'react';
import { toast } from 'react-toastify';
import {
  Search,
  PackagePlus,
  Package,
  Trash2,
} from 'lucide-react';
import { productApi, type Product } from '../api/productApi';
import { categoryApi, type Category } from '../api/categoryApi';
import '../styles/products.css';

/* ── Filter type labels ───────────────────────────────── */
const TYPE_TABS: { key: string; label: string }[] = [
  { key: 'all', label: 'All Products' },
  { key: 'normal', label: 'Normal Products' },
  { key: 'modifier', label: 'Modifiers & Add-ons' },
  { key: 'combo', label: 'Combo Bundles' },
];

const TYPE_BADGE_LABELS: Record<string, string> = {
  normal: 'Normal',
  modifier: 'Modifier',
  combo: 'Combo Bundle',
};

/* ================================================================
   ProductsView
   ================================================================ */
export default function ProductsView() {
  /* ── State ────────────────────────────────────────────── */
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const [selectedType, setSelectedType] = useState('all');
  const [selectedCategoryId, setSelectedCategoryId] = useState<number | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  const [showAddModal, setShowAddModal] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Product | null>(null);

  /* ── Data Loading ─────────────────────────────────────── */
  const loadData = useCallback(async () => {
    setIsLoading(true);
    try {
      const [catRes, prodRes] = await Promise.all([
        categoryApi.getAll(),
        productApi.getAll({
          category_id: selectedCategoryId ?? undefined,
          product_type: selectedType === 'all' ? undefined : selectedType,
          search: searchQuery || undefined,
        }),
      ]);
      setCategories(catRes.data?.data ?? []);
      setProducts(prodRes.data?.data ?? []);
    } catch {
      toast.error('Failed to load products');
    } finally {
      setIsLoading(false);
    }
  }, [selectedType, selectedCategoryId, searchQuery]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  /* ── Delete handler ───────────────────────────────────── */
  const handleDeleteConfirm = async () => {
    if (!deleteTarget) return;
    try {
      await productApi.delete(deleteTarget.id);
      toast.success(`"${deleteTarget.name}" deleted`);
      setDeleteTarget(null);
      loadData();
    } catch {
      toast.error('Failed to delete product');
    }
  };

  /* ── Render ───────────────────────────────────────────── */
  return (
    <div className="products-view">
      {/* ── Top Controls: Search + Add ──────────────────── */}
      <div className="products-controls">
        <div className="products-search-box">
          <Search size={20} />
          <input
            type="text"
            placeholder="Search products by name, SKU, or notes..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <button
          type="button"
          className="products-add-btn"
          onClick={() => setShowAddModal(true)}
        >
          <PackagePlus size={20} />
          <span>New Product</span>
        </button>
      </div>

      {/* ── Filter Bar ─────────────────────────────────── */}
      <div className="products-filter-bar">
        {TYPE_TABS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            className={`pf-type-tab ${selectedType === tab.key ? 'pf-type-tab--active' : ''}`}
            onClick={() => setSelectedType(tab.key)}
          >
            {tab.key === 'all' ? `${tab.label} (${products.length})` : tab.label}
          </button>
        ))}
        <span className="pf-divider" />
        <button
          type="button"
          className={`pf-cat-chip ${selectedCategoryId === null ? 'pf-cat-chip--active' : ''}`}
          onClick={() => setSelectedCategoryId(null)}
        >
          All Categories
        </button>
        {categories.map((c) => (
          <button
            key={c.id}
            type="button"
            className={`pf-cat-chip ${selectedCategoryId === c.id ? 'pf-cat-chip--active' : ''}`}
            onClick={() => setSelectedCategoryId(c.id)}
          >
            {c.name}
          </button>
        ))}
      </div>

      {/* ── Content Area ───────────────────────────────── */}
      {isLoading ? (
        <div className="products-loading">
          <div className="spinner" />
        </div>
      ) : products.length === 0 ? (
        <div className="products-empty">
          <Package size={54} />
          <span className="products-empty__title">No products matched filter</span>
        </div>
      ) : (
        <div className="products-grid-wrap">
          <div className="products-grid">
            {products.map((prod, idx) => (
              <div
                key={prod.id}
                className="product-card"
                style={{ animationDelay: `${idx * 0.04}s` }}
              >
                <div className="product-card__header">
                  <span
                    className={`product-card__type-badge product-card__type-badge--${prod.product_type}`}
                  >
                    {TYPE_BADGE_LABELS[prod.product_type] ?? 'Normal'}
                  </span>
                  <button
                    type="button"
                    className="product-card__delete-btn"
                    title="Delete product"
                    onClick={() => setDeleteTarget(prod)}
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
                <div className="product-card__name">{prod.name}</div>
                {prod.sku && <div className="product-card__sku">SKU: {prod.sku}</div>}
                <div className="product-card__desc">
                  {prod.description || 'No description'}
                </div>
                <div className="product-card__footer">
                  <span className="product-card__price">
                    ${Number(prod.price).toFixed(2)}
                  </span>
                  {prod.product_type === 'combo' && (
                    <span className="product-card__combo-count">
                      {prod.combo_items?.length ?? 0} items bundled
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── Add Product Modal ──────────────────────────── */}
      {showAddModal && (
        <AddProductModal
          categories={categories}
          onClose={() => setShowAddModal(false)}
          onSaved={() => {
            setShowAddModal(false);
            loadData();
          }}
        />
      )}

      {/* ── Delete Confirmation ────────────────────────── */}
      {deleteTarget && (
        <div
          className="product-modal-overlay"
          onClick={() => setDeleteTarget(null)}
        >
          <div
            className="delete-confirm-dialog"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="delete-confirm-dialog__title">Delete Product?</h3>
            <p className="delete-confirm-dialog__body">
              Delete "{deleteTarget.name}"? Past sales and appointments will
              preserve the item line.
            </p>
            <div className="delete-confirm-dialog__actions">
              <button
                type="button"
                className="delete-confirm-dialog__cancel"
                onClick={() => setDeleteTarget(null)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="delete-confirm-dialog__delete"
                onClick={handleDeleteConfirm}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ================================================================
   Add Product Modal (inline sub-component)
   ================================================================ */
interface AddProductModalProps {
  categories: Category[];
  onClose: () => void;
  onSaved: () => void;
}

function AddProductModal({ categories, onClose, onSaved }: AddProductModalProps) {
  const [name, setName] = useState('');
  const [sku, setSku] = useState(`PRD-${Date.now() % 1000}`);
  const [price, setPrice] = useState('25.00');
  const [description, setDescription] = useState('');
  const [productType, setProductType] = useState('normal');
  const [categoryId, setCategoryId] = useState<number | string>(
    categories.length > 0 ? categories[0].id : '',
  );
  const [isSaving, setIsSaving] = useState(false);

  const handleSave = async () => {
    if (!name.trim()) {
      toast.warning('Product name is required');
      return;
    }
    setIsSaving(true);
    try {
      await productApi.create({
        name: name.trim(),
        product_type: productType,
        price: parseFloat(price) || 0,
        sku: sku.trim(),
        category_id: categoryId ? Number(categoryId) : null,
        description: description.trim(),
      });
      toast.success('Product created successfully');
      onSaved();
    } catch {
      toast.error('Failed to create product');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="product-modal-overlay" onClick={onClose}>
      <div
        className="product-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="product-modal__title">Create New Product / Service</h3>

        {/* Product Type Selector */}
        <span className="product-modal__label">Product Architecture Type *</span>
        <div className="product-modal__type-chips">
          {[
            { key: 'normal', label: 'Normal Product' },
            { key: 'modifier', label: 'Modifier / Addon' },
            { key: 'combo', label: 'Combo Bundle' },
          ].map((t) => (
            <button
              key={t.key}
              type="button"
              className={`product-modal__type-chip ${productType === t.key ? 'product-modal__type-chip--active' : ''}`}
              onClick={() => setProductType(t.key)}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Name */}
        <div className="product-modal__field">
          <label>
            {productType === 'combo' ? 'Combo Bundle Name *' : 'Product / Service Name *'}
          </label>
          <input
            type="text"
            placeholder={
              productType === 'combo'
                ? 'e.g. Grooming + Diet Pack'
                : 'e.g. Executive Meeting Hall / Spa Bath'
            }
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>

        {/* Price + SKU */}
        <div className="product-modal__row">
          <div className="product-modal__field">
            <label>Price ($) *</label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
            />
          </div>
          <div className="product-modal__field">
            <label>SKU / Code</label>
            <input
              type="text"
              placeholder="e.g. MED-01"
              value={sku}
              onChange={(e) => setSku(e.target.value)}
            />
          </div>
        </div>

        {/* Category */}
        {categories.length > 0 && (
          <div className="product-modal__field">
            <label>Assign Category *</label>
            <select
              value={categoryId}
              onChange={(e) => setCategoryId(e.target.value)}
            >
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Description */}
        <div className="product-modal__field">
          <label>Description</label>
          <textarea
            placeholder="Optional notes or item details"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>

        {/* Actions */}
        <div className="product-modal__actions">
          <button
            type="button"
            className="product-modal__cancel-btn"
            onClick={onClose}
          >
            Cancel
          </button>
          <button
            type="button"
            className="product-modal__save-btn"
            disabled={isSaving}
            onClick={handleSave}
          >
            {isSaving ? 'Saving...' : 'Save Product'}
          </button>
        </div>
      </div>
    </div>
  );
}
