# Appointment & Hotel Booking Management System

This project contains a full-stack solution featuring a **Node.js Express Backend** and a **Flutter App** for business registration, authentication, and management.

---

## 📁 Project Structure

```
appointment-hotel-booking/
├── appointment-hotel-booking-backend/    # Node.js + Express + MySQL / JSON storage
│   ├── config/
│   │   └── db.js                        # MySQL connection & smart auto-fallback
│   ├── controllers/
│   │   └── authController.js            # Register, Login, Profile controllers
│   ├── middleware/
│   │   └── authMiddleware.js            # JWT verification middleware
│   ├── routes/
│   │   └── auth.js                      # /api/auth routes
│   ├── data/
│   │   └── businesses.json              # Local fallback database
│   ├── .env                             # Environment configuration
│   ├── index.js                         # Server entry point
│   └── package.json
│
└── appointment_and_hotel_booking/        # Flutter Client App
    ├── lib/
    │   ├── models/
    │   │   └── business_model.dart      # Business data model
    │   ├── services/
    │   │   ├── api_service.dart         # HTTP API client
    │   │   └── auth_storage.dart        # Session & token storage (SharedPreferences)
    │   ├── screens/
    │   │   ├── login_screen.dart        # Business sign-in screen
    │   │   ├── register_screen.dart     # Business details registration screen
    │   │   └── home_screen.dart         # Business dashboard with quick actions
    │   ├── theme/
    │   │   └── app_theme.dart           # UI theme & styling tokens
    │   └── main.dart                    # App entry point with session restore
    └── pubspec.yaml
```

---

## 🚀 1. Running the Node.js Backend

1. Navigate to the backend folder:
   ```bash
   cd appointment-hotel-booking-backend
   ```
2. Start the server:
   ```bash
   npm run dev
   # or
   npm start
   ```
3. The server runs on `http://localhost:5000`.

### 🗄️ Database Setup (MySQL & Fallback)
- **MySQL Ready**: Configure your database credentials in `.env`:
  ```ini
  PORT=5000
  DB_HOST=localhost
  DB_USER=root
  DB_PASSWORD=
  DB_NAME=appointment_hotel_booking
  DB_PORT=3306
  JWT_SECRET=super_secret_jwt_key_appointment_hotel_2026
  JWT_EXPIRES_IN=7d
  ```
- **Zero-Friction Fallback**: If MySQL is not running or credentials are empty, the backend automatically logs a notice and operates using a local JSON store in `data/businesses.json`. You can test registration and login immediately without installing or configuring MySQL first!

### 📡 API Endpoints
- `GET  /api/health` — Check server and database status
- `POST /api/auth/register` — Register a new business with details
- `POST /api/auth/login` — Sign in with business email and password
- `GET  /api/auth/me` — Get logged-in business profile (`Bearer <token>` required)

---

## 📱 2. Running the Flutter App

1. Navigate to the Flutter directory:
   ```bash
   cd appointment_and_hotel_booking
   ```
2. Launch on your desired platform:
   - **Chrome (Web)**:
     ```bash
     flutter run -d chrome
     ```
   - **Windows Desktop**:
     ```bash
     flutter run -d windows
     ```
   - **Android Emulator**:
     ```bash
     flutter run
     ```

### ⚙️ Network / API Configuration
- By default:
  - **Web & Windows**: Connects to `http://localhost:5000/api`
  - **Android Emulator**: Automatically connects to `http://10.0.2.2:5000/api`
- You can tap the **Settings icon (⚙️)** on the top right of the Login screen to adjust the API URL at any time.

---

## ✨ Features Implemented
- **Business Details Registration**:
  - Business Name, Business Category/Type (Hotel, Salon, Spa, Clinic, etc.)
  - Owner / Contact Person Name & Contact Phone
  - Email & Password with confirmation and validation
  - Street Address, City, Country, Description
- **Authentication & Security**:
  - Encrypted passwords with `bcryptjs`
  - JSON Web Tokens (JWT) for secure session authorization
  - Persistent login state with `SharedPreferences`
- **Modern UI / UX**:
  - Clean Material 3 design system with Indigo/Sky palette
  - Password visibility toggles
  - Quick "Fill Sample Data" buttons for immediate testing
  - Fully responsive layout
