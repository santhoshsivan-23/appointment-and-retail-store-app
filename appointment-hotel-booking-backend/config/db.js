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
      await pool.query('ALTER TABLE staff ADD COLUMN image LONGTEXT NULL');
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
        'SELECT * FROM categories WHERE (business_id = ? OR business_id = 1) AND is_active = TRUE ORDER BY sort_order ASC, id ASC',
        [businessId || 1]
      );
      return rows;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('categories');
  return list.filter((c) => c.is_active !== false).sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
}

async function createCategory(data) {
  const showInAppointment = data.show_in_appointment !== false && data.show_in_appointment !== 'false';
  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO categories (business_id, name, description, icon, sort_order, show_in_appointment, is_active)
        VALUES (?, ?, ?, ?, ?, ?, TRUE)
      `;
      const [res] = await pool.query(query, [
        data.business_id || 1,
        data.name.trim(),
        data.description || '',
        data.icon || 'category',
        data.sort_order || 0,
        showInAppointment,
      ]);
      return { id: res.insertId, ...data, show_in_appointment: showInAppointment, is_active: true, created_at: new Date().toISOString() };
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
      await pool.query('UPDATE categories SET is_active = FALSE WHERE id = ?', [id]);
      return true;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('categories');
  const idx = list.findIndex((c) => String(c.id) === String(id));
  if (idx === -1) return false;
  list[idx].is_active = false;
  writeJson('categories', list);
  return true;
}

// ----------------- Products Helpers -----------------
async function getProducts(businessId, categoryId = null, productType = null, search = '') {
  const s = (search || '').trim().toLowerCase();
  if (!useFallback && pool) {
    try {
      let query = 'SELECT * FROM products WHERE (business_id = ? OR business_id = 1) AND is_active = TRUE';
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
  list = list.filter((p) => p.is_active !== false);
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

async function createProduct(data) {
  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO products 
        (business_id, category_id, name, sku, product_type, price, description, modifiers, combo_items, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, TRUE)
      `;
      const [res] = await pool.query(query, [
        data.business_id || 1,
        data.category_id || null,
        data.name.trim(),
        data.sku || '',
        data.product_type || 'normal',
        Number(data.price) || 0.0,
        data.description || '',
        JSON.stringify(data.modifiers || []),
        JSON.stringify(data.combo_items || []),
      ]);
      return { id: res.insertId, ...data, is_active: true, created_at: new Date().toISOString() };
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
      await pool.query(
        `UPDATE products 
         SET category_id = ?, name = ?, sku = ?, product_type = ?, price = ?, description = ?, modifiers = ?, combo_items = ?
         WHERE id = ?`,
        [
          data.category_id || null,
          data.name,
          data.sku,
          data.product_type,
          data.price,
          data.description,
          JSON.stringify(data.modifiers || []),
          JSON.stringify(data.combo_items || []),
          id,
        ]
      );
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
      await pool.query('UPDATE products SET is_active = FALSE, deleted_at = NOW() WHERE id = ?', [id]);
      return true;
    } catch (e) {
      console.error(e);
    }
  }

  const list = readJson('products');
  const idx = list.findIndex((p) => String(p.id) === String(id));
  if (idx === -1) return false;
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
      return rows.map((r) => {
        if (r.services && typeof r.services === 'string') {
          try { r.services = JSON.parse(r.services); } catch (_) { r.services = []; }
        }
        return r;
      });
    } catch (e) {
      console.error(e);
    }
  }

  let list = readJson('appointments');
  const staffList = readJson('staff');
  const staffMap = {};
  staffList.forEach((st) => { staffMap[String(st.id)] = st.name; });

  list = list.map((a) => ({
    ...a,
    staff_name: a.staff_name || staffMap[String(a.staff_id)] || '',
  }));

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
      if (rows[0] && rows[0].services && typeof rows[0].services === 'string') {
        try { rows[0].services = JSON.parse(rows[0].services); } catch (_) { rows[0].services = []; }
      }
      return rows[0] || null;
    } catch (e) {
      console.error(e);
    }
  }
  const list = readJson('appointments');
  return list.find((a) => String(a.id) === String(id)) || null;
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
  let list = readJson('sales');
  const staffList = readJson('staff');
  const staffMap = {};
  staffList.forEach((st) => { staffMap[String(st.id)] = st.name; });

  list = list.map((s) => ({
    ...s,
    staff_name: s.staff_name || staffMap[String(s.staff_id)] || '',
  }));

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
      if (rows[0] && rows[0].items && typeof rows[0].items === 'string') {
        rows[0].items = JSON.parse(rows[0].items);
      }
      return rows[0] || null;
    } catch (e) {
      console.error(e);
    }
  }
  const list = readJson('sales');
  return list.find((s) => String(s.id) === String(id)) || null;
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
  checkAppointmentConflict,
};
