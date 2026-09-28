const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

let pool = null;
let useFallback = false;

const dataDir = path.join(__dirname, '..', 'data');
const jsonFilePath = path.join(dataDir, 'businesses.json');

// Ensure data directory and fallback JSON file exist
function initFallbackStorage() {
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }
  if (!fs.existsSync(jsonFilePath)) {
    fs.writeFileSync(jsonFilePath, JSON.stringify([], null, 2), 'utf8');
  }
}

// Fallback JSON operations
function getFallbackBusinesses() {
  initFallbackStorage();
  try {
    const raw = fs.readFileSync(jsonFilePath, 'utf8');
    return JSON.parse(raw || '[]');
  } catch (err) {
    console.error('Error reading JSON fallback file:', err);
    return [];
  }
}

function saveFallbackBusinesses(businesses) {
  initFallbackStorage();
  fs.writeFileSync(jsonFilePath, JSON.stringify(businesses, null, 2), 'utf8');
}

// Initialize MySQL Database and Tables
async function initDatabase() {
  const host = process.env.DB_HOST || 'localhost';
  const user = process.env.DB_USER || 'root';
  const password = process.env.DB_PASSWORD || '';
  const database = process.env.DB_NAME || 'appointment_hotel_booking';
  const port = parseInt(process.env.DB_PORT || '3306', 10);

  try {
    // Attempt connecting to server to ensure database exists
    const tempConnection = await mysql.createConnection({
      host,
      user,
      password,
      port,
      connectTimeout: 3000,
    });

    await tempConnection.query(`CREATE DATABASE IF NOT EXISTS \`${database}\`;`);
    await tempConnection.end();

    // Create pool for the specific database
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

    // Create businesses table if not exists
    const createTableQuery = `
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
    `;

    await pool.query(createTableQuery);
    useFallback = false;
    console.log(`✅ [MySQL] Connected successfully to database: "${database}"`);
  } catch (err) {
    console.warn(`⚠️ [MySQL] Connection failed (${err.message}).`);
    console.warn('📁 [Storage] Switching to local JSON fallback database in /data/businesses.json.');
    useFallback = true;
    initFallbackStorage();
  }
}

// Unified Database Access Functions
async function findBusinessByEmail(email) {
  const normalizedEmail = (email || '').trim().toLowerCase();

  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT * FROM businesses WHERE LOWER(email) = ?', [normalizedEmail]);
      return rows[0] || null;
    } catch (err) {
      console.error('MySQL query error, using fallback:', err.message);
    }
  }

  const businesses = getFallbackBusinesses();
  return businesses.find((b) => b.email.toLowerCase() === normalizedEmail) || null;
}

async function findBusinessById(id) {
  if (!useFallback && pool) {
    try {
      const [rows] = await pool.query('SELECT id, business_name, business_type, owner_name, email, phone, address, city, country, description, created_at FROM businesses WHERE id = ?', [id]);
      return rows[0] || null;
    } catch (err) {
      console.error('MySQL query error, using fallback:', err.message);
    }
  }

  const businesses = getFallbackBusinesses();
  const business = businesses.find((b) => String(b.id) === String(id));
  if (!business) return null;
  const { password, ...safeData } = business;
  return safeData;
}

async function createBusiness(data) {
  const {
    business_name,
    business_type,
    owner_name,
    email,
    phone,
    password,
    address = '',
    city = '',
    country = '',
    description = '',
  } = data;

  const normalizedEmail = email.trim().toLowerCase();

  if (!useFallback && pool) {
    try {
      const query = `
        INSERT INTO businesses 
        (business_name, business_type, owner_name, email, phone, password, address, city, country, description) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      const [result] = await pool.query(query, [
        business_name.trim(),
        business_type.trim(),
        owner_name.trim(),
        normalizedEmail,
        phone.trim(),
        password,
        address.trim(),
        city.trim(),
        country.trim(),
        description.trim(),
      ]);

      return {
        id: result.insertId,
        business_name: business_name.trim(),
        business_type: business_type.trim(),
        owner_name: owner_name.trim(),
        email: normalizedEmail,
        phone: phone.trim(),
        address: address.trim(),
        city: city.trim(),
        country: country.trim(),
        description: description.trim(),
        created_at: new Date().toISOString(),
      };
    } catch (err) {
      console.error('MySQL insert error, using fallback:', err.message);
    }
  }

  // Fallback JSON insert
  const businesses = getFallbackBusinesses();
  const newId = businesses.length > 0 ? Math.max(...businesses.map((b) => Number(b.id) || 0)) + 1 : 1;
  const newBusiness = {
    id: newId,
    business_name: business_name.trim(),
    business_type: business_type.trim(),
    owner_name: owner_name.trim(),
    email: normalizedEmail,
    phone: phone.trim(),
    password,
    address: address.trim(),
    city: city.trim(),
    country: country.trim(),
    description: description.trim(),
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  businesses.push(newBusiness);
  saveFallbackBusinesses(businesses);

  const { password: _, ...safeData } = newBusiness;
  return safeData;
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
  findBusinessByEmail,
  findBusinessById,
  createBusiness,
  getDatabaseStatus,
};
