const express = require('express');
const router = express.Router();
const {
  getCategories,
  createCategory,
  updateCategory,
  deleteCategory,
} = require('../config/db');

// List categories
router.get('/', async (req, res) => {
  try {
    const businessId = req.business ? req.business.id : 1;
    const categories = await getCategories(businessId);
    res.json({ success: true, count: categories.length, data: categories });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Create category
router.post('/', async (req, res) => {
  try {
    const { name, description, icon, sort_order } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Category name is required.' });
    }
    const businessId = req.business ? req.business.id : 1;
    const category = await createCategory({
      business_id: businessId,
      name,
      description: description || '',
      icon: icon || 'category',
      sort_order: sort_order || 0,
    });
    res.status(201).json({ success: true, message: 'Category created successfully', data: category });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Update category
router.put('/:id', async (req, res) => {
  try {
    const updated = await updateCategory(req.params.id, req.body);
    if (!updated) return res.status(404).json({ success: false, message: 'Category not found' });
    res.json({ success: true, message: 'Category updated successfully', data: updated });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Delete category
router.delete('/:id', async (req, res) => {
  try {
    const ok = await deleteCategory(req.params.id);
    if (!ok) return res.status(404).json({ success: false, message: 'Category not found' });
    res.json({ success: true, message: 'Category deleted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
