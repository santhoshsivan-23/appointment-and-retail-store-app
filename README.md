# IQ Store — Unified Appointment & Retail POS Management System

Full-stack POS and Appointment Management terminal built with **Flutter** and **Node.js + Express + MySQL** (with zero-friction fallback).

---

## 🚀 Features by Phase

### Phase 1 — Project Setup & Base Layout
- **Fixed Header**: Brand identity (`IQ Store Grooming & Clinical Suite`), `Station #01 Online` live status pill, active business name, and quick search.
- **Collapsible Sidebar**: Smooth toggle between **expanded mode** (240px) and **compact icon rail** (72px) with animated rotation icon.
- **8 Core Navigation Modules**:
  1. 📊 **Dashboard**: High-level KPI metrics (Today's appointments, register sales, active clinicians, suite occupancy).
  2. 📅 **Appointment**: Daily and weekly schedule slots, appointment status badges, and booking modal.
  3. 👥 **Staff**: Staff directory, role badges, live search, details popup, and delete confirmation.
  4. 📜 **Appointment History**: Historical preservation demonstrating that deleted/archived staff members still retain their attribution on past logs.
  5. 🛒 **Cart & POS**: Full register with line item tallies, instant tax/total calculations, and checkout.
  6. 🗂️ **Categories**: Generic, customizable domain classification (Food, Service, Drinks, Meeting Hall, Room, Anything).
  7. 📦 **Products**: Normal products, Modifiers/Add-ons, and Combo bundles with category filtering and SKU tracking.
  8. ⚙️ **Appointment Configuration**: Opening/closing hours, slot intervals (15m, 30m, 45m, 60m), and sanitation buffer times.

### Phase 2 — Staff & Customer Management
- **Staff Operations**:
  - Live search by name, role, email, or phone.
  - View staff details popup with contact info, role specialization, and status.
  - Delete staff confirmation popup: Soft-deletes staff from active booking schedules while strictly preserving historical records.
- **Customer Operations**:
  - Customer database and customer selection dropdown in POS.
  - **Walk-in Customer Option**: Single toggle switch capturing **Name** and **Phone number** inline.

### Phase 3 — Categories & Products
- **Generic Customizable Categories**:
  - Add / Edit / Delete categories without restricting to food (e.g. Food, Service, Drinks, Meeting Hall, Room, Retail, Spa, Wellness).
- **Multi-Type Product Architecture**:
  - **Normal Product**: Base price items/services.
  - **Modifier Product**: Add-ons & customization extras with positive/negative price adjustments.
  - **Combo Product**: Bundled packages bundling multiple individual products at a single package price.
  - Instant category assignment and search.

---

## 📡 Backend API Endpoints

### Auth
- `POST /api/auth/register` — Register business details
- `POST /api/auth/login` — Sign in with email & password
- `GET  /api/auth/me` — Authenticated profile (Bearer Token)
- `GET  /api/health` — Status and DB mode

### Staff
- `GET    /api/staff` — List active staff (`?search=...&include_deleted=true`)
- `GET    /api/staff/:id` — Single staff details
- `POST   /api/staff` — Create staff member
- `PUT    /api/staff/:id` — Update staff member
- `DELETE /api/staff/:id` — Soft delete staff (preserves historical logs)

### Customers
- `GET    /api/customers` — List/search customers (`?search=...`)
- `POST   /api/customers` — Register customer or walk-in client

### Categories
- `GET    /api/categories` — List active categories
- `POST   /api/categories` — Create category (Food, Service, Room, etc.)
- `PUT    /api/categories/:id` — Update category
- `DELETE /api/categories/:id` — Soft delete category

### Products
- `GET    /api/products` — List products (`?category_id=...&product_type=...&search=...`)
- `POST   /api/products` — Create product (`normal`, `modifier`, `combo`)
- `PUT    /api/products/:id` — Update product
- `DELETE /api/products/:id` — Soft delete product

---

## 🏃 Running the Application

### 1. Start the Node.js Backend
```bash
cd appointment-hotel-booking-backend
npm run dev
# or
npm start
```

### 2. Run the Flutter App
```bash
cd appointment_and_hotel_booking
flutter run -d chrome
# or for Windows Desktop
flutter run -d windows
```
