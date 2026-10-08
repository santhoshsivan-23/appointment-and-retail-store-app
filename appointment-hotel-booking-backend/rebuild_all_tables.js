const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

async function rebuild() {
  console.log('Connecting to MySQL...');
  const conn = await mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: '',
    database: 'appointment_hotel_booking'
  });

  console.log('Fetching existing tables...');
  const [existing] = await conn.query('SHOW TABLES');
  for (const row of existing) {
    const t = Object.values(row)[0];
    try {
      console.log(`Dropping table ${t}...`);
      await conn.query(`DROP TABLE IF EXISTS \`${t}\``);
    } catch (e) {
      console.warn(`Could not drop table ${t}: ${e.message}`);
    }
  }

  // Remove any remaining .frm or .ibd files in data dir if any exist
  const dataDir = 'C:\\xampp\\mysql\\data\\appointment_hotel_booking';
  if (fs.existsSync(dataDir)) {
    const files = fs.readdirSync(dataDir);
    for (const f of files) {
      if (f.endsWith('.frm') || f.endsWith('.ibd')) {
        try {
          fs.unlinkSync(path.join(dataDir, f));
          console.log(`Removed orphaned file: ${f}`);
        } catch (e) {
          console.warn(`Could not remove ${f}: ${e.message}`);
        }
      }
    }
  }

  console.log('Creating fresh tables with current engine LSN...');

  const schemas = [
    `CREATE TABLE businesses (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

    `CREATE TABLE staff (
      id INT AUTO_INCREMENT PRIMARY KEY,
      business_id INT NOT NULL,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255),
      phone VARCHAR(50),
      role VARCHAR(100) DEFAULT 'Staff',
      color_code VARCHAR(50) DEFAULT '#B42907',
      is_active BOOLEAN DEFAULT TRUE,
      deleted_at DATETIME NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

    `CREATE TABLE customers (
      id INT AUTO_INCREMENT PRIMARY KEY,
      business_id INT NOT NULL,
      name VARCHAR(255) NOT NULL,
      phone VARCHAR(50) NOT NULL,
      email VARCHAR(255) DEFAULT '',
      is_walk_in BOOLEAN DEFAULT FALSE,
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

    `CREATE TABLE categories (
      id INT AUTO_INCREMENT PRIMARY KEY,
      business_id INT NOT NULL,
      name VARCHAR(255) NOT NULL,
      description TEXT,
      icon VARCHAR(100) DEFAULT 'category',
      sort_order INT DEFAULT 0,
      is_active BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

    `CREATE TABLE products (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

    `CREATE TABLE appointments (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

    `CREATE TABLE sales (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

    `CREATE TABLE settings (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
  ];

  for (const s of schemas) {
    await conn.query(s);
  }
  console.log('All 8 tables created successfully in InnoDB!');

  // Seed Data from backend/data/*.json
  const dataPath = path.join(__dirname, 'data');

  // 1. Businesses
  if (fs.existsSync(path.join(dataPath, 'businesses.json'))) {
    const list = JSON.parse(fs.readFileSync(path.join(dataPath, 'businesses.json'), 'utf8'));
    for (const b of list) {
      await conn.query(`
        INSERT INTO businesses (id, business_name, business_type, owner_name, email, phone, password, address, city, country, description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [b.id, b.business_name, b.business_type, b.owner_name, b.email, b.phone, b.password, b.address || '', b.city || '', b.country || '', b.description || '']);
    }
    console.log(`Seeded ${list.length} businesses.`);
  }

  // 2. Staff
  if (fs.existsSync(path.join(dataPath, 'staff.json'))) {
    const list = JSON.parse(fs.readFileSync(path.join(dataPath, 'staff.json'), 'utf8'));
    for (const s of list) {
      await conn.query(`
        INSERT INTO staff (id, business_id, name, email, phone, role, color_code, is_active, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [s.id, s.business_id, s.name, s.email, s.phone, s.role, s.color_code, s.is_active ? 1 : 0, s.deleted_at || null]);
    }
    console.log(`Seeded ${list.length} staff.`);
  }

  // 3. Customers
  if (fs.existsSync(path.join(dataPath, 'customers.json'))) {
    const list = JSON.parse(fs.readFileSync(path.join(dataPath, 'customers.json'), 'utf8'));
    for (const c of list) {
      await conn.query(`
        INSERT INTO customers (id, business_id, name, phone, email, is_walk_in, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `, [c.id, c.business_id, c.name, c.phone, c.email || '', c.is_walk_in ? 1 : 0, c.notes || '']);
    }
    console.log(`Seeded ${list.length} customers.`);
  }

  // 4. Categories
  if (fs.existsSync(path.join(dataPath, 'categories.json'))) {
    const list = JSON.parse(fs.readFileSync(path.join(dataPath, 'categories.json'), 'utf8'));
    for (const cat of list) {
      await conn.query(`
        INSERT INTO categories (id, business_id, name, description, icon, sort_order, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `, [cat.id, cat.business_id, cat.name, cat.description || '', cat.icon || 'category', cat.sort_order || 0, cat.is_active ? 1 : 0]);
    }
    console.log(`Seeded ${list.length} categories.`);
  }

  // 5. Products
  if (fs.existsSync(path.join(dataPath, 'products.json'))) {
    const list = JSON.parse(fs.readFileSync(path.join(dataPath, 'products.json'), 'utf8'));
    for (const p of list) {
      await conn.query(`
        INSERT INTO products (id, business_id, category_id, name, sku, product_type, price, description, modifiers, combo_items, is_active, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        p.id, p.business_id, p.category_id, p.name, p.sku || '', p.product_type || 'normal',
        p.price || 0, p.description || '',
        JSON.stringify(p.modifiers || []),
        JSON.stringify(p.combo_items || []),
        p.is_active ? 1 : 0,
        p.deleted_at || null
      ]);
    }
    console.log(`Seeded ${list.length} products.`);
  }

  // 6. Appointments
  if (fs.existsSync(path.join(dataPath, 'appointments.json'))) {
    const list = JSON.parse(fs.readFileSync(path.join(dataPath, 'appointments.json'), 'utf8'));
    for (const a of list) {
      await conn.query(`
        INSERT INTO appointments (id, business_id, staff_id, customer_id, customer_name, customer_phone, staff_name, appointment_date, start_time, end_time, status, total_amount, services, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        a.id, a.business_id, a.staff_id, a.customer_id, a.customer_name || '', a.customer_phone || '',
        a.staff_name || '', a.appointment_date, a.start_time, a.end_time,
        a.status || 'booked', a.total_amount || 0,
        JSON.stringify(a.services || []),
        a.notes || ''
      ]);
    }
    console.log(`Seeded ${list.length} appointments.`);
  }

  // 7. Sales
  if (fs.existsSync(path.join(dataPath, 'sales.json'))) {
    const list = JSON.parse(fs.readFileSync(path.join(dataPath, 'sales.json'), 'utf8'));
    for (const s of list) {
      await conn.query(`
        INSERT INTO sales (id, business_id, appointment_id, customer_id, customer_name, customer_phone, staff_id, staff_name, subtotal, item_discount_total, overall_discount, tax_amount, total_amount, payment_method, amount_tendered, change_amount, items, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        s.id, s.business_id, s.appointment_id || null, s.customer_id || null,
        s.customer_name || '', s.customer_phone || '', s.staff_id || null, s.staff_name || '',
        s.subtotal || 0, s.item_discount_total || 0, s.overall_discount || 0, s.tax_amount || 0,
        s.total_amount || 0, s.payment_method || 'cash', s.amount_tendered || 0, s.change_amount || 0,
        JSON.stringify(s.items || []),
        s.notes || ''
      ]);
    }
    console.log(`Seeded ${list.length} sales.`);
  }

  // 8. Settings
  if (fs.existsSync(path.join(dataPath, 'settings.json'))) {
    const list = JSON.parse(fs.readFileSync(path.join(dataPath, 'settings.json'), 'utf8'));
    for (const st of list) {
      await conn.query(`
        INSERT INTO settings (id, business_id, time_format, clock_display, booking_slot_interval, buffer_time_between_sessions, open_time, close_time, allow_walk_in_queue, require_doctor_notes, allow_delete_service)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        st.id || 1, st.business_id || 1, st.time_format || '12', st.clock_display || '12h',
        st.booking_slot_interval || 30, st.buffer_time_between_sessions || 10,
        st.open_time || '08:00', st.close_time || '20:00',
        st.allow_walk_in_queue ? 1 : 0, st.require_doctor_notes ? 1 : 0, st.allow_delete_service ? 1 : 0
      ]);
    }
    console.log(`Seeded ${list.length} settings.`);
  }

  console.log('\n--- VERIFYING ALL TABLES IN MARIADB ---');
  const [tables] = await conn.query('SHOW TABLES');
  for (const t of tables) {
    const tableName = Object.values(t)[0];
    const [rows] = await conn.query(`SELECT COUNT(*) as count FROM \`${tableName}\``);
    console.log(`  ✓ ${tableName}: ${rows[0].count} records`);
  }

  await conn.end();
  console.log('\nRebuild completed successfully!');
}

rebuild().catch(err => {
  console.error('Rebuild failed:', err);
});
