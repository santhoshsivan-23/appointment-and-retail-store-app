const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

let pool = null;
let useFallback = false;

const dataDir = path.join(__dirname, '..', 'data');
const jsonFiles = {
  businesses: path.join(dataDir, 'businesses.json'),
  staff: path.join(dataDir, 'staff.json'),
  customers: path.join(dataDir, 'customers.json'),
  categories: path.join(dataDir, 'categories.json'),
  products: path.join(dataDir, 'products.json'),
  appointments: path.join(dataDir, 'appointments.json'),
  sales: path.join(dataDir, 'sales.json'),
  refunds: path.join(dataDir, 'refunds.json'),
  settings: path.join(dataDir, 'settings.json'),
};

// Seed initial fallback data
const initialData = {
  businesses: [],
  staff: [
    {
      id: 1,
      business_id: 1,
      name: 'Dr. Shaun Ong',
      email: 'shaun.ong@omopet.clinic',
      phone: '+1 555-0192',
      role: 'Chief Veterinary Officer',
      color_code: '#B42907',
      is_active: true,
      deleted_at: null,
      created_at: new Date().toISOString(),
    },
    {
      id: 2,
      business_id: 1,
      name: 'Elena Rostova',
      email: 'elena@omopet.clinic',
      phone: '+1 555-0144',
      role: 'Senior Stylist & Groomer',
      color_code: '#855300',
      is_active: true,
      deleted_at: null,
      created_at: new Date().toISOString(),
    },
    {
      id: 3,
      business_id: 1,
      name: 'Marcus Vance',
      email: 'marcus@omopet.clinic',
      phone: '+1 555-0188',
      role: 'Retail POS & Inventory Lead',
      color_code: '#006C49',
      is_active: true,
      deleted_at: null,
      created_at: new Date().toISOString(),
    },
  ],
  customers: [
    {
      id: 1,
      business_id: 1,
      name: 'Claire Beauchamp',
      phone: '+1 555-4421',
      email: 'claire.b@example.com',
      is_walk_in: false,
      notes: 'VIP client with 2 Golden Retrievers. Prefers organic diet.',
      created_at: new Date().toISOString(),
    },
    {
      id: 2,
      business_id: 1,
      name: 'David Kim (Walk-in)',
      phone: '+1 555-8832',
      email: '',
      is_walk_in: true,
      notes: 'Walk-in customer for express grooming bath.',
      created_at: new Date().toISOString(),
    },
  ],
  categories: [
    {
      id: 1,
      business_id: 1,
      name: 'Clinical Services',
      description: 'Consultations, vaccines, checkups, and diagnostic procedures.',
      icon: 'medical_services',
      sort_order: 1,
      is_active: true,
      created_at: new Date().toISOString(),
    },
    {
      id: 2,
      business_id: 1,
      name: 'Salon & Grooming',
      description: 'Shampoo, styling, spa bath, nail trimming, and de-shedding.',
      icon: 'content_cut',
      sort_order: 2,
      is_active: true,
      created_at: new Date().toISOString(),
    },
    {
      id: 3,
      business_id: 1,
      name: 'Hotel & Boarding Suites',
      description: 'Luxury overnight suites, daylight kennels, and extended stays.',
      icon: 'hotel',
      sort_order: 3,
      is_active: true,
      created_at: new Date().toISOString(),
    },
    {
      id: 4,
      business_id: 1,
      name: 'Retail & Wellness Diet',
      description: 'Nutritional food, supplements, treats, and wellness supplies.',
      icon: 'shopping_bag',
      sort_order: 4,
      is_active: true,
      created_at: new Date().toISOString(),
    },
    {
      id: 5,
      business_id: 1,
      name: 'Meeting Hall & Event Spaces',
      description: 'Conference room, seminar hall, and pet training arena hourly rental.',
      icon: 'meeting_room',
      sort_order: 5,
      is_active: true,
      created_at: new Date().toISOString(),
    },
  ],
  products: [
    {
      id: 1,
      business_id: 1,
      category_id: 1,
      name: 'Comprehensive Health Consult',
      sku: 'MED-101',
      product_type: 'normal',
      price: 65.0,
      description: 'Standard veterinary consultation and vitals examination.',
      is_active: true,
      modifiers: [4, 5],
      combo_items: [],
      created_at: new Date().toISOString(),
    },
    {
      id: 2,
      business_id: 1,
      category_id: 2,
      name: 'Full Luxury Spa & Grooming',
      sku: 'GRM-201',
      product_type: 'normal',
      price: 85.0,
      description: 'Hydrating wash, blow-dry, ear cleaning, and breed-standard cut.',
      is_active: true,
      modifiers: [4],
      combo_items: [],
      created_at: new Date().toISOString(),
    },
    {
      id: 3,
      business_id: 1,
      category_id: 3,
      name: 'Deluxe Suite Overnight Stay',
      sku: 'HTL-301',
      product_type: 'normal',
      price: 110.0,
      description: 'Climate-controlled suite with webcam monitoring & outdoor playtime.',
      is_active: true,
      modifiers: [],
      combo_items: [],
      created_at: new Date().toISOString(),
    },
    {
      id: 4,
      business_id: 1,
      category_id: 2,
      name: 'Aroma Therapy & Herbal Paw Balm',
      sku: 'MOD-401',
      product_type: 'modifier',
      price: 15.0,
      description: 'Organic paw protection balm and calming aromatherapy add-on.',
      is_active: true,
      modifiers: [],
      combo_items: [],
      created_at: new Date().toISOString(),
    },
    {
      id: 5,
      business_id: 1,
      category_id: 1,
      name: 'Express Diagnostic Panel',
      sku: 'MOD-402',
      product_type: 'modifier',
      price: 45.0,
      description: 'Same-day rapid blood & vitals profile addition.',
      is_active: true,
      modifiers: [],
      combo_items: [],
      created_at: new Date().toISOString(),
    },
    {
      id: 6,
      business_id: 1,
      category_id: 1,
      name: 'Unified Wellness & Grooming Bundle',
      sku: 'CMB-501',
      product_type: 'combo',
      price: 135.0,
      description: 'Combo package: Health Consult + Full Spa Grooming + Herbal Balm.',
      is_active: true,
      modifiers: [],
      combo_items: [
        { product_id: 1, quantity: 1, name: 'Comprehensive Health Consult' },
        { product_id: 2, quantity: 1, name: 'Full Luxury Spa & Grooming' },
        { product_id: 4, quantity: 1, name: 'Aroma Therapy & Herbal Paw Balm' },
      ],
      created_at: new Date().toISOString(),
    },
  ],
  appointments: (() => {
    const today = new Date().toISOString().split('T')[0];
    return [
      {
        id: 1, business_id: 1, staff_id: 1, customer_id: 1,
        customer_name: 'Omopet', customer_phone: '+1 555-4421',
        staff_name: 'Dr. Shaun Ong',
        appointment_date: today, start_time: '17:00', end_time: '17:30',
        status: 'completed', total_amount: 65.00,
        services: [{ product_id: 1, name: 'Omopet Bath Basic', price: 65.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 2, business_id: 1, staff_id: 1, customer_id: 1,
        customer_name: 'New Bel... (Persian Cat)', customer_phone: '+1 555-4421',
        staff_name: 'Dr. Shaun Ong',
        appointment_date: today, start_time: '18:00', end_time: '19:30',
        status: 'no_show', total_amount: 120.00,
        services: [{ product_id: 2, name: 'Full Fur Detangling & Spa', price: 120.00 }],
        notes: 'Client missed check-in', created_at: new Date().toISOString(),
      },
      {
        id: 3, business_id: 1, staff_id: 1, customer_id: 2,
        customer_name: 'test (Golden Retriever)', customer_phone: '+1 555-8832',
        staff_name: 'Dr. Shaun Ong',
        appointment_date: today, start_time: '18:45', end_time: '19:44',
        status: 'completed', total_amount: 75.00,
        services: [{ product_id: 2, name: 'Deep Deshedding + Ear Clean', price: 75.00 }],
        notes: 'Paid via Card', created_at: new Date().toISOString(),
      },
      {
        id: 4, business_id: 1, staff_id: 1, customer_id: 1,
        customer_name: 'Omopet', customer_phone: '+1 555-4421',
        staff_name: 'Dr. Shaun Ong',
        appointment_date: today, start_time: '20:00', end_time: '20:30',
        status: 'completed', total_amount: 45.00,
        services: [{ product_id: 1, name: 'Omopet Express Bath', price: 45.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 5, business_id: 1, staff_id: 1, customer_id: 1,
        customer_name: 'Omopet', customer_phone: '+1 555-4421',
        staff_name: 'Dr. Shaun Ong',
        appointment_date: today, start_time: '20:30', end_time: '21:00',
        status: 'in_service', total_amount: 55.00,
        services: [{ product_id: 2, name: 'Omopet Haircut & Style', price: 55.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 6, business_id: 1, staff_id: 1, customer_id: 1,
        customer_name: 'Omopet', customer_phone: '+1 555-4421',
        staff_name: 'Dr. Shaun Ong',
        appointment_date: today, start_time: '21:00', end_time: '21:30',
        status: 'in_service', total_amount: 25.00,
        services: [{ product_id: 4, name: 'Omopet Nail Trimming', price: 25.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 7, business_id: 1, staff_id: 2, customer_id: 2,
        customer_name: 'Consultation — Milo', customer_phone: '+1 555-8832',
        staff_name: 'Elena Rostova',
        appointment_date: today, start_time: '17:00', end_time: '17:30',
        status: 'completed', total_amount: 65.00,
        services: [{ product_id: 1, name: 'Consultation — Milo', price: 65.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 8, business_id: 1, staff_id: 2, customer_id: 1,
        customer_name: 'Quick Vet Assessment', customer_phone: '+1 555-4421',
        staff_name: 'Elena Rostova',
        appointment_date: today, start_time: '18:44', end_time: '19:00',
        status: 'completed', total_amount: 45.00,
        services: [{ product_id: 5, name: 'Quick Vet Assessment', price: 45.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 9, business_id: 1, staff_id: 2, customer_id: 1,
        customer_name: 'Omopet', customer_phone: '+1 555-4421',
        staff_name: 'Elena Rostova',
        appointment_date: today, start_time: '20:00', end_time: '20:30',
        status: 'cancelled', total_amount: 0,
        services: [{ product_id: 1, name: 'Omopet Routine Check', price: 65.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 10, business_id: 1, staff_id: 2, customer_id: 2,
        customer_name: 'Vaccine Booster (Corgi)', customer_phone: '+1 555-8832',
        staff_name: 'Elena Rostova',
        appointment_date: today, start_time: '20:30', end_time: '21:00',
        status: 'cancelled', total_amount: 0,
        services: [{ product_id: 1, name: 'Vaccine Booster (Corgi)', price: 65.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 11, business_id: 1, staff_id: 2, customer_id: 1,
        customer_name: 'Omopet', customer_phone: '+1 555-4421',
        staff_name: 'Elena Rostova',
        appointment_date: today, start_time: '21:00', end_time: '21:30',
        status: 'in_service', total_amount: 85.00,
        services: [{ product_id: 2, name: 'Omopet Dental Cleaning', price: 85.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 12, business_id: 1, staff_id: 3, customer_id: 2,
        customer_name: 'r4r4', customer_phone: '+1 555-8832',
        staff_name: 'Marcus Vance',
        appointment_date: today, start_time: '18:00', end_time: '18:30',
        status: 'in_service', total_amount: 85.00,
        services: [{ product_id: 2, name: 'r4r4 Therapy Session', price: 85.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 13, business_id: 1, staff_id: 3, customer_id: 2,
        customer_name: 'test', customer_phone: '+1 555-8832',
        staff_name: 'Marcus Vance',
        appointment_date: today, start_time: '20:00', end_time: '20:30',
        status: 'cancelled', total_amount: 0,
        services: [{ product_id: 2, name: 'test Hydrotherapy', price: 85.00 }],
        notes: '', created_at: new Date().toISOString(),
      },
      {
        id: 14, business_id: 1, staff_id: 3, customer_id: 1,
        customer_name: 'Tester (Shih Tzu)', customer_phone: '+1 555-4421',
        staff_name: 'Marcus Vance',
        appointment_date: today, start_time: '20:30', end_time: '21:24',
        status: 'completed', total_amount: 110.00,
        services: [{ product_id: 3, name: 'Acupuncture & Relaxation', price: 110.00 }],
        notes: 'Verified by Tester Omopet', created_at: new Date().toISOString(),
      },
    ];
  })(),
  settings: [
    {
      id: 1,
      business_id: 1,
      time_format: '12',
      clock_display: '12h',
      booking_slot_interval: 30,
      buffer_time_between_sessions: 10,
      open_time: '08:00',
      close_time: '20:00',
      allow_walk_in_queue: true,
      require_doctor_notes: true,
      allow_delete_service: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
  ],
};

function initFallbackStorage() {
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }

  for (const [key, filepath] of Object.entries(jsonFiles)) {
    if (!fs.existsSync(filepath)) {
      fs.writeFileSync(filepath, JSON.stringify(initialData[key] || [], null, 2), 'utf8');
    }
  }
}

function readJson(key) {
  initFallbackStorage();
  try {
    const raw = fs.readFileSync(jsonFiles[key], 'utf8');
    return JSON.parse(raw || '[]');
  } catch (err) {
    console.error(`Error reading ${key}.json:`, err);
    return [];
  }
}

function writeJson(key, data) {
  initFallbackStorage();
  fs.writeFileSync(jsonFiles[key], JSON.stringify(data, null, 2), 'utf8');
}

// Initialize MySQL Tables
async function initDatabase() {
  const host = process.env.DB_HOST || 'localhost';
  const user = process.env.DB_USER || 'root';
  const password = process.env.DB_PASSWORD || '';
  const database = process.env.DB_NAME || 'appointment_hotel_booking';
  const port = parseInt(process.env.DB_PORT || '3306', 10);

  try {
    const tempConnection = await mysql.createConnection({
      host,
      user,
      password,
      port,
      connectTimeout: 3000,
    });

    await tempConnection.query(`CREATE DATABASE IF NOT EXISTS \`${database}\`;`);
    await tempConnection.end();

    pool = mysql.createPool({
      host,
      user,
      password,
      database,
      port,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
    });

    // Create Tables
    const schema = `
      CREATE TABLE IF NOT EXISTS businesses (
        id INT AUTO_INCREMENT PRIMARY KEY,
        business_name VARCHAR(255) NOT NULL,
        business_type VARCHAR(100) NOT NULL,
        owner_name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL UNIQUE,
        phone VARCHAR(50) NOT NULL,
        password VARCHAR(255) NOT NULL,
        address VARCHAR(255) DEFAULT '',
        city VARCHAR(100) DEFAULT '',
        country VARCHAR(100) DEFAULT '',
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

      CREATE TABLE IF NOT EXISTS staff (
        id INT AUTO_INCREMENT PRIMARY KEY,
        business_id INT NOT NULL,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255),
        phone VARCHAR(50),
        role VARCHAR(100) DEFAULT 'Staff',
        color_code VARCHAR(50) DEFAULT '#B42907',
        image LONGTEXT,
        is_active BOOLEAN DEFAULT TRUE,
        deleted_at DATETIME NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

      CREATE TABLE IF NOT EXISTS customers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        business_id INT NOT NULL,
        name VARCHAR(255) NOT NULL,
        phone VARCHAR(50) NOT NULL,
        email VARCHAR(255) DEFAULT '',
        is_walk_in BOOLEAN DEFAULT FALSE,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

      CREATE TABLE IF NOT EXISTS categories (
        id INT AUTO_INCREMENT PRIMARY KEY,
        business_id INT NOT NULL,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        icon VARCHAR(100) DEFAULT 'category',
        sort_order INT DEFAULT 0,
        show_in_appointment BOOLEAN DEFAULT TRUE,
        is_active BOOLEAN DEFAULT TRUE,
        is_deleted BOOLEAN DEFAULT FALSE,
        deleted_at DATETIME NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

      CREATE TABLE IF NOT EXISTS products (
        id INT AUTO_INCREMENT PRIMARY KEY,
        business_id INT NOT NULL,
        category_id INT NULL,
        name VARCHAR(255) NOT NULL,
        sku VARCHAR(100) DEFAULT '',
        product_type VARCHAR(50) DEFAULT 'normal',
        price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        description TEXT,
        modifiers JSON NULL,
        combo_items JSON NULL,
        is_active BOOLEAN DEFAULT TRUE,
        is_deleted BOOLEAN DEFAULT FALSE,
        deleted_at DATETIME NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

      CREATE TABLE IF NOT EXISTS appointments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        business_id INT NOT NULL,
        staff_id INT NOT NULL,
        customer_id INT NULL,
        customer_name VARCHAR(255) DEFAULT '',
        customer_phone VARCHAR(50) DEFAULT '',
        staff_name VARCHAR(255) DEFAULT '',
        appointment_date DATE NOT NULL,
        start_time VARCHAR(10) NOT NULL,
        end_time VARCHAR(10) NOT NULL,
        status ENUM('booked', 'in_service', 'completed', 'no_show', 'cancelled') DEFAULT 'booked',
        total_amount DECIMAL(10, 2) DEFAULT 0.00,
        services JSON NULL,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

      CREATE TABLE IF NOT EXISTS sales (
        id INT AUTO_INCREMENT PRIMARY KEY,
        business_id INT NOT NULL,
        appointment_id INT NULL,
        customer_id INT NULL,
        customer_name VARCHAR(255) NOT NULL DEFAULT '',
        customer_phone VARCHAR(50) DEFAULT '',
        staff_id INT NULL,
        staff_name VARCHAR(255) DEFAULT '',
        subtotal DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        item_discount_total DECIMAL(10, 2) DEFAULT 0.00,
        overall_discount DECIMAL(10, 2) DEFAULT 0.00,
        tax_amount DECIMAL(10, 2) DEFAULT 0.00,
        total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        payment_method ENUM('cash', 'card', 'qr', 'other') NOT NULL DEFAULT 'cash',
        amount_tendered DECIMAL(10, 2) DEFAULT 0.00,
        change_amount DECIMAL(10, 2) DEFAULT 0.00,
        items JSON NULL,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

      CREATE TABLE IF NOT EXISTS settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        business_id INT NOT NULL DEFAULT 1,
        time_format VARCHAR(10) DEFAULT '12',
        clock_display VARCHAR(20) DEFAULT '12h',
        booking_slot_interval INT DEFAULT 30,
        buffer_time_between_sessions INT DEFAULT 10,
        open_time VARCHAR(10) DEFAULT '08:00',
        close_time VARCHAR(10) DEFAULT '20:00',
        allow_walk_in_queue BOOLEAN DEFAULT TRUE,
        require_doctor_notes BOOLEAN DEFAULT TRUE,
        allow_delete_service BOOLEAN DEFAULT FALSE,
        appointment_v2_clock BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_business (business_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

      CREATE TABLE IF NOT EXISTS refunds (
        id INT AUTO_INCREMENT PRIMARY KEY,
        refund_receipt_number VARCHAR(100) NOT NULL UNIQUE,
        business_id INT NOT NULL DEFAULT 1,
        sale_id INT NULL,
        appointment_id INT NULL,
        refund_type ENUM('partial', 'full') NOT NULL DEFAULT 'partial',
        subtotal_refunded DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        discount_reversed_total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        gst_reversed_total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        total_refund_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        refund_method VARCHAR(50) NOT NULL DEFAULT 'cash',
        reason VARCHAR(255) DEFAULT '',
        notes TEXT,
        items JSON NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_sale (sale_id),
        INDEX idx_appointment (appointment_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `;

    // Run each statement
    const statements = schema.split(';').map((s) => s.trim()).filter((s) => s.length > 0);
    for (const sql of statements) {
      await pool.query(sql);
    }

    try {
      await pool.query('ALTER TABLE categories ADD COLUMN show_in_appointment BOOLEAN DEFAULT TRUE');
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE categories ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE');
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE categories ADD COLUMN deleted_at DATETIME NULL');
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE products ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE');
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE staff ADD COLUMN image LONGTEXT NULL');
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE settings ADD COLUMN appointment_v2_clock BOOLEAN DEFAULT TRUE');
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE settings ADD COLUMN printer_settings JSON NULL');
    } catch (_) {}

    try {
      await pool.query("ALTER TABLE sales ADD COLUMN refund_status ENUM('none', 'partial', 'full') DEFAULT 'none'");
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE sales ADD COLUMN refunded_amount DECIMAL(10, 2) DEFAULT 0.00');
    } catch (_) {}

    try {
      await pool.query("ALTER TABLE appointments ADD COLUMN refund_status ENUM('none', 'partial', 'full') DEFAULT 'none'");
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE appointments ADD COLUMN refunded_amount DECIMAL(10, 2) DEFAULT 0.00');
    } catch (_) {}

    try {
      await pool.query('CREATE INDEX idx_products_biz_cat ON products (business_id, is_active, category_id, id)');
    } catch (_) {}

    try {
      await pool.query(`
        INSERT INTO settings (business_id, time_format, clock_display, booking_slot_interval, buffer_time_between_sessions, open_time, close_time, allow_walk_in_queue, require_doctor_notes, allow_delete_service, appointment_v2_clock)
        VALUES (1, '12', '12h', 30, 10, '08:00', '20:00', TRUE, TRUE, FALSE, TRUE)
        ON DUPLICATE KEY UPDATE id=id;
      `);
    } catch (_) {}

    useFallback = false;
    console.log(`✅ [MySQL] Connected and verified schemas in database: "${database}"`);
  } catch (err) {
    console.warn(`⚠️ [MySQL] Connection failed (${err.message}). Using local JSON fallback in /data.`);
    useFallback = true;
    initFallbackStorage();
  }
}

// ----------------- Business Auth Helpers -----------------
async function findBusinessByEmail(email) {
  const norm = (email || '').trim().toLowerCase();
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT * FROM businesses WHERE LOWER(email) = ?', [norm]);
      return rows[0] || null;
    } catch (e) {
      console.error(e);
    }
  }
  const businesses = readJson('businesses');
  return businesses.find((b) => b.email.toLowerCase() === norm) || null;
}

async function findBusinessById(id) {
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT id, business_name, business_type, owner_name, email, phone, address, city, country, description, created_at FROM businesses WHERE id = ?', [id]);
      return rows[0] || null;
    } catch (e) {
      console.error(e);
    }
  }
  const businesses = readJson('businesses');
  const b = businesses.find((x) => String(x.id) === String(id));
  if (!b) return null;
  const { password, ...safe } = b;
  return safe;
}

async function createBusiness(data) {
  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO businesses 
        (business_name, business_type, owner_name, email, phone, password, address, city, country, description) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      const [res] = await pool.query(query, [
        data.business_name.trim(),
        data.business_type.trim(),
        data.owner_name.trim(),
        data.email.trim().toLowerCase(),
        data.phone.trim(),
        data.password,
        data.address || '',
        data.city || '',
        data.country || '',
        data.description || '',
      ]);
      return { id: res.insertId, ...data, created_at: new Date().toISOString() };
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('businesses');
  const id = list.length > 0 ? Math.max(...list.map((x) => Number(x.id) || 0)) + 1 : 1;
  const newB = { id, ...data, email: data.email.trim().toLowerCase(), created_at: new Date().toISOString() };
  list.push(newB);
  writeJson('businesses', list);
  const { password, ...safe } = newB;
  return safe;
}

// ----------------- Staff Helpers -----------------
async function getStaffList(businessId, search = '', includeDeleted = false) {
  const s = (search || '').trim().toLowerCase();
  if (!useFallback && pool) {
    try {
      let query = 'SELECT * FROM staff WHERE (business_id = ? OR business_id = 1)';
      const params = [businessId || 1];
      if (!includeDeleted) {
        query += ' AND is_active = TRUE';
      }
      if (s) {
        query += ' AND (LOWER(name) LIKE ? OR LOWER(role) LIKE ? OR LOWER(email) LIKE ? OR phone LIKE ?)';
        const wild = `%${s}%`;
        params.push(wild, wild, wild, wild);
      }
      query += ' ORDER BY id DESC';
      const [rows] = await pool.query(query, params);
      return rows;
    } catch (e) {
      console.error(e);
    }
  }

  let list = readJson('staff');
  if (!includeDeleted) {
    list = list.filter((st) => st.is_active !== false);
  }
  if (s) {
    list = list.filter((st) =>
      (st.name || '').toLowerCase().includes(s) ||
      (st.role || '').toLowerCase().includes(s) ||
      (st.email || '').toLowerCase().includes(s) ||
      (st.phone || '').includes(s)
    );
  }
  return list;
}

async function getStaffById(id) {
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT * FROM staff WHERE id = ?', [id]);
      return rows[0] || null;
    } catch (e) {
      console.error(e);
    }
  }
  const list = readJson('staff');
  return list.find((st) => String(st.id) === String(id)) || null;
}

async function createStaff(data) {
  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO staff (business_id, name, email, phone, role, color_code, image, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, TRUE)
      `;
      const [res] = await pool.query(query, [
        data.business_id || 1,
        data.name.trim(),
        data.email || '',
        data.phone || '',
        data.role || 'Staff',
        data.color_code || '#B42907',
        data.image || null,
      ]);
      return { id: res.insertId, ...data, is_active: true, created_at: new Date().toISOString() };
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('staff');
  const id = list.length > 0 ? Math.max(...list.map((x) => Number(x.id) || 0)) + 1 : 1;
  const newSt = {
    id,
    business_id: data.business_id || 1,
    name: data.name.trim(),
    email: data.email || '',
    phone: data.phone || '',
    role: data.role || 'Staff',
    color_code: data.color_code || '#B42907',
    image: data.image || null,
    is_active: true,
    deleted_at: null,
    created_at: new Date().toISOString(),
  };
  list.unshift(newSt);
  writeJson('staff', list);
  return newSt;
}

async function updateStaff(id, data) {
  if (!useFallback && pool) {
    try {
      const fields = [];
      const values = [];
      if (data.name !== undefined) { fields.push('name = ?'); values.push(data.name); }
      if (data.email !== undefined) { fields.push('email = ?'); values.push(data.email); }
      if (data.phone !== undefined) { fields.push('phone = ?'); values.push(data.phone); }
      if (data.role !== undefined) { fields.push('role = ?'); values.push(data.role); }
      if (data.color_code !== undefined) { fields.push('color_code = ?'); values.push(data.color_code); }
      if (data.image !== undefined) { fields.push('image = ?'); values.push(data.image); }
      if (data.is_active !== undefined) { fields.push('is_active = ?'); values.push(Boolean(data.is_active)); }

      if (fields.length > 0) {
        values.push(id);
        await pool.query(`UPDATE staff SET ${fields.join(', ')} WHERE id = ?`, values);
      }
      return await getStaffById(id);
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('staff');
  const idx = list.findIndex((x) => String(x.id) === String(id));
  if (idx === -1) return null;
  list[idx] = { ...list[idx], ...data, updated_at: new Date().toISOString() };
  writeJson('staff', list);
  return list[idx];
}

// Soft Delete: Preserves records for historical appointment logs
async function deleteStaff(id) {
  if (!useFallback && pool) {
    try {
      await pool.query('UPDATE staff SET is_active = FALSE, deleted_at = NOW() WHERE id = ?', [id]);
      return true;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('staff');
  const idx = list.findIndex((x) => String(x.id) === String(id));
  if (idx === -1) return false;
  list[idx].is_active = false;
  list[idx].deleted_at = new Date().toISOString();
  writeJson('staff', list);
  return true;
}

// ----------------- Customer Helpers -----------------
async function getCustomers(businessId, search = '') {
  const s = (search || '').trim().toLowerCase();
  if (!useFallback && pool) {
    try {
      let query = 'SELECT * FROM customers WHERE (business_id = ? OR business_id = 1)';
      const params = [businessId || 1];
      if (s) {
        query += ' AND (LOWER(name) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(email) LIKE ?)';
        const wild = `%${s}%`;
        params.push(wild, wild, wild);
      }
      query += ' ORDER BY id DESC';
      const [rows] = await pool.query(query, params);
      return rows;
    } catch (e) {
      console.error(e);
    }
  }

  let list = readJson('customers');
  if (s) {
    list = list.filter((c) =>
      (c.name || '').toLowerCase().includes(s) ||
      (c.phone || '').includes(s) ||
      (c.email || '').toLowerCase().includes(s)
    );
  }
  return list;
}

async function createCustomer(data) {
  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO customers (business_id, name, phone, email, is_walk_in, notes)
        VALUES (?, ?, ?, ?, ?, ?)
      `;
      const [res] = await pool.query(query, [
        data.business_id || 1,
        data.name.trim(),
        data.phone.trim(),
        data.email || '',
        data.is_walk_in ? 1 : 0,
        data.notes || '',
      ]);
      return { id: res.insertId, ...data, created_at: new Date().toISOString() };
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('customers');
  const id = list.length > 0 ? Math.max(...list.map((x) => Number(x.id) || 0)) + 1 : 1;
  const newC = {
    id,
    business_id: data.business_id || 1,
    name: data.name.trim(),
    phone: data.phone.trim(),
    email: data.email || '',
    is_walk_in: Boolean(data.is_walk_in),
    notes: data.notes || '',
    created_at: new Date().toISOString(),
  };
  list.unshift(newC);
  writeJson('customers', list);
  return newC;
}

// ----------------- Categories Helpers -----------------
async function getCategories(businessId) {
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query(
        'SELECT * FROM categories WHERE (business_id = ? OR business_id = 1) AND is_active = TRUE AND (is_deleted = FALSE OR is_deleted IS NULL) ORDER BY sort_order ASC, id ASC',
        [businessId || 1]
      );
      return rows;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('categories');
  return list
    .filter((c) => c.is_active !== false && c.is_deleted !== true && c.is_deleted !== 1)
    .sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
}

async function createCategory(data) {
  const showInAppointment = data.show_in_appointment !== false && data.show_in_appointment !== 'false';
  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO categories (business_id, name, description, icon, sort_order, show_in_appointment, is_active, is_deleted)
        VALUES (?, ?, ?, ?, ?, ?, TRUE, FALSE)
      `;
      const [res] = await pool.query(query, [
        data.business_id || 1,
        data.name.trim(),
        data.description || '',
        data.icon || 'category',
        data.sort_order || 0,
        showInAppointment,
      ]);
      return { id: res.insertId, ...data, show_in_appointment: showInAppointment, is_active: true, is_deleted: false, created_at: new Date().toISOString() };
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('categories');
  const id = list.length > 0 ? Math.max(...list.map((x) => Number(x.id) || 0)) + 1 : 1;
  const newCat = {
    id,
    business_id: data.business_id || 1,
    name: data.name.trim(),
    description: data.description || '',
    icon: data.icon || 'category',
    sort_order: Number(data.sort_order) || 0,
    show_in_appointment: showInAppointment,
    is_active: true,
    is_deleted: false,
    deleted_at: null,
    created_at: new Date().toISOString(),
  };
  list.push(newCat);
  writeJson('categories', list);
  return newCat;
}

async function updateCategory(id, data) {
  if (!useFallback && pool) {
    try {
      const fields = [];
      const values = [];
      if (data.name !== undefined) { fields.push('name = ?'); values.push(data.name); }
      if (data.description !== undefined) { fields.push('description = ?'); values.push(data.description); }
      if (data.icon !== undefined) { fields.push('icon = ?'); values.push(data.icon); }
      if (data.sort_order !== undefined) { fields.push('sort_order = ?'); values.push(data.sort_order); }
      if (data.show_in_appointment !== undefined) {
        fields.push('show_in_appointment = ?');
        values.push(data.show_in_appointment === true || data.show_in_appointment === 1 || data.show_in_appointment === 'true');
      }
      if (data.is_active !== undefined) { fields.push('is_active = ?'); values.push(Boolean(data.is_active)); }
      if (data.is_deleted !== undefined) { fields.push('is_deleted = ?'); values.push(Boolean(data.is_deleted)); }

      if (fields.length > 0) {
        values.push(id);
        await pool.query(`UPDATE categories SET ${fields.join(', ')} WHERE id = ?`, values);
      }
      const [rows] = await pool.query('SELECT * FROM categories WHERE id = ?', [id]);
      return rows[0] || null;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('categories');
  const idx = list.findIndex((c) => String(c.id) === String(id));
  if (idx === -1) return null;
  const showInAppointment = data.show_in_appointment !== undefined
    ? (data.show_in_appointment === true || data.show_in_appointment === 1 || data.show_in_appointment === 'true')
    : (list[idx].show_in_appointment !== false);
  list[idx] = { ...list[idx], ...data, show_in_appointment: showInAppointment };
  writeJson('categories', list);
  return list[idx];
}

async function deleteCategory(id) {
  if (!useFallback && pool) {
    try {
      await pool.query('UPDATE categories SET is_deleted = TRUE, is_active = FALSE, deleted_at = NOW() WHERE id = ?', [id]);
      return true;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('categories');
  const idx = list.findIndex((c) => String(c.id) === String(id));
  if (idx === -1) return false;
  list[idx].is_deleted = true;
  list[idx].is_active = false;
  list[idx].deleted_at = new Date().toISOString();
  writeJson('categories', list);
  return true;
}

// ----------------- Products Helpers -----------------
async function getProducts(businessId, categoryId = null, productType = null, search = '') {
  const s = (search || '').trim().toLowerCase();
  if (!useFallback && pool) {
    try {
      let query = 'SELECT * FROM products WHERE (business_id = ? OR business_id = 1) AND is_active = TRUE AND (is_deleted = FALSE OR is_deleted IS NULL)';
      const params = [businessId || 1];
      if (categoryId) {
        query += ' AND category_id = ?';
        params.push(categoryId);
      }
      if (productType) {
        query += ' AND product_type = ?';
        params.push(productType);
      }
      if (s) {
        query += ' AND (LOWER(name) LIKE ? OR LOWER(sku) LIKE ? OR LOWER(description) LIKE ?)';
        const wild = `%${s}%`;
        params.push(wild, wild, wild);
      }
      query += ' ORDER BY id DESC';
      const [rows] = await pool.query(query, params);
      return rows;
    } catch (e) {
      console.error(e);
    }
  }

  let list = readJson('products');
  list = list.filter((p) => p.is_active !== false && p.is_deleted !== true && p.is_deleted !== 1);
  if (categoryId) {
    list = list.filter((p) => String(p.category_id) === String(categoryId));
  }
  if (productType) {
    list = list.filter((p) => p.product_type === productType);
  }
  if (s) {
    list = list.filter((p) =>
      (p.name || '').toLowerCase().includes(s) ||
      (p.sku || '').toLowerCase().includes(s) ||
      (p.description || '').toLowerCase().includes(s)
    );
  }
  return list;
}

// Dedicated Paginated Products query for React Cart Page (batch size: default 20)
async function getPaginatedProducts(businessId, { categoryId = null, productType = null, search = '', page = 1, limit = 20 } = {}) {
  const p = Math.max(1, parseInt(page, 10) || 1);
  const l = Math.max(1, parseInt(limit, 10) || 20);
  const offset = (p - 1) * l;
  const s = (search || '').trim().toLowerCase();

  if (!useFallback && pool) {
    try {
      let whereClause = ' WHERE (business_id = ? OR business_id = 1) AND is_active = TRUE AND (is_deleted = FALSE OR is_deleted IS NULL)';
      const countParams = [businessId || 1];

      if (categoryId && categoryId !== 'all') {
        whereClause += ' AND category_id = ?';
        countParams.push(categoryId);
      }
      if (productType) {
        whereClause += ' AND product_type = ?';
        countParams.push(productType);
      }
      if (s) {
        whereClause += ' AND (LOWER(name) LIKE ? OR LOWER(sku) LIKE ? OR LOWER(description) LIKE ?)';
        const wild = `%${s}%`;
        countParams.push(wild, wild, wild);
      }

      // 1. Total count query
      const countQuery = `SELECT COUNT(*) AS total FROM products${whereClause}`;
      const [countRows] = await pool.query(countQuery, countParams);
      const total = countRows && countRows[0] ? Number(countRows[0].total) : 0;

      // 2. Paginated data query
      const dataQuery = `SELECT * FROM products${whereClause} ORDER BY id DESC LIMIT ? OFFSET ?`;
      const dataParams = [...countParams, l, offset];
      const [rows] = await pool.query(dataQuery, dataParams);

      const totalPages = Math.ceil(total / l) || 0;
      const hasMore = p < totalPages;

      return {
        products: rows,
        pagination: {
          page: p,
          current_page: p,
          limit: l,
          page_size: l,
          total,
          totalPages,
          has_more: hasMore,
          hasMore: hasMore,
        },
      };
    } catch (e) {
      console.error('getPaginatedProducts DB query error, falling back to JSON:', e);
    }
  }

  // Fallback storage (JSON file)
  let list = readJson('products');
  list = list.filter((p) => p.is_active !== false && p.is_deleted !== true && p.is_deleted !== 1);
  if (categoryId && categoryId !== 'all') {
    list = list.filter((p) => String(p.category_id) === String(categoryId));
  }
  if (productType) {
    list = list.filter((p) => p.product_type === productType);
  }
  if (s) {
    list = list.filter((p) =>
      (p.name || '').toLowerCase().includes(s) ||
      (p.sku || '').toLowerCase().includes(s) ||
      (p.description || '').toLowerCase().includes(s)
    );
  }
  // Sort descending by id to match DB behavior
  list.sort((a, b) => (Number(b.id) || 0) - (Number(a.id) || 0));

  const total = list.length;
  const totalPages = Math.ceil(total / l) || 0;
  const products = list.slice(offset, offset + l);
  const hasMore = p < totalPages;

  return {
    products,
    pagination: {
      page: p,
      current_page: p,
      limit: l,
      page_size: l,
      total,
      totalPages,
      has_more: hasMore,
      hasMore: hasMore,
    },
  };
}

async function createProduct(data) {
  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO products 
        (business_id, category_id, name, sku, product_type, price, description, modifiers, combo_items, is_active, is_deleted)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, TRUE, FALSE)
      `;
      const [res] = await pool.query(query, [
        data.business_id || 1,
        data.category_id ? Number(data.category_id) : null,
        data.name.trim(),
        data.sku || '',
        data.product_type || 'normal',
        Number(data.price) || 0.0,
        data.description || '',
        JSON.stringify(data.modifiers || []),
        JSON.stringify(data.combo_items || []),
      ]);
      return { id: res.insertId, ...data, is_active: true, is_deleted: false, created_at: new Date().toISOString() };
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('products');
  const id = list.length > 0 ? Math.max(...list.map((x) => Number(x.id) || 0)) + 1 : 1;
  const newProd = {
    id,
    business_id: data.business_id || 1,
    category_id: data.category_id ? Number(data.category_id) : null,
    name: data.name.trim(),
    sku: data.sku || '',
    product_type: data.product_type || 'normal',
    price: Number(data.price) || 0.0,
    description: data.description || '',
    modifiers: data.modifiers || [],
    combo_items: data.combo_items || [],
    is_active: true,
    is_deleted: false,
    deleted_at: null,
    created_at: new Date().toISOString(),
  };
  list.unshift(newProd);
  writeJson('products', list);
  return newProd;
}

async function updateProduct(id, data) {
  if (!useFallback && pool) {
    try {
      const fields = [];
      const values = [];
      if (data.category_id !== undefined) {
        fields.push('category_id = ?');
        values.push(data.category_id ? Number(data.category_id) : null);
      }
      if (data.name !== undefined) {
        fields.push('name = ?');
        values.push(data.name.trim());
      }
      if (data.sku !== undefined) {
        fields.push('sku = ?');
        values.push(data.sku);
      }
      if (data.product_type !== undefined) {
        fields.push('product_type = ?');
        values.push(data.product_type);
      }
      if (data.price !== undefined) {
        fields.push('price = ?');
        values.push(Number(data.price) || 0.0);
      }
      if (data.description !== undefined) {
        fields.push('description = ?');
        values.push(data.description);
      }
      if (data.modifiers !== undefined) {
        fields.push('modifiers = ?');
        values.push(JSON.stringify(data.modifiers || []));
      }
      if (data.combo_items !== undefined) {
        fields.push('combo_items = ?');
        values.push(JSON.stringify(data.combo_items || []));
      }
      if (data.is_active !== undefined) {
        fields.push('is_active = ?');
        values.push(Boolean(data.is_active));
      }
      if (data.is_deleted !== undefined) {
        fields.push('is_deleted = ?');
        values.push(Boolean(data.is_deleted));
      }

      if (fields.length > 0) {
        values.push(id);
        await pool.query(`UPDATE products SET ${fields.join(', ')} WHERE id = ?`, values);
      }
      const [rows] = await pool.query('SELECT * FROM products WHERE id = ?', [id]);
      return rows[0] || null;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('products');
  const idx = list.findIndex((p) => String(p.id) === String(id));
  if (idx === -1) return null;
  list[idx] = { ...list[idx], ...data, updated_at: new Date().toISOString() };
  writeJson('products', list);
  return list[idx];
}

async function deleteProduct(id) {
  if (!useFallback && pool) {
    try {
      await pool.query('UPDATE products SET is_deleted = TRUE, is_active = FALSE, deleted_at = NOW() WHERE id = ?', [id]);
      return true;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('products');
  const idx = list.findIndex((p) => String(p.id) === String(id));
  if (idx === -1) return false;
  list[idx].is_deleted = true;
  list[idx].is_active = false;
  list[idx].deleted_at = new Date().toISOString();
  writeJson('products', list);
  return true;
}

// ----------------- Appointments Helpers -----------------
async function getAppointments(date = null, staffId = null, search = null, status = null) {
  if (!useFallback && pool) {
    try {
      let query = `
        SELECT a.*, COALESCE(NULLIF(a.staff_name, ''), s.name, '') AS staff_name
        FROM appointments a
        LEFT JOIN staff s ON a.staff_id = s.id
        WHERE a.business_id = 1
      `;
      const params = [];
      if (date) {
        query += ' AND a.appointment_date = ?';
        params.push(date);
      }
      if (staffId) {
        query += ' AND a.staff_id = ?';
        params.push(staffId);
      }
      if (status) {
        query += ' AND a.status = ?';
        params.push(status);
      }
      if (search && search.trim().length > 0) {
        const term = `%${search.trim()}%`;
        query += ' AND (a.customer_name LIKE ? OR a.customer_phone LIKE ? OR a.staff_name LIKE ? OR s.name LIKE ?)';
        params.push(term, term, term, term);
      }
      if (date) {
        query += ' ORDER BY a.start_time ASC';
      } else {
        query += ' ORDER BY a.appointment_date DESC, a.start_time DESC';
      }
      const [rows] = await pool.query(query, params);

      let allRefunds = [];
      try {
        const [refRows] = await pool.query('SELECT * FROM refunds ORDER BY created_at ASC');
        allRefunds = refRows.map((rf) => {
          if (rf.items && typeof rf.items === 'string') {
            try { rf.items = JSON.parse(rf.items); } catch (_) { rf.items = []; }
          }
          return rf;
        });
      } catch (_) {}

      const refundsByAppt = {};
      allRefunds.forEach((rf) => {
        if (rf.appointment_id) {
          if (!refundsByAppt[rf.appointment_id]) refundsByAppt[rf.appointment_id] = [];
          refundsByAppt[rf.appointment_id].push(rf);
        }
      });

      return rows.map((r) => {
        if (r.services && typeof r.services === 'string') {
          try { r.services = JSON.parse(r.services); } catch (_) { r.services = []; }
        }
        const aRefunds = refundsByAppt[r.id] || [];
        const totalRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
        const totalGstRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
        const totalSubtotalRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
        const origTax = Number(r.tax_amount) || 0;
        const origSubtotal = Number(r.subtotal) || Number(r.total_amount) || 0;
        return {
          ...r,
          refunds: aRefunds,
          refunded_amount: Number(r.refunded_amount) || totalRefunded,
          refund_status: r.refund_status || (aRefunds.length > 0 ? (totalRefunded >= Number(r.total_amount) ? 'full' : 'partial') : 'none'),
          gst_reversed_total: totalGstRefunded,
          net_tax_amount: Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100),
          subtotal_refunded_total: totalSubtotalRefunded,
          net_subtotal: Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100),
        };
      });
    } catch (e) {
      console.error(e);
    }
  }

  let list = readJson('appointments');
  const staffList = readJson('staff');
  const staffMap = {};
  staffList.forEach((st) => { staffMap[String(st.id)] = st.name; });

  const allRefundsFallback = readJson('refunds');
  const refundsByApptFallback = {};
  allRefundsFallback.forEach((rf) => {
    if (rf.appointment_id) {
      if (!refundsByApptFallback[rf.appointment_id]) refundsByApptFallback[rf.appointment_id] = [];
      refundsByApptFallback[rf.appointment_id].push(rf);
    }
  });

  list = list.map((a) => {
    const aRefunds = refundsByApptFallback[a.id] || [];
    const totalRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
    const totalGstRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
    const totalSubtotalRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
    const origTax = Number(a.tax_amount) || 0;
    const origSubtotal = Number(a.subtotal) || Number(a.total_amount) || 0;
    return {
      ...a,
      staff_name: a.staff_name || staffMap[String(a.staff_id)] || '',
      refunds: aRefunds,
      refunded_amount: Number(a.refunded_amount) || totalRefunded,
      refund_status: a.refund_status || (aRefunds.length > 0 ? (totalRefunded >= Number(a.total_amount) ? 'full' : 'partial') : 'none'),
      gst_reversed_total: totalGstRefunded,
      net_tax_amount: Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100),
      subtotal_refunded_total: totalSubtotalRefunded,
      net_subtotal: Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100),
    };
  });

  if (date) {
    list = list.filter((a) => a.appointment_date === date);
  }
  if (staffId) {
    list = list.filter((a) => String(a.staff_id) === String(staffId));
  }
  if (status) {
    list = list.filter((a) => String(a.status).toLowerCase() === String(status).toLowerCase());
  }
  if (search && search.trim().length > 0) {
    const q = search.trim().toLowerCase();
    list = list.filter((a) => {
      const cName = (a.customer_name || '').toLowerCase();
      const cPhone = (a.customer_phone || '').toLowerCase();
      const sName = (a.staff_name || staffMap[String(a.staff_id)] || '').toLowerCase();
      return cName.includes(q) || cPhone.includes(q) || sName.includes(q);
    });
  }
  if (date) {
    return list.sort((a, b) => (a.start_time || '').localeCompare(b.start_time || ''));
  }
  return list.sort((a, b) => {
    const dCmp = (b.appointment_date || '').localeCompare(a.appointment_date || '');
    if (dCmp !== 0) return dCmp;
    return (b.start_time || '').localeCompare(a.start_time || '');
  });
}

async function getAppointmentById(id) {
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT * FROM appointments WHERE id = ?', [id]);
      if (!rows[0]) return null;
      const appt = rows[0];
      if (appt.services && typeof appt.services === 'string') {
        try { appt.services = JSON.parse(appt.services); } catch (_) { appt.services = []; }
      }
      try {
        const [refRows] = await pool.query('SELECT * FROM refunds WHERE appointment_id = ? ORDER BY created_at ASC', [id]);
        appt.refunds = refRows.map((rf) => {
          if (rf.items && typeof rf.items === 'string') {
            try { rf.items = JSON.parse(rf.items); } catch (_) { rf.items = []; }
          }
          return rf;
        });
      } catch (_) {
        appt.refunds = [];
      }
      const totalRefunded = appt.refunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
      const totalGstRefunded = appt.refunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
      const totalSubtotalRefunded = appt.refunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
      const origTax = Number(appt.tax_amount) || 0;
      const origSubtotal = Number(appt.subtotal) || Number(appt.total_amount) || 0;
      appt.refunded_amount = Number(appt.refunded_amount) || totalRefunded;
      appt.refund_status = appt.refund_status || (appt.refunds.length > 0 ? (totalRefunded >= Number(appt.total_amount) ? 'full' : 'partial') : 'none');
      appt.gst_reversed_total = totalGstRefunded;
      appt.net_tax_amount = Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100);
      appt.subtotal_refunded_total = totalSubtotalRefunded;
      appt.net_subtotal = Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100);
      return appt;
    } catch (e) {
      console.error(e);
    }
  }
  const list = readJson('appointments');
  const appt = list.find((a) => String(a.id) === String(id)) || null;
  if (!appt) return null;
  const allRefundsFallback = readJson('refunds');
  appt.refunds = allRefundsFallback.filter((rf) => String(rf.appointment_id) === String(id));
  const totalRefunded = appt.refunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
  const totalGstRefunded = appt.refunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
  const totalSubtotalRefunded = appt.refunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
  const origTax = Number(appt.tax_amount) || 0;
  const origSubtotal = Number(appt.subtotal) || Number(appt.total_amount) || 0;
  appt.refunded_amount = Number(appt.refunded_amount) || totalRefunded;
  appt.refund_status = appt.refund_status || (appt.refunds.length > 0 ? (totalRefunded >= Number(appt.total_amount) ? 'full' : 'partial') : 'none');
  appt.gst_reversed_total = totalGstRefunded;
  appt.net_tax_amount = Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100);
  appt.subtotal_refunded_total = totalSubtotalRefunded;
  appt.net_subtotal = Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100);
  return appt;
}

async function getAppointmentStats(date = null) {
  const appts = await getAppointments(date, null);
  const stats = {
    total: appts.length,
    booked: 0,
    in_service: 0,
    completed: 0,
    no_show: 0,
    cancelled: 0,
  };
  for (const a of appts) {
    const s = (a.status || '').toLowerCase().trim();
    if (s === 'booked') {
      stats.booked++;
    } else if (s === 'in_service' || s === 'inservice' || s === 'in-service') {
      stats.in_service++;
    } else if (s === 'completed') {
      stats.completed++;
    } else if (s === 'no_show' || s === 'noshow' || s === 'no-show') {
      stats.no_show++;
    } else if (s === 'cancelled' || s === 'canceled') {
      stats.cancelled++;
    }
  }
  return stats;
}

async function createAppointment(data) {
  let resolvedStaffName = data.staff_name || '';
  if (!resolvedStaffName && data.staff_id) {
    try {
      const staffMember = await getStaffById(data.staff_id);
      if (staffMember) resolvedStaffName = staffMember.name || '';
    } catch (_) {}
  }

  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO appointments
        (business_id, staff_id, customer_id, customer_name, customer_phone, staff_name, appointment_date, start_time, end_time, status, total_amount, services, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      const [res] = await pool.query(query, [
        data.business_id || 1,
        data.staff_id,
        data.customer_id || null,
        data.customer_name || '',
        data.customer_phone || '',
        resolvedStaffName,
        data.appointment_date,
        data.start_time,
        data.end_time,
        data.status || 'booked',
        data.total_amount || 0,
        JSON.stringify(data.services || []),
        data.notes || '',
      ]);
      return { id: res.insertId, ...data, staff_name: resolvedStaffName, created_at: new Date().toISOString() };
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('appointments');
  const id = list.length > 0 ? Math.max(...list.map((x) => Number(x.id) || 0)) + 1 : 1;
  const newAppt = {
    id,
    business_id: data.business_id || 1,
    staff_id: data.staff_id,
    customer_id: data.customer_id || null,
    customer_name: data.customer_name || '',
    customer_phone: data.customer_phone || '',
    staff_name: resolvedStaffName,
    appointment_date: data.appointment_date,
    start_time: data.start_time,
    end_time: data.end_time,
    status: data.status || 'booked',
    total_amount: Number(data.total_amount) || 0,
    services: data.services || [],
    notes: data.notes || '',
    created_at: new Date().toISOString(),
  };
  list.push(newAppt);
  writeJson('appointments', list);
  return newAppt;
}

async function updateAppointmentStatus(id, status) {
  if (!useFallback && pool) {
    try {
      await pool.query('UPDATE appointments SET status = ? WHERE id = ?', [status, id]);
      return await getAppointmentById(id);
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('appointments');
  const idx = list.findIndex((a) => String(a.id) === String(id));
  if (idx === -1) return null;
  list[idx].status = status;
  list[idx].updated_at = new Date().toISOString();
  writeJson('appointments', list);
  return list[idx];
}

async function updateAppointment(id, data) {
  if (!useFallback && pool) {
    try {
      const fields = [];
      const values = [];
      const allowed = ['staff_id', 'customer_id', 'customer_name', 'customer_phone', 'staff_name', 'appointment_date', 'start_time', 'end_time', 'status', 'total_amount', 'notes'];
      for (const key of allowed) {
        if (data[key] !== undefined) {
          fields.push(`${key} = ?`);
          values.push(data[key]);
        }
      }
      if (data.services !== undefined) {
        fields.push('services = ?');
        values.push(JSON.stringify(data.services));
      }
      if (fields.length === 0) return await getAppointmentById(id);
      values.push(id);
      await pool.query(`UPDATE appointments SET ${fields.join(', ')} WHERE id = ?`, values);
      return await getAppointmentById(id);
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('appointments');
  const idx = list.findIndex((a) => String(a.id) === String(id));
  if (idx === -1) return null;
  list[idx] = { ...list[idx], ...data, updated_at: new Date().toISOString() };
  writeJson('appointments', list);
  return list[idx];
}

async function deleteAppointment(id) {
  if (!useFallback && pool) {
    try {
      const [res] = await pool.query('DELETE FROM appointments WHERE id = ?', [id]);
      return res.affectedRows > 0;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('appointments');
  const idx = list.findIndex((a) => String(a.id) === String(id));
  if (idx === -1) return false;
  list.splice(idx, 1);
  writeJson('appointments', list);
  return true;
}

// =================== Sales CRUD ===================
async function getSales(filters = {}) {
  if (!useFallback && pool) {
    try {
      let sql = `
        SELECT sales.*, COALESCE(NULLIF(sales.staff_name, ''), s.name, '') AS staff_name
        FROM sales
        LEFT JOIN staff s ON sales.staff_id = s.id
      `;
      const conditions = [];
      const values = [];
      if (filters.appointment_id) {
        conditions.push('sales.appointment_id = ?');
        values.push(filters.appointment_id);
      } else if (filters.include_appointments !== 'true' && filters.include_appointments !== true) {
        // Exclude appointment transactions by default so Sales History has only normal POS/Cart transactions
        conditions.push('(sales.appointment_id IS NULL OR sales.appointment_id = 0)');
      }
      if (filters.customer_id) {
        conditions.push('sales.customer_id = ?');
        values.push(filters.customer_id);
      }
      if (filters.search && filters.search.trim().length > 0) {
        const term = `%${filters.search.trim()}%`;
        conditions.push('(sales.customer_name LIKE ? OR sales.customer_phone LIKE ? OR sales.staff_name LIKE ? OR s.name LIKE ?)');
        values.push(term, term, term, term);
      }
      if (conditions.length > 0) sql += ' WHERE ' + conditions.join(' AND ');
      sql += ' ORDER BY sales.created_at DESC';
      const [rows] = await pool.query(sql, values);

      let allRefunds = [];
      try {
        const [refRows] = await pool.query('SELECT * FROM refunds ORDER BY created_at ASC');
        allRefunds = refRows.map((rf) => {
          if (rf.items && typeof rf.items === 'string') {
            try { rf.items = JSON.parse(rf.items); } catch (_) { rf.items = []; }
          }
          return rf;
        });
      } catch (_) {}

      const refundsBySale = {};
      allRefunds.forEach((rf) => {
        if (rf.sale_id) {
          if (!refundsBySale[rf.sale_id]) refundsBySale[rf.sale_id] = [];
          refundsBySale[rf.sale_id].push(rf);
        }
      });

      return rows.map((r) => {
        if (r.items && typeof r.items === 'string') {
          try { r.items = JSON.parse(r.items); } catch (_) { r.items = []; }
        }
        const sRefunds = refundsBySale[r.id] || [];
        const totalRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
        const totalGstRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
        const totalSubtotalRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
        const origTax = Number(r.tax_amount) || 0;
        const origSubtotal = Number(r.subtotal) || 0;
        return {
          ...r,
          refunds: sRefunds,
          refunded_amount: Number(r.refunded_amount) || totalRefunded,
          refund_status: r.refund_status || (sRefunds.length > 0 ? (totalRefunded >= Number(r.total_amount) ? 'full' : 'partial') : 'none'),
          gst_reversed_total: totalGstRefunded,
          net_tax_amount: Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100),
          subtotal_refunded_total: totalSubtotalRefunded,
          net_subtotal: Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100),
        };
      });
    } catch (e) {
      console.error(e);
    }
  }
  let list = readJson('sales');
  const staffList = readJson('staff');
  const staffMap = {};
  staffList.forEach((st) => { staffMap[String(st.id)] = st.name; });

  const allRefundsFallback = readJson('refunds');
  const refundsBySaleFallback = {};
  allRefundsFallback.forEach((rf) => {
    if (rf.sale_id) {
      if (!refundsBySaleFallback[rf.sale_id]) refundsBySaleFallback[rf.sale_id] = [];
      refundsBySaleFallback[rf.sale_id].push(rf);
    }
  });

  list = list.map((s) => {
    const sRefunds = refundsBySaleFallback[s.id] || [];
    const totalRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
    const totalGstRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
    const totalSubtotalRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
    const origTax = Number(s.tax_amount) || 0;
    const origSubtotal = Number(s.subtotal) || 0;
    return {
      ...s,
      staff_name: s.staff_name || staffMap[String(s.staff_id)] || '',
      refunds: sRefunds,
      refunded_amount: Number(s.refunded_amount) || totalRefunded,
      refund_status: s.refund_status || (sRefunds.length > 0 ? (totalRefunded >= Number(s.total_amount) ? 'full' : 'partial') : 'none'),
      gst_reversed_total: totalGstRefunded,
      net_tax_amount: Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100),
      subtotal_refunded_total: totalSubtotalRefunded,
      net_subtotal: Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100),
    };
  });

  if (filters.appointment_id) {
    list = list.filter((s) => String(s.appointment_id) === String(filters.appointment_id));
  } else if (filters.include_appointments !== 'true' && filters.include_appointments !== true) {
    list = list.filter((s) => !s.appointment_id || s.appointment_id == 0);
  }
  if (filters.customer_id) list = list.filter((s) => String(s.customer_id) === String(filters.customer_id));
  if (filters.search && filters.search.trim().length > 0) {
    const q = filters.search.trim().toLowerCase();
    list = list.filter((s) => {
      const cName = (s.customer_name || '').toLowerCase();
      const cPhone = (s.customer_phone || '').toLowerCase();
      const sName = (s.staff_name || staffMap[String(s.staff_id)] || '').toLowerCase();
      return cName.includes(q) || cPhone.includes(q) || sName.includes(q);
    });
  }
  return list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
}

async function getSaleById(id) {
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT * FROM sales WHERE id = ?', [id]);
      if (!rows[0]) return null;
      const s = rows[0];
      if (s.items && typeof s.items === 'string') {
        try { s.items = JSON.parse(s.items); } catch (_) { s.items = []; }
      }
      try {
        const [refRows] = await pool.query('SELECT * FROM refunds WHERE sale_id = ? ORDER BY created_at ASC', [id]);
        s.refunds = refRows.map((rf) => {
          if (rf.items && typeof rf.items === 'string') {
            try { rf.items = JSON.parse(rf.items); } catch (_) { rf.items = []; }
          }
          return rf;
        });
      } catch (_) {
        s.refunds = [];
      }
      const totalRefunded = s.refunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
      const totalGstRefunded = s.refunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
      const totalSubtotalRefunded = s.refunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
      const origTax = Number(s.tax_amount) || 0;
      const origSubtotal = Number(s.subtotal) || 0;
      s.refunded_amount = Number(s.refunded_amount) || totalRefunded;
      s.refund_status = s.refund_status || (s.refunds.length > 0 ? (totalRefunded >= Number(s.total_amount) ? 'full' : 'partial') : 'none');
      s.gst_reversed_total = totalGstRefunded;
      s.net_tax_amount = Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100);
      s.subtotal_refunded_total = totalSubtotalRefunded;
      s.net_subtotal = Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100);
      return s;
    } catch (e) {
      console.error(e);
    }
  }
  const list = readJson('sales');
  const s = list.find((item) => String(item.id) === String(id)) || null;
  if (!s) return null;
  const allRefundsFallback = readJson('refunds');
  s.refunds = allRefundsFallback.filter((rf) => String(rf.sale_id) === String(id));
  const totalRefunded = s.refunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
  const totalGstRefunded = s.refunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
  const totalSubtotalRefunded = s.refunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
  const origTax = Number(s.tax_amount) || 0;
  const origSubtotal = Number(s.subtotal) || 0;
  s.refunded_amount = Number(s.refunded_amount) || totalRefunded;
  s.refund_status = s.refund_status || (s.refunds.length > 0 ? (totalRefunded >= Number(s.total_amount) ? 'full' : 'partial') : 'none');
  s.gst_reversed_total = totalGstRefunded;
  s.net_tax_amount = Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100);
  s.subtotal_refunded_total = totalSubtotalRefunded;
  s.net_subtotal = Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100);
  return s;
}

async function createSale(data) {
  let resolvedStaffName = data.staff_name || '';
  if (!resolvedStaffName && data.staff_id) {
    try {
      const staffMember = await getStaffById(data.staff_id);
      if (staffMember) resolvedStaffName = staffMember.name || '';
    } catch (_) {}
  }

  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO sales
        (business_id, appointment_id, customer_id, customer_name, customer_phone, staff_id, staff_name,
         subtotal, item_discount_total, overall_discount, tax_amount, total_amount,
         payment_method, amount_tendered, change_amount, items, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      const [result] = await pool.query(query, [
        data.business_id || 1,
        data.appointment_id || null,
        data.customer_id || null,
        data.customer_name || '',
        data.customer_phone || '',
        data.staff_id || null,
        resolvedStaffName,
        data.subtotal || 0,
        data.item_discount_total || 0,
        data.overall_discount || 0,
        data.tax_amount || 0,
        data.total_amount || 0,
        data.payment_method || 'cash',
        data.amount_tendered || 0,
        data.change_amount || 0,
        JSON.stringify(data.items || []),
        data.notes || '',
      ]);
      return await getSaleById(result.insertId);
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('sales');
  const newId = list.length > 0 ? Math.max(...list.map((s) => s.id)) + 1 : 1;
  const sale = {
    id: newId,
    business_id: data.business_id || 1,
    appointment_id: data.appointment_id || null,
    customer_id: data.customer_id || null,
    customer_name: data.customer_name || '',
    customer_phone: data.customer_phone || '',
    staff_id: data.staff_id || null,
    staff_name: resolvedStaffName,
    subtotal: data.subtotal || 0,
    item_discount_total: data.item_discount_total || 0,
    overall_discount: data.overall_discount || 0,
    tax_amount: data.tax_amount || 0,
    total_amount: data.total_amount || 0,
    payment_method: data.payment_method || 'cash',
    amount_tendered: data.amount_tendered || 0,
    change_amount: data.change_amount || 0,
    items: data.items || [],
    notes: data.notes || '',
    created_at: new Date().toISOString(),
  };
  list.push(sale);
  writeJson('sales', list);
  return sale;
}

// =================== Refund Calculations & Operations ===================
function calculateRefundDetails(originalTransaction, refundItems, existingRefunds = []) {
  const prevRefundedMap = {};
  let totalPrevRefundAmount = 0;
  for (const ref of existingRefunds) {
    totalPrevRefundAmount += Number(ref.total_refund_amount) || 0;
    if (Array.isArray(ref.items)) {
      for (const it of ref.items) {
        const key = String(it.product_id || it.product_name);
        prevRefundedMap[key] = (prevRefundedMap[key] || 0) + (Number(it.quantity) || 0);
      }
    }
  }

  const origItems = originalTransaction.items || originalTransaction.services || [];
  const origSubtotal = Number(originalTransaction.subtotal) ||
    origItems.reduce((acc, it) => acc + (Number(it.unit_price !== undefined ? it.unit_price : it.price) || 0) * (Number(it.quantity) || 1), 0);
  const origItemDiscount = Number(originalTransaction.item_discount_total) || 0;
  const origOverallDiscount = Number(originalTransaction.overall_discount) || 0;
  const origTaxAmount = Number(originalTransaction.tax_amount) || 0;
  const origTotalAmount = Number(originalTransaction.total_amount) || 0;

  const netItemsTotal = Math.max(0, origSubtotal - origItemDiscount);
  const overallDiscountRatio = netItemsTotal > 0 ? (origOverallDiscount / netItemsTotal) : 0;
  const origTaxable = Math.max(0, netItemsTotal - origOverallDiscount);
  const taxRate = origTaxable > 0 ? (origTaxAmount / origTaxable) : (origTaxAmount > 0 ? 0.08 : 0);

  let subtotalRefunded = 0;
  let lineDiscountReversedTotal = 0;
  const processedRefundItems = [];

  for (const reqItem of refundItems) {
    const qtyToRefund = Number(reqItem.quantity) || 0;
    if (qtyToRefund <= 0) continue;

    const orig = origItems.find((it) =>
      (reqItem.product_id && (it.product_id === reqItem.product_id || it.id === reqItem.product_id)) ||
      (it.product_name && (it.product_name === reqItem.product_name || it.product_name === reqItem.name)) ||
      (it.name && (it.name === reqItem.product_name || it.name === reqItem.name))
    );

    if (!orig) {
      throw new Error(`Item "${reqItem.product_name || reqItem.product_id}" not found in original transaction.`);
    }

    const origQty = Number(orig.quantity) || 1;
    const unitPrice = Number(orig.unit_price !== undefined ? orig.unit_price : orig.price) || 0;
    const origLineDiscount = Number(orig.discount) || 0;
    const key = String(orig.product_id || orig.id || orig.product_name || orig.name);
    const prevQty = prevRefundedMap[key] || 0;
    const maxRefundable = origQty - prevQty;

    if (qtyToRefund > maxRefundable) {
      throw new Error(`Cannot refund ${qtyToRefund} × "${orig.product_name || orig.name}". Only ${maxRefundable} remaining.`);
    }

    const itemBaseGross = qtyToRefund * unitPrice;
    const unitLineDiscount = origQty > 0 ? (origLineDiscount / origQty) : 0;
    const itemLineDiscountReversal = qtyToRefund * unitLineDiscount;
    const itemNetBeforeOverall = Math.max(0, itemBaseGross - itemLineDiscountReversal);

    const itemOverallDiscountReversal = itemNetBeforeOverall * overallDiscountRatio;
    const itemTaxable = Math.max(0, itemNetBeforeOverall - itemOverallDiscountReversal);
    const itemGstReversal = Math.round((itemTaxable * taxRate) * 100) / 100;
    const itemRefundTotal = Math.round((itemTaxable + itemGstReversal) * 100) / 100;

    subtotalRefunded += itemBaseGross;
    lineDiscountReversedTotal += itemLineDiscountReversal;

    processedRefundItems.push({
      product_id: orig.product_id || orig.id || null,
      product_name: orig.product_name || orig.name || 'Item',
      unit_price: unitPrice,
      quantity: qtyToRefund,
      original_quantity: origQty,
      previously_refunded: prevQty,
      remaining_quantity: origQty - prevQty - qtyToRefund,
      line_discount_reversed: Math.round(itemLineDiscountReversal * 100) / 100,
      overall_discount_reversed: Math.round(itemOverallDiscountReversal * 100) / 100,
      total_discount_reversed: Math.round((itemLineDiscountReversal + itemOverallDiscountReversal) * 100) / 100,
      gst_reversed: itemGstReversal,
      refund_amount: itemRefundTotal,
    });
  }

  if (processedRefundItems.length === 0) {
    throw new Error('Please select at least one item and quantity to refund.');
  }

  const selectedNetLineSum = Math.max(0, subtotalRefunded - lineDiscountReversedTotal);
  const overallDiscountReversedTotal = selectedNetLineSum * overallDiscountRatio;
  const totalDiscountReversed = Math.round((lineDiscountReversedTotal + overallDiscountReversedTotal) * 100) / 100;
  const taxableRefund = Math.max(0, selectedNetLineSum - overallDiscountReversedTotal);
  const gstReversedTotal = Math.round((taxableRefund * taxRate) * 100) / 100;
  let totalRefundAmount = Math.round((taxableRefund + gstReversedTotal) * 100) / 100;

  // Determine if this results in full refund of all items
  let isAllItemsFullyRefunded = true;
  for (const orig of origItems) {
    const origQty = Number(orig.quantity) || 1;
    const key = String(orig.product_id || orig.id || orig.product_name || orig.name);
    const prevQty = prevRefundedMap[key] || 0;
    const currentRefItem = processedRefundItems.find((p) => String(p.product_id || p.product_name) === key);
    const thisRefQty = currentRefItem ? currentRefItem.quantity : 0;
    if (prevQty + thisRefQty < origQty) {
      isAllItemsFullyRefunded = false;
      break;
    }
  }

  // Exact matching for full refund to eliminate 1-cent drift
  if (isAllItemsFullyRefunded) {
    const remainingPaidBalance = Math.round((origTotalAmount - totalPrevRefundAmount) * 100) / 100;
    if (remainingPaidBalance > 0) {
      totalRefundAmount = remainingPaidBalance;
    }
  }

  // Strict boundary cap
  if (totalPrevRefundAmount + totalRefundAmount > origTotalAmount + 0.01) {
    totalRefundAmount = Math.max(0, Math.round((origTotalAmount - totalPrevRefundAmount) * 100) / 100);
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

async function getSaleRefunds(saleId) {
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT * FROM refunds WHERE sale_id = ? ORDER BY created_at ASC', [saleId]);
      return rows.map((r) => {
        if (r.items && typeof r.items === 'string') {
          try { r.items = JSON.parse(r.items); } catch (_) { r.items = []; }
        }
        return r;
      });
    } catch (e) {
      console.error(e);
    }
  }
  const allRefunds = readJson('refunds');
  return allRefunds.filter((r) => String(r.sale_id) === String(saleId));
}

async function getAppointmentRefunds(appointmentId) {
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT * FROM refunds WHERE appointment_id = ? ORDER BY created_at ASC', [appointmentId]);
      return rows.map((r) => {
        if (r.items && typeof r.items === 'string') {
          try { r.items = JSON.parse(r.items); } catch (_) { r.items = []; }
        }
        return r;
      });
    } catch (e) {
      console.error(e);
    }
  }
  const allRefunds = readJson('refunds');
  return allRefunds.filter((r) => String(r.appointment_id) === String(appointmentId));
}

async function createSaleRefund({ sale_id, items, reason, notes, refund_method }) {
  const sale = await getSaleById(sale_id);
  if (!sale) {
    throw new Error('Sale not found.');
  }

  const existingRefunds = await getSaleRefunds(sale_id);
  const calc = calculateRefundDetails(sale, items, existingRefunds);

  const now = new Date();
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const randomSuffix = Math.floor(1000 + Math.random() * 9000);
  const refundReceiptNumber = `#REF-${yyyy}${mm}${dd}-${sale.id}-${randomSuffix}`;

  const prevRefunded = existingRefunds.reduce((sum, rf) => sum + (Number(rf.total_refund_amount) || 0), 0);
  const newRefundedAmount = Math.round((prevRefunded + calc.total_refund_amount) * 100) / 100;
  const newStatus = calc.is_fully_refunded ? 'full' : 'partial';

  let refundRecord;

  if (!useFallback && pool) {
    try {
      const insertSql = `
        INSERT INTO refunds
        (refund_receipt_number, business_id, sale_id, appointment_id, refund_type,
         subtotal_refunded, discount_reversed_total, gst_reversed_total, total_refund_amount,
         refund_method, reason, notes, items)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      const [res] = await pool.query(insertSql, [
        refundReceiptNumber,
        sale.business_id || 1,
        sale.id,
        sale.appointment_id || null,
        calc.refund_type,
        calc.subtotal_refunded,
        calc.discount_reversed_total,
        calc.gst_reversed_total,
        calc.total_refund_amount,
        refund_method || sale.payment_method || 'cash',
        reason || '',
        notes || '',
        JSON.stringify(calc.items),
      ]);

      await pool.query(
        'UPDATE sales SET refund_status = ?, refunded_amount = ? WHERE id = ?',
        [newStatus, newRefundedAmount, sale.id]
      );

      if (sale.appointment_id) {
        await pool.query(
          'UPDATE appointments SET refund_status = ?, refunded_amount = ? WHERE id = ?',
          [newStatus, newRefundedAmount, sale.appointment_id]
        );
      }

      refundRecord = {
        id: res.insertId,
        refund_receipt_number: refundReceiptNumber,
        business_id: sale.business_id || 1,
        sale_id: sale.id,
        appointment_id: sale.appointment_id || null,
        refund_type: calc.refund_type,
        subtotal_refunded: calc.subtotal_refunded,
        discount_reversed_total: calc.discount_reversed_total,
        gst_reversed_total: calc.gst_reversed_total,
        total_refund_amount: calc.total_refund_amount,
        refund_method: refund_method || sale.payment_method || 'cash',
        reason: reason || '',
        notes: notes || '',
        items: calc.items,
        created_at: now.toISOString(),
      };
    } catch (e) {
      console.error('Error inserting refund in MySQL:', e);
      throw e;
    }
  } else {
    const refundsList = readJson('refunds');
    const newId = refundsList.length > 0 ? Math.max(...refundsList.map((r) => r.id)) + 1 : 1;
    refundRecord = {
      id: newId,
      refund_receipt_number: refundReceiptNumber,
      business_id: sale.business_id || 1,
      sale_id: sale.id,
      appointment_id: sale.appointment_id || null,
      refund_type: calc.refund_type,
      subtotal_refunded: calc.subtotal_refunded,
      discount_reversed_total: calc.discount_reversed_total,
      gst_reversed_total: calc.gst_reversed_total,
      total_refund_amount: calc.total_refund_amount,
      refund_method: refund_method || sale.payment_method || 'cash',
      reason: reason || '',
      notes: notes || '',
      items: calc.items,
      created_at: now.toISOString(),
    };
    refundsList.push(refundRecord);
    writeJson('refunds', refundsList);

    const salesList = readJson('sales');
    const sIdx = salesList.findIndex((s) => String(s.id) === String(sale.id));
    if (sIdx !== -1) {
      salesList[sIdx].refund_status = newStatus;
      salesList[sIdx].refunded_amount = newRefundedAmount;
      writeJson('sales', salesList);
    }

    if (sale.appointment_id) {
      const aptList = readJson('appointments');
      const aIdx = aptList.findIndex((a) => String(a.id) === String(sale.appointment_id));
      if (aIdx !== -1) {
        aptList[aIdx].refund_status = newStatus;
        aptList[aIdx].refunded_amount = newRefundedAmount;
        writeJson('appointments', aptList);
      }
    }
  }

  const updatedSale = await getSaleById(sale.id);
  return { refund: refundRecord, sale: updatedSale };
}

async function createAppointmentRefund({ appointment_id, items, reason, notes, refund_method }) {
  const appt = await getAppointmentById(appointment_id);
  if (!appt) {
    throw new Error('Appointment not found.');
  }

  // Check if linked to an existing sale record in sales
  let linkedSale = null;
  if (!useFallback && pool) {
    try {
      const [salesRows] = await pool.query('SELECT * FROM sales WHERE appointment_id = ? ORDER BY id DESC LIMIT 1', [appointment_id]);
      if (salesRows.length > 0) linkedSale = salesRows[0];
    } catch (_) {}
  } else {
    const salesList = readJson('sales');
    linkedSale = salesList.find((s) => String(s.appointment_id) === String(appointment_id)) || null;
  }

  if (linkedSale) {
    // Process refund through the linked sale record
    const result = await createSaleRefund({
      sale_id: linkedSale.id,
      items,
      reason,
      notes,
      refund_method,
    });
    const updatedAppt = await getAppointmentById(appointment_id);
    return { refund: result.refund, appointment: updatedAppt, sale: result.sale };
  }

  // Standalone appointment refund (e.g. completed directly without cart POS)
  const existingRefunds = await getAppointmentRefunds(appointment_id);
  const calc = calculateRefundDetails(appt, items, existingRefunds);

  const now = new Date();
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const randomSuffix = Math.floor(1000 + Math.random() * 9000);
  const refundReceiptNumber = `#REF-${yyyy}${mm}${dd}-APT${appt.id}-${randomSuffix}`;

  const prevRefunded = existingRefunds.reduce((sum, rf) => sum + (Number(rf.total_refund_amount) || 0), 0);
  const newRefundedAmount = Math.round((prevRefunded + calc.total_refund_amount) * 100) / 100;
  const newStatus = calc.is_fully_refunded ? 'full' : 'partial';

  let refundRecord;

  if (!useFallback && pool) {
    try {
      const insertSql = `
        INSERT INTO refunds
        (refund_receipt_number, business_id, sale_id, appointment_id, refund_type,
         subtotal_refunded, discount_reversed_total, gst_reversed_total, total_refund_amount,
         refund_method, reason, notes, items)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      const [res] = await pool.query(insertSql, [
        refundReceiptNumber,
        appt.business_id || 1,
        null,
        appt.id,
        calc.refund_type,
        calc.subtotal_refunded,
        calc.discount_reversed_total,
        calc.gst_reversed_total,
        calc.total_refund_amount,
        refund_method || 'cash',
        reason || '',
        notes || '',
        JSON.stringify(calc.items),
      ]);

      await pool.query(
        'UPDATE appointments SET refund_status = ?, refunded_amount = ? WHERE id = ?',
        [newStatus, newRefundedAmount, appt.id]
      );

      refundRecord = {
        id: res.insertId,
        refund_receipt_number: refundReceiptNumber,
        business_id: appt.business_id || 1,
        sale_id: null,
        appointment_id: appt.id,
        refund_type: calc.refund_type,
        subtotal_refunded: calc.subtotal_refunded,
        discount_reversed_total: calc.discount_reversed_total,
        gst_reversed_total: calc.gst_reversed_total,
        total_refund_amount: calc.total_refund_amount,
        refund_method: refund_method || 'cash',
        reason: reason || '',
        notes: notes || '',
        items: calc.items,
        created_at: now.toISOString(),
      };
    } catch (e) {
      console.error('Error inserting appointment refund in MySQL:', e);
      throw e;
    }
  } else {
    const refundsList = readJson('refunds');
    const newId = refundsList.length > 0 ? Math.max(...refundsList.map((r) => r.id)) + 1 : 1;
    refundRecord = {
      id: newId,
      refund_receipt_number: refundReceiptNumber,
      business_id: appt.business_id || 1,
      sale_id: null,
      appointment_id: appt.id,
      refund_type: calc.refund_type,
      subtotal_refunded: calc.subtotal_refunded,
      discount_reversed_total: calc.discount_reversed_total,
      gst_reversed_total: calc.gst_reversed_total,
      total_refund_amount: calc.total_refund_amount,
      refund_method: refund_method || 'cash',
      reason: reason || '',
      notes: notes || '',
      items: calc.items,
      created_at: now.toISOString(),
    };
    refundsList.push(refundRecord);
    writeJson('refunds', refundsList);

    const aptList = readJson('appointments');
    const aIdx = aptList.findIndex((a) => String(a.id) === String(appt.id));
    if (aIdx !== -1) {
      aptList[aIdx].refund_status = newStatus;
      aptList[aIdx].refunded_amount = newRefundedAmount;
      writeJson('appointments', aptList);
    }
  }

  const updatedAppt = await getAppointmentById(appt.id);
  return { refund: refundRecord, appointment: updatedAppt };
}

// =================== Appointment Conflict Check ===================
async function checkAppointmentConflict({ staff_id, appointment_date, start_time, end_time, exclude_id }) {
  // Parse times to minutes
  function timeToMinutes(t) {
    const parts = (t || '').split(':');
    return (parseInt(parts[0], 10) || 0) * 60 + (parseInt(parts[1], 10) || 0);
  }
  const newStart = timeToMinutes(start_time);
  const newEnd = timeToMinutes(end_time);

  // Get all appointments for this staff on this date
  const allAppointments = await getAppointments(appointment_date, staff_id);

  // Filter to only active (blocking) statuses — cancelled and no_show are FREE
  const blocking = allAppointments.filter((a) => {
    if (exclude_id && String(a.id) === String(exclude_id)) return false;
    return ['booked', 'in_service', 'completed'].includes(a.status);
  });

  // Check for overlap
  for (const a of blocking) {
    const aStart = timeToMinutes(a.start_time);
    const aEnd = timeToMinutes(a.end_time);
    // Overlap check: two intervals [s1, e1) and [s2, e2) overlap when s1 < e2 && s2 < e1
    if (newStart < aEnd && aStart < newEnd) {
      return { has_conflict: true, conflicting_appointment: a };
    }
  }
  return { has_conflict: false };
}

function getDatabaseStatus() {
  return {
    mode: useFallback ? 'JSON_FALLBACK' : 'MYSQL',
    connected: !useFallback && pool !== null,
    database: process.env.DB_NAME || 'appointment_hotel_booking',
  };
}

// =================== Settings Helpers ===================
function formatSettingsOutput(row) {
  if (!row) return null;
  const timeFormat = String(row.time_format || '12');
  const clockDisplay = String(row.clock_display || (timeFormat === '24' ? '24h' : '12h'));
  const slotInterval = parseInt(row.booking_slot_interval ?? row.slot_duration ?? 30, 10);
  const bufferTime = parseInt(row.buffer_time_between_sessions ?? row.buffer_time ?? 10, 10);
  const openTime = row.open_time || '08:00';
  const closeTime = row.close_time || '20:00';
  const allowWalkIn = row.allow_walk_in_queue !== false && row.allow_walk_in_queue !== 0;
  const requireNotes = row.require_doctor_notes !== false && row.require_doctor_notes !== 0;
  const allowDelete = row.allow_delete_service === true || row.allow_delete_service === 1;
  const appointmentV2Clock = row.appointment_v2_clock !== false && row.appointment_v2_clock !== 0 && row.appointment_v2_clock !== '0';

  return {
    id: row.id || 1,
    business_id: row.business_id || 1,
    time_format: timeFormat,
    clock_display: clockDisplay,
    booking_slot_interval: slotInterval,
    slot_duration: slotInterval,
    buffer_time_between_sessions: bufferTime,
    buffer_time: bufferTime,
    open_time: openTime,
    close_time: closeTime,
    operating_business_hours: {
      open_time: openTime,
      close_time: closeTime,
    },
    allow_walk_in_queue: allowWalkIn,
    require_doctor_notes: requireNotes,
    allow_delete_service: allowDelete,
    appointment_v2_clock: appointmentV2Clock,
    printer_settings: row.printer_settings
      ? (typeof row.printer_settings === 'string'
          ? (() => { try { return JSON.parse(row.printer_settings); } catch { return row.printer_settings; } })()
          : row.printer_settings)
      : null,
    created_at: row.created_at || new Date().toISOString(),
    updated_at: row.updated_at || new Date().toISOString(),
  };
}

async function getSettings(businessId = 1) {
  const bId = parseInt(businessId, 10) || 1;
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT * FROM settings WHERE business_id = ?', [bId]);
      if (rows && rows.length > 0) {
        return formatSettingsOutput(rows[0]);
      }
      // Insert default if not present
      await pool.query(
        `INSERT INTO settings (business_id, time_format, clock_display, booking_slot_interval, buffer_time_between_sessions, open_time, close_time, allow_walk_in_queue, require_doctor_notes, allow_delete_service, appointment_v2_clock)
         VALUES (?, '12', '12h', 30, 10, '08:00', '20:00', TRUE, TRUE, FALSE, TRUE)`,
        [bId]
      );
      const [newRows] = await pool.query('SELECT * FROM settings WHERE business_id = ?', [bId]);
      return formatSettingsOutput(newRows[0]);
    } catch (e) {
      console.error('Error fetching settings from MySQL:', e);
    }
  }

  const list = readJson('settings');
  let item = list.find((s) => Number(s.business_id) === bId);
  if (!item) {
    item = {
      id: list.length > 0 ? Math.max(...list.map((s) => s.id || 0)) + 1 : 1,
      business_id: bId,
      time_format: '12',
      clock_display: '12h',
      booking_slot_interval: 30,
      buffer_time_between_sessions: 10,
      open_time: '08:00',
      close_time: '20:00',
      allow_walk_in_queue: true,
      require_doctor_notes: true,
      allow_delete_service: false,
      appointment_v2_clock: true,
      printer_settings: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    list.push(item);
    writeJson('settings', list);
  }
  return formatSettingsOutput(item);
}

async function updateSettings(businessId = 1, data = {}) {
  const bId = parseInt(businessId, 10) || 1;
  const timeFormat = data.time_format !== undefined ? String(data.time_format) : undefined;
  const clockDisplay = data.clock_display !== undefined ? String(data.clock_display) : (timeFormat ? (timeFormat === '24' ? '24h' : '12h') : undefined);
  const slotInterval = data.booking_slot_interval !== undefined ? parseInt(data.booking_slot_interval, 10) : (data.slot_duration !== undefined ? parseInt(data.slot_duration, 10) : (data.slotDuration !== undefined ? parseInt(data.slotDuration, 10) : undefined));
  const bufferTime = data.buffer_time_between_sessions !== undefined ? parseInt(data.buffer_time_between_sessions, 10) : (data.buffer_time !== undefined ? parseInt(data.buffer_time, 10) : (data.bufferTime !== undefined ? parseInt(data.bufferTime, 10) : undefined));
  const openTime = data.open_time !== undefined ? String(data.open_time).trim() : (data.openTime !== undefined ? String(data.openTime).trim() : (data.operating_business_hours?.open_time ? String(data.operating_business_hours.open_time).trim() : undefined));
  const closeTime = data.close_time !== undefined ? String(data.close_time).trim() : (data.closeTime !== undefined ? String(data.closeTime).trim() : (data.operating_business_hours?.close_time ? String(data.operating_business_hours.close_time).trim() : undefined));
  const allowWalkIn = data.allow_walk_in_queue !== undefined ? Boolean(data.allow_walk_in_queue) : (data.allowWalkInQueue !== undefined ? Boolean(data.allowWalkInQueue) : undefined);
  const requireNotes = data.require_doctor_notes !== undefined ? Boolean(data.require_doctor_notes) : (data.requireDoctorNotes !== undefined ? Boolean(data.requireDoctorNotes) : undefined);
  const allowDelete = data.allow_delete_service !== undefined ? Boolean(data.allow_delete_service) : (data.allowDeleteService !== undefined ? Boolean(data.allowDeleteService) : undefined);
  const appointmentV2Clock = data.appointment_v2_clock !== undefined ? Boolean(data.appointment_v2_clock) : (data.appointmentV2Clock !== undefined ? Boolean(data.appointmentV2Clock) : undefined);
  const printerSettings = data.printer_settings !== undefined ? data.printer_settings : undefined;

  if (!useFallback && pool) {
    try {
      // Ensure record exists
      await getSettings(bId);

      const fields = [];
      const values = [];
      if (timeFormat !== undefined) { fields.push('time_format = ?'); values.push(timeFormat); }
      if (clockDisplay !== undefined) { fields.push('clock_display = ?'); values.push(clockDisplay); }
      if (slotInterval !== undefined) { fields.push('booking_slot_interval = ?'); values.push(slotInterval); }
      if (bufferTime !== undefined) { fields.push('buffer_time_between_sessions = ?'); values.push(bufferTime); }
      if (openTime !== undefined) { fields.push('open_time = ?'); values.push(openTime); }
      if (closeTime !== undefined) { fields.push('close_time = ?'); values.push(closeTime); }
      if (allowWalkIn !== undefined) { fields.push('allow_walk_in_queue = ?'); values.push(allowWalkIn); }
      if (requireNotes !== undefined) { fields.push('require_doctor_notes = ?'); values.push(requireNotes); }
      if (allowDelete !== undefined) { fields.push('allow_delete_service = ?'); values.push(allowDelete); }
      if (appointmentV2Clock !== undefined) { fields.push('appointment_v2_clock = ?'); values.push(appointmentV2Clock); }
      if (printerSettings !== undefined) {
        fields.push('printer_settings = ?');
        values.push(typeof printerSettings === 'object' && printerSettings !== null ? JSON.stringify(printerSettings) : printerSettings);
      }

      if (fields.length > 0) {
        values.push(bId);
        await pool.query(`UPDATE settings SET ${fields.join(', ')} WHERE business_id = ?`, values);
      }
      return await getSettings(bId);
    } catch (e) {
      console.error('Error updating settings in MySQL:', e);
    }
  }

  const list = readJson('settings');
  let idx = list.findIndex((s) => Number(s.business_id) === bId);
  if (idx === -1) {
    list.push({
      id: list.length > 0 ? Math.max(...list.map((s) => s.id || 0)) + 1 : 1,
      business_id: bId,
      time_format: '12',
      clock_display: '12h',
      booking_slot_interval: 30,
      buffer_time_between_sessions: 10,
      open_time: '08:00',
      close_time: '20:00',
      allow_walk_in_queue: true,
      require_doctor_notes: true,
      allow_delete_service: false,
      appointment_v2_clock: true,
      printer_settings: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    idx = list.length - 1;
  }

  const current = list[idx];
  list[idx] = {
    ...current,
    time_format: timeFormat !== undefined ? timeFormat : current.time_format,
    clock_display: clockDisplay !== undefined ? clockDisplay : current.clock_display,
    booking_slot_interval: slotInterval !== undefined ? slotInterval : current.booking_slot_interval,
    buffer_time_between_sessions: bufferTime !== undefined ? bufferTime : current.buffer_time_between_sessions,
    open_time: openTime !== undefined ? openTime : current.open_time,
    close_time: closeTime !== undefined ? closeTime : current.close_time,
    allow_walk_in_queue: allowWalkIn !== undefined ? allowWalkIn : current.allow_walk_in_queue,
    require_doctor_notes: requireNotes !== undefined ? requireNotes : current.require_doctor_notes,
    allow_delete_service: allowDelete !== undefined ? allowDelete : current.allow_delete_service,
    appointment_v2_clock: appointmentV2Clock !== undefined ? appointmentV2Clock : (current.appointment_v2_clock !== undefined ? current.appointment_v2_clock : true),
    printer_settings: printerSettings !== undefined
      ? (typeof printerSettings === 'string'
          ? (() => { try { return JSON.parse(printerSettings); } catch { return printerSettings; } })()
          : printerSettings)
      : current.printer_settings,
    updated_at: new Date().toISOString(),
  };
  writeJson('settings', list);
  return formatSettingsOutput(list[idx]);
}

module.exports = {
  initDatabase,
  getDatabaseStatus,
  findBusinessByEmail,
  findBusinessById,
  createBusiness,
  getStaffList,
  getStaffById,
  createStaff,
  updateStaff,
  deleteStaff,
  getCustomers,
  createCustomer,
  getCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  getProducts,
  getPaginatedProducts,
  createProduct,
  updateProduct,
  deleteProduct,
  getAppointments,
  getAppointmentById,
  getAppointmentStats,
  createAppointment,
  updateAppointmentStatus,
  updateAppointment,
  deleteAppointment,
  getSales,
  getSaleById,
  createSale,
  calculateRefundDetails,
  getSaleRefunds,
  getAppointmentRefunds,
  createSaleRefund,
  createAppointmentRefund,
  checkAppointmentConflict,
  getSettings,
  updateSettings,
};
