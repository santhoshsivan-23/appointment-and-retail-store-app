const express = require('express');
const router = express.Router();
const {
  getProducts,
  getPaginatedProducts,
  createProduct,
  updateProduct,
  deleteProduct,
} = require('../config/db');

// Dedicated Paginated Products API for React Cart Page (Server-side pagination: 20 per request)
router.get('/cart-paginated', async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.max(1, parseInt(req.query.limit, 10) || 20);
    const categoryId = req.query.category_id && req.query.category_id !== 'all' && req.query.category_id !== 'null'
      ? req.query.category_id
      : null;
    const { product_type, search, q } = req.query;
    const businessId = req.business ? req.business.id : 1;

    const result = await getPaginatedProducts(businessId, {
      categoryId,
      productType: product_type,
      search: search || q || '',
      page,
      limit,
    });

    res.json({
      success: true,
      data: result.products,
      pagination: result.pagination,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Alias endpoint for paginated access
router.get('/paginated', async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.max(1, parseInt(req.query.limit, 10) || 20);
    const categoryId = req.query.category_id && req.query.category_id !== 'all' && req.query.category_id !== 'null'
      ? req.query.category_id
      : null;
    const { product_type, search, q } = req.query;
    const businessId = req.business ? req.business.id : 1;

    const result = await getPaginatedProducts(businessId, {
      categoryId,
      productType: product_type,
      search: search || q || '',
      page,
      limit,
    });

    res.json({
      success: true,
      data: result.products,
      pagination: result.pagination,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// List products (Existing unpaginated endpoint preserved for Flutter app, POS, and subterminals)
router.get('/', async (req, res) => {
  try {
    const { category_id, product_type, search } = req.query;
    const businessId = req.business ? req.business.id : 1;
    const products = await getProducts(businessId, category_id, product_type, search);
    res.json({ success: true, count: products.length, data: products });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Dedicated Product / Service Search API
// Accepts keyword via ?q=..., ?search=..., or ?keyword=...
router.get('/search', async (req, res) => {
  try {
    const q = (req.query.q || req.query.keyword || req.query.search || '').trim();
    if (!q) {
      return res.json({ success: true, count: 0, data: [] });
    }
    const businessId = req.business ? req.business.id : 1;
    const { category_id, product_type } = req.query;
    const products = await getProducts(businessId, category_id, product_type, q);
    res.json({ success: true, count: products.length, data: products });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Create product (normal, modifier, combo)
router.post('/', async (req, res) => {
  try {
    const {
      name,
      category_id,
      sku,
      product_type,
      price,
      description,
      modifiers,
      combo_items,
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Product name is required.' });
    }

    const businessId = req.business ? req.business.id : 1;
    const product = await createProduct({
      business_id: businessId,
      category_id,
      name,
      sku,
      product_type: product_type || 'normal',
      price: price !== undefined ? price : 0.0,
      description,
      modifiers: modifiers || [],
      combo_items: combo_items || [],
    });

    res.status(201).json({ success: true, message: 'Product created successfully', data: product });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Update product
router.put('/:id', async (req, res) => {
  try {
    const updated = await updateProduct(req.params.id, req.body);
    if (!updated) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, message: 'Product updated successfully', data: updated });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Delete product
router.delete('/:id', async (req, res) => {
  try {
    const ok = await deleteProduct(req.params.id);
    if (!ok) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, message: 'Product deleted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
