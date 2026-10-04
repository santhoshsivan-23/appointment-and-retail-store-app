import { useState, useEffect, useCallback } from 'react';
import { toast } from 'react-toastify';
import {
  Plus,
  FolderTree,
  Pencil,
  Trash2,
  CalendarCheck,
  CalendarOff,
  Stethoscope,
  Scissors,
  Hotel,
  UtensilsCrossed,
  Wine,
  DoorOpen,
  ShoppingBag,
  Dumbbell,
  Flower2,
  PawPrint,
  Layers,
} from 'lucide-react';
import { categoryApi, type Category, type CategoryPayload } from '../api/categoryApi';
import '../styles/categories.css';

/* ── Icon resolver (matches Flutter _resolveIcon) ──────── */
const ICON_MAP: Record<string, React.ComponentType<{ size?: number }>> = {
  medical_services: Stethoscope,
  content_cut: Scissors,
  hotel: Hotel,
  restaurant: UtensilsCrossed,
  local_bar: Wine,
  meeting_room: DoorOpen,
  shopping_bag: ShoppingBag,
  fitness_center: Dumbbell,
  spa: Flower2,
  pets: PawPrint,
  category: Layers,
};

function resolveIcon(iconName: string) {
  return ICON_MAP[iconName] ?? Layers;
}

/* ================================================================
   CategoriesView
   ================================================================ */
