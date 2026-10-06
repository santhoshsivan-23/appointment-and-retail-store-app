import { useState, useEffect, useCallback, useRef } from 'react';
import { toast } from 'react-toastify';
import {
  Search,
  X,
  UserPlus,
  Users,
  Info,
  Edit,
  Trash2,
  Mail,
  Phone,
  BadgeAlert,
  CheckCircle,
  AlertTriangle,
  History,
  Camera,
  Upload,
  Image as ImageIcon,
  RotateCw,
} from 'lucide-react';
import { staffApi, type Staff } from '../api/staffApi';
import '../styles/staff.css';

export default function StaffView() {
  /* ── State ────────────────────────────────────────────── */
  const [staffList, setStaffList] = useState<Staff[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Modals state
  const [detailStaff, setDetailStaff] = useState<Staff | null>(null);
  const [editStaff, setEditStaff] = useState<Staff | null>(null);
  const [deleteStaff, setDeleteStaff] = useState<Staff | null>(null);
  const [showAddModal, setShowAddModal] = useState<boolean>(false);

  // Form states for Add Modal
  const [addName, setAddName] = useState<string>('');
  const [addRole, setAddRole] = useState<string>('Stylist / Clinician');
  const [addPhone, setAddPhone] = useState<string>('');
  const [addEmail, setAddEmail] = useState<string>('');
  const [addImageBase64, setAddImageBase64] = useState<string | null>(null);
  const [isAdding, setIsAdding] = useState<boolean>(false);

  // Form states for Edit Modal
  const [editName, setEditName] = useState<string>('');
  const [editRole, setEditRole] = useState<string>('');
  const [editPhone, setEditPhone] = useState<string>('');
  const [editEmail, setEditEmail] = useState<string>('');
  const [editIsActive, setEditIsActive] = useState<boolean>(true);
  const [editImageBase64, setEditImageBase64] = useState<string | null>(null);
  const [editImageChanged, setEditImageChanged] = useState<boolean>(false);
  const [isSavingEdit, setIsSavingEdit] = useState<boolean>(false);

  const [isDeleting, setIsDeleting] = useState<boolean>(false);

  // Hidden file input refs
  const addFileInputRef = useRef<HTMLInputElement>(null);
  const editFileInputRef = useRef<HTMLInputElement>(null);

  /* ── Data Fetching ────────────────────────────────────── */
  const loadStaff = useCallback(async (query = searchQuery) => {
    setIsLoading(true);
    try {
      const res = await staffApi.getAll(true, query.trim().length > 0 ? query.trim() : undefined);
      setStaffList(res.data?.data ?? []);
    } catch (err) {
      console.error('Error loading staff list:', err);
      toast.error('Failed to load staff list');
    } finally {
      setIsLoading(false);
    }
  }, [searchQuery]);

  useEffect(() => {
    loadStaff();
  }, [loadStaff]);

  /* ── Search Handlers ──────────────────────────────────── */
  const handleSearchChange = (val: string) => {
    setSearchQuery(val);
    loadStaff(val);
  };

  const handleClearSearch = () => {
    setSearchQuery('');
    loadStaff('');
  };

  /* ── File Selection Helpers ───────────────────────────── */
  const handleImageFilePick = (
    e: React.ChangeEvent<HTMLInputElement>,
    onSelect: (b64: string | null) => void
  ) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      toast.warning('Please select a valid image file');
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      onSelect(result);
    };
    reader.readAsDataURL(file);
    e.target.value = '';
  };

  /* ── Add Staff Action ─────────────────────────────────── */
  const handleOpenAddModal = () => {
    setAddName('');
    setAddRole('Stylist / Clinician');
    setAddPhone('');
    setAddEmail('');
    setAddImageBase64(null);
    setShowAddModal(true);
  };

  const handleCreateStaff = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!addName.trim()) {
      toast.warning('Please enter staff full name');
      return;
    }

    setIsAdding(true);
    try {
      const payload: Partial<Staff> = {
        name: addName.trim(),
        role: addRole.trim() || 'Stylist / Clinician',
        phone: addPhone.trim(),
        email: addEmail.trim(),
        is_active: true,
      };
      if (addImageBase64) {
        payload.image = addImageBase64;
      }

      await staffApi.create(payload);
      toast.success(`Staff member "${addName.trim()}" created successfully`);
      setShowAddModal(false);
      loadStaff();
    } catch (err) {
      console.error('Error creating staff:', err);
      toast.error('Failed to create staff member');
    } finally {
      setIsAdding(false);
    }
  };

  /* ── Edit Staff Action ────────────────────────────────── */
  const handleOpenEditModal = (staff: Staff) => {
    setEditStaff(staff);
    setEditName(staff.name || '');
    setEditRole(staff.role || '');
    setEditPhone(staff.phone || '');
    setEditEmail(staff.email || '');
    setEditIsActive(Boolean(staff.is_active));
    setEditImageBase64(staff.image || null);
    setEditImageChanged(false);
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editStaff) return;
    if (!editName.trim()) {
      toast.warning('Please enter staff full name');
      return;
    }

    setIsSavingEdit(true);
    try {
      const payload: Partial<Staff> = {
        name: editName.trim(),
        role: editRole.trim(),
        phone: editPhone.trim(),
        email: editEmail.trim(),
        is_active: editIsActive,
      };

      if (editImageChanged) {
        payload.image = editImageBase64 || '';
      }

      await staffApi.update(editStaff.id, payload);
      toast.success(`Staff member "${editName.trim()}" updated successfully`);
      setEditStaff(null);
      loadStaff();
    } catch (err) {
      console.error('Error updating staff:', err);
      toast.error('Failed to update staff member');
    } finally {
      setIsSavingEdit(false);
    }
  };

  /* ── Delete Staff Action ──────────────────────────────── */
  const handleConfirmDelete = async () => {
    if (!deleteStaff) return;
    setIsDeleting(true);
    try {
      await staffApi.delete(deleteStaff.id);
      toast.success(`Staff member "${deleteStaff.name}" deleted & archived`);
      setDeleteStaff(null);
      loadStaff();
    } catch (err) {
      console.error('Error deleting staff:', err);
      toast.error('Failed to delete staff member');
    } finally {
      setIsDeleting(false);
    }
  };

  /* ── Avatar Render Helper ─────────────────────────────── */
  const renderAvatar = (staff: Staff, size = 44) => {
    const initial = (staff.name || '?').trim().charAt(0).toUpperCase();
    const hasImage = Boolean(staff.image && staff.image.trim().length > 0);

    return (
      <div
        className="staff-avatar"
        style={{
          width: `${size}px`,
          height: `${size}px`,
          backgroundColor: staff.color_code || '#E11D48',
        }}
      >
        {hasImage ? (
          <img
            src={staff.image!}
            alt={staff.name}
            className="staff-avatar-img"
            onError={(e) => {
              // Fallback to initial if image fails
              (e.currentTarget as HTMLElement).style.display = 'none';
            }}
          />
        ) : (
          <span
            className="staff-avatar-initial"
            style={{ fontSize: `${Math.round(size * 0.42)}px` }}
          >
            {initial}
          </span>
        )}
      </div>
    );
  };

  return (
    <div className="staff-view-container">
      {/* 1. Top Controls Bar */}
      <div className="staff-top-bar">
        {/* Search input container */}
        <div className="staff-search-box">
          <Search size={20} style={{ color: '#64748B' }} />
          <input
            type="text"
            className="staff-search-input"
            placeholder="Search staff by name, role, email, phone..."
            value={searchQuery}
            onChange={(e) => handleSearchChange(e.target.value)}
          />
          {searchQuery && (
            <button
              type="button"
              className="staff-search-clear-btn"
              onClick={handleClearSearch}
            >
              <X size={18} />
            </button>
          )}
        </div>

        {/* Add Staff Button */}
        <button
          type="button"
          className="staff-add-btn"
          onClick={handleOpenAddModal}
        >
          <UserPlus size={18} />
          <span>Add Staff</span>
        </button>
      </div>

      {/* 2. Staff Grid / Empty State */}
      <div className="staff-grid-wrapper">
        {isLoading ? (
          <div className="staff-empty-state">
            <RotateCw size={36} className="apt-spin" style={{ color: '#E11D48', marginBottom: 16 }} />
            <div className="staff-empty-desc">Loading staff directory...</div>
          </div>
        ) : staffList.length === 0 ? (
          <div className="staff-empty-state">
            <div className="staff-empty-icon">
              <Users size={48} />
            </div>
            <div className="staff-empty-title">No staff members found</div>
            <div className="staff-empty-desc">
              Click &quot;+ Add Staff&quot; to onboard team clinicians &amp; staff.
            </div>
          </div>
        ) : (
          <div className="staff-grid">
            {staffList.map((staff) => {
              const isActive = Boolean(staff.is_active);
              return (
                <div key={staff.id} className="staff-card">
                  {/* Card Header: Avatar + Name + Role + Status Badge */}
                  <div className="staff-card-header">
                    {renderAvatar(staff, 44)}
                    <div className="staff-card-title-box">
                      <h4 className="staff-card-name" title={staff.name}>
                        {staff.name}
                      </h4>
                      <div className="staff-card-role" title={staff.role}>
                        {staff.role}
                      </div>
                    </div>
                    <div
                      className={`staff-status-badge ${
                        isActive
                          ? 'staff-status-badge--active'
                          : 'staff-status-badge--archived'
                      }`}
                    >
                      {isActive ? 'Active' : 'Archived'}
                    </div>
                  </div>

                  {/* Contact Info */}
                  <div className="staff-card-contact-list">
                    <a
                      href={staff.phone ? `tel:${staff.phone}` : undefined}
                      className={`staff-card-contact ${!staff.phone ? 'staff-card-contact--empty' : ''}`}
                      title={staff.phone || 'No phone'}
                      onClick={(e) => {
                        if (!staff.phone) e.preventDefault();
                      }}
                    >
                      <Phone size={13} style={{ color: staff.phone ? '#2563EB' : '#94A3B8' }} />
                      <span>{staff.phone ? staff.phone : 'No phone'}</span>
                    </a>
                    <a
                      href={staff.email ? `mailto:${staff.email}` : undefined}
                      className={`staff-card-contact ${!staff.email ? 'staff-card-contact--empty' : ''}`}
                      title={staff.email || 'No email'}
                      onClick={(e) => {
                        if (!staff.email) e.preventDefault();
                      }}
                    >
                      <Mail size={13} style={{ color: staff.email ? '#7C3AED' : '#94A3B8' }} />
                      <span>{staff.email ? staff.email : 'No email'}</span>
                    </a>
                  </div>

                  {/* 3 Action Buttons */}
                  <div className="staff-card-actions">
                    <button
                      type="button"
                      className="staff-card-btn staff-card-btn--primary"
                      onClick={() => setDetailStaff(staff)}
                    >
                      <Info size={14} />
                      <span>Details</span>
                    </button>

                    <button
                      type="button"
                      className="staff-card-btn staff-card-btn--primary"
                      onClick={() => handleOpenEditModal(staff)}
                    >
                      <Edit size={14} />
                      <span>Edit</span>
                    </button>

                    <button
                      type="button"
                      className="staff-card-btn staff-card-btn--danger"
                      onClick={() => setDeleteStaff(staff)}
                    >
                      <Trash2 size={14} />
                      <span>Delete</span>
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* ── 3. Staff Details Popup Dialog ─────────────────────── */}
      {detailStaff && (
        <div
          className="staff-modal-overlay"
          onClick={() => setDetailStaff(null)}
        >
          <div
            className="staff-modal-dialog"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
          >
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              {renderAvatar(detailStaff, 46)}
              <div>
                <h3 className="staff-modal-title">{detailStaff.name}</h3>
                <div style={{ fontSize: 13, color: '#64748B', marginTop: 2 }}>
                  {detailStaff.role}
                </div>
              </div>
            </div>

            <div className="staff-modal-divider" />

            {/* Info rows matching Flutter */}
            <div className="staff-info-row">
              <Mail size={18} className="staff-info-icon" />
              <div className="staff-info-label">Email</div>
              <div className="staff-info-value">
                {detailStaff.email || 'None recorded'}
              </div>
            </div>

            <div className="staff-info-row">
              <Phone size={18} className="staff-info-icon" />
              <div className="staff-info-label">Phone</div>
              <div className="staff-info-value">
                {detailStaff.phone || 'None recorded'}
              </div>
            </div>

            <div className="staff-info-row">
              <BadgeAlert size={18} className="staff-info-icon" />
              <div className="staff-info-label">Staff ID</div>
              <div className="staff-info-value">#STF-00{detailStaff.id}</div>
            </div>

            <div className="staff-info-row">
              <CheckCircle size={18} className="staff-info-icon" />
              <div className="staff-info-label">Scheduling Status</div>
              <div
                className={`staff-info-value ${
                  Boolean(detailStaff.is_active)
                    ? 'staff-info-value--active'
                    : 'staff-info-value--archived'
                }`}
              >
                {Boolean(detailStaff.is_active)
                  ? 'Active for Bookings'
                  : 'Deactivated (Historical Record)'}
              </div>
            </div>

            {/* Actions: Close, Edit, Delete */}
            <div className="staff-modal-actions" style={{ marginTop: 24 }}>
              <button
                type="button"
                className="staff-modal-btn staff-modal-btn--cancel"
                onClick={() => setDetailStaff(null)}
                style={{ flex: 1 }}
              >
                Close
              </button>
              <button
                type="button"
                className="staff-modal-btn staff-modal-btn--primary"
                onClick={() => {
                  const s = detailStaff;
                  setDetailStaff(null);
                  handleOpenEditModal(s);
                }}
                style={{ flex: 1 }}
              >
                <Edit size={14} />
                <span>Edit Staff</span>
              </button>
              <button
                type="button"
                className="staff-modal-btn staff-modal-btn--danger"
                onClick={() => {
                  const s = detailStaff;
                  setDetailStaff(null);
                  setDeleteStaff(s);
                }}
                style={{ flex: 1 }}
              >
                <Trash2 size={14} />
                <span>Delete</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── 4. Add Staff Modal Dialog ─────────────────────────── */}
      {showAddModal && (
        <div
          className="staff-modal-overlay"
          onClick={() => setShowAddModal(false)}
        >
          <div
            className="staff-modal-dialog"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
          >
            <div className="staff-modal-header">
              <h3 className="staff-modal-title">Add New Staff Member</h3>
            </div>

            <form onSubmit={handleCreateStaff}>
              {/* Profile Image Upload Circle */}
              <div className="staff-avatar-upload-box">
                <input
                  type="file"
                  ref={addFileInputRef}
                  style={{ display: 'none' }}
                  accept="image/*"
                  onChange={(e) =>
                    handleImageFilePick(e, (b64) => setAddImageBase64(b64))
                  }
                />
                <div
                  className="staff-avatar-uploader-circle"
                  onClick={() => addFileInputRef.current?.click()}
                  title="Upload profile picture"
                >
                  <div className="staff-avatar-preview">
                    {addImageBase64 ? (
                      <img src={addImageBase64} alt="Preview" />
                    ) : addName.trim() ? (
                      <span className="staff-avatar-preview-initial">
                        {addName.trim().charAt(0).toUpperCase()}
                      </span>
                    ) : (
                      <div
                        style={{
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          color: '#64748B',
                        }}
                      >
                        <ImageIcon size={28} />
                        <span style={{ fontSize: 10, fontWeight: 600, marginTop: 2 }}>
                          Add Photo
                        </span>
                      </div>
                    )}
                  </div>
                  <div className="staff-avatar-camera-badge">
                    <Camera size={13} />
                  </div>
                </div>

                <div className="staff-avatar-actions">
                  <button
                    type="button"
                    className="staff-avatar-btn staff-avatar-btn--primary"
                    onClick={() => addFileInputRef.current?.click()}
                  >
                    <Upload size={13} />
                    <span>
                      {addImageBase64 ? 'Change Photo' : 'Upload Profile Image'}
                    </span>
                  </button>
                  {addImageBase64 && (
                    <button
                      type="button"
                      className="staff-avatar-btn staff-avatar-btn--danger"
                      onClick={() => setAddImageBase64(null)}
                    >
                      Remove
                    </button>
                  )}
                </div>
              </div>

              {/* Form fields */}
              <div className="staff-form-group">
                <label className="staff-form-label">Full Name *</label>
                <input
                  type="text"
                  className="staff-form-input"
                  placeholder="e.g. Dr. Maya Lin"
                  value={addName}
                  onChange={(e) => setAddName(e.target.value)}
                  required
                />
              </div>

              <div className="staff-form-group">
                <label className="staff-form-label">
                  Staff Role / Specialization *
                </label>
                <input
                  type="text"
                  className="staff-form-input"
                  placeholder="Stylist / Clinician"
                  value={addRole}
                  onChange={(e) => setAddRole(e.target.value)}
                  required
                />
              </div>

              <div className="staff-form-group">
                <label className="staff-form-label">Contact Phone</label>
                <input
                  type="text"
                  className="staff-form-input"
                  placeholder="+1 555-0100"
                  value={addPhone}
                  onChange={(e) => setAddPhone(e.target.value)}
                />
              </div>

              <div className="staff-form-group">
                <label className="staff-form-label">Email Address</label>
                <input
                  type="email"
                  className="staff-form-input"
                  placeholder="maya@omopet.clinic"
                  value={addEmail}
                  onChange={(e) => setAddEmail(e.target.value)}
                />
              </div>

              {/* Actions */}
              <div className="staff-modal-actions">
                <button
                  type="button"
                  className="staff-modal-btn staff-modal-btn--cancel"
                  onClick={() => setShowAddModal(false)}
                  disabled={isAdding}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="staff-modal-btn staff-modal-btn--primary"
                  disabled={isAdding}
                >
                  {isAdding ? 'Creating...' : 'Create Staff'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── 5. Edit Staff Modal Dialog ────────────────────────── */}
      {editStaff && (
        <div
          className="staff-modal-overlay"
          onClick={() => setEditStaff(null)}
        >
          <div
            className="staff-modal-dialog"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
          >
            <div className="staff-modal-header">
              <div className="staff-modal-header-icon">
                <Edit size={18} />
              </div>
              <h3 className="staff-modal-title">Edit Staff Member</h3>
            </div>

            <form onSubmit={handleSaveEdit}>
              {/* Profile Image Section */}
              <div className="staff-avatar-upload-box">
                <input
                  type="file"
                  ref={editFileInputRef}
                  style={{ display: 'none' }}
                  accept="image/*"
                  onChange={(e) =>
                    handleImageFilePick(e, (b64) => {
                      setEditImageBase64(b64);
                      setEditImageChanged(true);
                    })
                  }
                />
                <div
                  className="staff-avatar-uploader-circle"
                  onClick={() => editFileInputRef.current?.click()}
                  title="Upload profile picture"
                >
                  <div className="staff-avatar-preview">
                    {editImageBase64 ? (
                      <img src={editImageBase64} alt="Preview" />
                    ) : editName.trim() ? (
                      <span className="staff-avatar-preview-initial">
                        {editName.trim().charAt(0).toUpperCase()}
                      </span>
                    ) : (
                      <div
                        style={{
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          color: '#64748B',
                        }}
                      >
                        <ImageIcon size={28} />
                        <span style={{ fontSize: 10, fontWeight: 600, marginTop: 2 }}>
                          Add Photo
                        </span>
                      </div>
                    )}
                  </div>
                  <div className="staff-avatar-camera-badge">
                    <Camera size={13} />
                  </div>
                </div>

                <div className="staff-avatar-actions">
                  <button
                    type="button"
                    className="staff-avatar-btn staff-avatar-btn--primary"
                    onClick={() => editFileInputRef.current?.click()}
                  >
                    <Upload size={13} />
                    <span>
                      {editImageBase64 ? 'Change Photo' : 'Upload Profile Image'}
                    </span>
                  </button>
                  {editImageBase64 && (
                    <button
                      type="button"
                      className="staff-avatar-btn staff-avatar-btn--danger"
                      onClick={() => {
                        setEditImageBase64(null);
                        setEditImageChanged(true);
                      }}
                    >
                      Remove
                    </button>
                  )}
                </div>
              </div>

              {/* Form fields */}
              <div className="staff-form-group">
                <label className="staff-form-label">Full Name *</label>
                <input
                  type="text"
                  className="staff-form-input"
                  placeholder="e.g. Dr. Maya Lin"
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                  required
                />
              </div>

              <div className="staff-form-group">
                <label className="staff-form-label">
                  Staff Role / Specialization *
                </label>
                <input
                  type="text"
                  className="staff-form-input"
                  placeholder="Stylist / Clinician"
                  value={editRole}
                  onChange={(e) => setEditRole(e.target.value)}
                  required
                />
              </div>

              <div className="staff-form-group">
                <label className="staff-form-label">Contact Phone</label>
                <input
                  type="text"
                  className="staff-form-input"
                  placeholder="+1 555-0100"
                  value={editPhone}
                  onChange={(e) => setEditPhone(e.target.value)}
                />
              </div>

              <div className="staff-form-group">
                <label className="staff-form-label">Email Address</label>
                <input
                  type="email"
                  className="staff-form-input"
                  placeholder="maya@omopet.clinic"
                  value={editEmail}
                  onChange={(e) => setEditEmail(e.target.value)}
                />
              </div>

              {/* Active for Bookings toggle switch matching Flutter */}
              <div className="staff-toggle-box">
                <div className="staff-toggle-info">
                  <div className="staff-toggle-title">Active for Bookings</div>
                  <div className="staff-toggle-subtitle">
                    {editIsActive
                      ? 'Staff is visible and selectable for bookings'
                      : 'Staff is archived from active bookings'}
                  </div>
                </div>
                <label className="staff-switch">
                  <input
                    type="checkbox"
                    checked={editIsActive}
                    onChange={(e) => setEditIsActive(e.target.checked)}
                  />
                  <span className="staff-slider" />
                </label>
              </div>

              {/* Actions */}
              <div className="staff-modal-actions">
                <button
                  type="button"
                  className="staff-modal-btn staff-modal-btn--cancel"
                  onClick={() => setEditStaff(null)}
                  disabled={isSavingEdit}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="staff-modal-btn staff-modal-btn--primary"
                  disabled={isSavingEdit}
                >
                  {isSavingEdit ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── 6. Delete Confirmation Dialog ─────────────────────── */}
      {deleteStaff && (
        <div
          className="staff-modal-overlay"
          onClick={() => setDeleteStaff(null)}
        >
          <div
            className="staff-modal-dialog"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
              <div
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: '50%',
                  background: 'rgba(239, 68, 68, 0.1)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#EF4444',
                  flexShrink: 0,
                }}
              >
                <AlertTriangle size={22} />
              </div>
              <h3 className="staff-modal-title">Delete Staff Member?</h3>
            </div>

            <div style={{ fontSize: 14, color: '#334155', lineHeight: 1.5 }}>
              Are you sure you want to delete{' '}
              <strong>
                {deleteStaff.name} ({deleteStaff.role})
              </strong>
              ?
            </div>

            {/* Information Alert Box matching Flutter */}
            <div className="staff-delete-callout">
              <History size={18} className="staff-delete-callout-icon" />
              <div className="staff-delete-callout-text">
                Historical appointments will preserve {deleteStaff.name}&apos;s name
                for past logs. They will no longer appear in active booking slots.
              </div>
            </div>

            {/* Actions: Cancel & Confirm Deletion */}
            <div className="staff-modal-actions" style={{ marginTop: 20 }}>
              <button
                type="button"
                className="staff-modal-btn staff-modal-btn--cancel"
                onClick={() => setDeleteStaff(null)}
                disabled={isDeleting}
              >
                Cancel
              </button>
              <button
                type="button"
                className="staff-modal-btn staff-modal-btn--danger"
                onClick={handleConfirmDelete}
                disabled={isDeleting}
              >
                {isDeleting ? 'Deleting...' : 'Confirm Deletion'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
