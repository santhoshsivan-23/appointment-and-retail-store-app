const express = require('express');
const router = express.Router();
const {
  getProducts,
  createProduct,
  updateProduct,
  deleteProduct,
} = require('../config/db');

// List products
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