export default function CategoriesView() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [editTarget, setEditTarget] = useState<Category | null | 'new'>(null);
  const [deleteTarget, setDeleteTarget] = useState<Category | null>(null);

  /* ── Load ─────────────────────────────────────────────── */
  const loadCategories = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await categoryApi.getAll();
      setCategories(res.data?.data ?? []);
    } catch {
      toast.error('Failed to load categories');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadCategories();
  }, [loadCategories]);

  /* ── Toggle "Show in Appointment" (optimistic) ───────── */
  const handleToggleAppointment = async (cat: Category) => {
    const newValue = !cat.show_in_appointment;
    setCategories((prev) =>
      prev.map((c) =>
        c.id === cat.id ? { ...c, show_in_appointment: newValue } : c,
      ),
    );
    try {
      await categoryApi.update(cat.id, { show_in_appointment: newValue });
    } catch {
      // Revert on error
      setCategories((prev) =>
        prev.map((c) =>
          c.id === cat.id ? { ...c, show_in_appointment: !newValue } : c,
        ),
      );
      toast.error('Failed to update appointment visibility');
    }
  };

  /* ── Delete handler ───────────────────────────────────── */
  const handleDeleteConfirm = async () => {
    if (!deleteTarget) return;
    try {
      await categoryApi.delete(deleteTarget.id);
      toast.success(`"${deleteTarget.name}" deleted`);
      setDeleteTarget(null);
      loadCategories();
    } catch {
      toast.error('Failed to delete category');
    }
  };

  /* ── Render ───────────────────────────────────────────── */
  return (
    <div className="categories-view">
      {/* Header */}
      <div className="categories-header">
        <div className="categories-header__info">
          <h2>Custom Category Architecture</h2>
          <p>
            Organize inventory and manage which categories and products appear in
            appointment booking.
          </p>
        </div>
        <button
          type="button"
          className="categories-add-btn"
          onClick={() => setEditTarget('new')}
        >
          <Plus size={20} />
          <span>New Category</span>
        </button>
      </div>

      {/* Content */}
      {isLoading ? (
        <div className="categories-loading">
          <div className="spinner" />
        </div>
      ) : categories.length === 0 ? (
        <div className="categories-empty">
          <FolderTree size={54} />
          <span className="categories-empty__title">
            No categories created yet.
          </span>
        </div>
      ) : (
        <div className="categories-grid-wrap">
          <div className="categories-grid">
            {categories.map((cat, idx) => {
              const Icon = resolveIcon(cat.icon);
              return (
                <div
                  key={cat.id}
                  className="category-card"
                  style={{ animationDelay: `${idx * 0.04}s` }}
                >
                  <div className="category-card__header">
                    <div className="category-card__icon-box">
                      <Icon size={20} />
                    </div>
                    <div className="category-card__meta">
                      <div className="category-card__name">{cat.name}</div>
                      <div className="category-card__sort-order">
                        Order #{cat.sort_order}
                      </div>
                    </div>
                    <div className="category-card__actions">
                      <button
                        type="button"
                        className="category-card__edit-btn"
                        title="Edit Category"
                        onClick={() => setEditTarget(cat)}
                      >
                        <Pencil size={18} />
                      </button>
                      <button
                        type="button"
                        className="category-card__delete-btn"
                        title="Delete Category"
                        onClick={() => setDeleteTarget(cat)}
                      >
                        <Trash2 size={18} />
                      </button>
                    </div>
                  </div>

                  <div className="category-card__desc">
                    {cat.description || 'No description provided.'}
                  </div>

                  <div className="category-card__footer">
                    <div className="category-card__divider" />
                    <div className="category-card__appointment-row">
                      <span
                        className={`category-card__appointment-label ${
                          cat.show_in_appointment
                            ? 'category-card__appointment-label--active'
                            : 'category-card__appointment-label--hidden'
                        }`}
                      >
                        {cat.show_in_appointment ? (
                          <>
                            <CalendarCheck size={15} />
                            Show in Appointment
                          </>
                        ) : (
                          <>
                            <CalendarOff size={15} />
                            Hidden in Appointment
                          </>
                        )}
                      </span>
                      <label className="toggle-switch">
                        <input
                          type="checkbox"
                          checked={cat.show_in_appointment}
                          onChange={() => handleToggleAppointment(cat)}
                        />
                        <span className="toggle-switch__slider" />
                      </label>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* ── Add/Edit Modal ─────────────────────────────── */}
      {editTarget !== null && (
        <CategoryModal
          existing={editTarget === 'new' ? null : editTarget}
          onClose={() => setEditTarget(null)}
          onSaved={() => {
            setEditTarget(null);
            loadCategories();
          }}
        />
      )}

      {/* ── Delete Confirmation ────────────────────────── */}
      {deleteTarget && (
        <div
          className="category-modal-overlay"
          onClick={() => setDeleteTarget(null)}
        >
          <div
            className="delete-confirm-dialog"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="delete-confirm-dialog__title">Delete Category?</h3>
            <p className="delete-confirm-dialog__body">
              Are you sure you want to remove "{deleteTarget.name}"? Products in
              this category will remain available.
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
   Add / Edit Category Modal
   ================================================================ */
interface CategoryModalProps {
  existing: Category | null;
  onClose: () => void;
  onSaved: () => void;
}

function CategoryModal({ existing, onClose, onSaved }: CategoryModalProps) {
  const [name, setName] = useState(existing?.name ?? '');
  const [description, setDescription] = useState(existing?.description ?? '');
  const [sortOrder, setSortOrder] = useState(
    existing ? String(existing.sort_order) : '1',
  );
  const [showInAppointment, setShowInAppointment] = useState(
    existing?.show_in_appointment ?? true,
  );
  const [isSaving, setIsSaving] = useState(false);

  const handleSave = async () => {
    if (!name.trim()) {
      toast.warning('Category name is required');
      return;
    }
    setIsSaving(true);
    const payload: CategoryPayload = {
      name: name.trim(),
      description: description.trim(),
      icon: existing?.icon ?? 'category',
      sort_order: parseInt(sortOrder, 10) || 0,
      show_in_appointment: showInAppointment,
    };
    try {
      if (existing) {
        await categoryApi.update(existing.id, payload);
        toast.success('Category updated');
      } else {
        await categoryApi.create(payload);
        toast.success('Category created');
      }
      onSaved();
    } catch {
      toast.error('Failed to save category');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="category-modal-overlay" onClick={onClose}>
      <div
        className="category-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="category-modal__title">
          {existing ? 'Edit Category' : 'Create Category'}
        </h3>
        <p className="category-modal__subtitle">
          Configure category details and manage visibility in the appointment
          booking flow.
        </p>

        {/* Name */}
        <div className="category-modal__field">
          <label>Category Name *</label>
          <input
            type="text"
            placeholder="e.g. Meeting Hall, Spa, Food, Room, Clinic..."
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>

        {/* Description */}
        <div className="category-modal__field">
          <label>Description</label>
          <textarea
            placeholder="Brief category overview or notes"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>

        {/* Sort Order */}
        <div className="category-modal__field">
          <label>Display Sort Order</label>
          <input
            type="number"
            min="0"
            placeholder="1, 2, 3..."
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value)}
          />
        </div>

        {/* Show in Appointment toggle box */}
        <div className="category-modal__toggle-box">
          <div className="category-modal__toggle-info">
            <div className="category-modal__toggle-title">
              Show in Appointment
            </div>
            <div className="category-modal__toggle-desc">
              Enable to show this category and its products in Book New
              Appointment popup.
            </div>
          </div>
          <label className="toggle-switch">
            <input
              type="checkbox"
              checked={showInAppointment}
              onChange={(e) => setShowInAppointment(e.target.checked)}
            />
            <span className="toggle-switch__slider" />
          </label>
        </div>

        {/* Actions */}
        <div className="category-modal__actions">
          <button
            type="button"
            className="category-modal__cancel-btn"
            onClick={onClose}
          >
            Cancel
          </button>
          <button
            type="button"
            className="category-modal__save-btn"
            disabled={isSaving}
            onClick={handleSave}
          >
            {isSaving
              ? 'Saving...'
              : existing
                ? 'Save Changes'
                : 'Create Category'}
          </button>
        </div>
      </div>
    </div>
  );
}
