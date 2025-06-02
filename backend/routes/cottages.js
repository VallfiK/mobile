const express = require('express');
const { Pool } = require('pg');
const router = express.Router();

// PostgreSQL connection configuration
const pool = new Pool({
    connectionString: 'postgres://postgres:L0kijuhy!@192.168.0.104:5432/BD_LesBaza?sslmode=disable'
});

// Get all cottages
router.get('/', async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT cottage_id as id, name, status FROM lesbaza.cottages ORDER BY cottage_id'
        );
        
        // Преобразуем данные для совместимости с Flutter моделью
        const cottages = rows.map(row => ({
            id: row.id.toString(),
            name: row.name || '',
            description: '', // Устанавливаем пустую строку вместо несуществующей колонки
            price: 0, // Устанавливаем 0 вместо несуществующей колонки
            images: [], // Устанавливаем пустой массив вместо несуществующей колонки
            capacity: 0, // Устанавливаем 0 вместо несуществующей колонки
            status: row.status
        }));
        
        res.json(cottages);
    } catch (err) {
        console.error('Error fetching cottages:', err);
        res.status(500).json({ message: 'Error fetching cottages', error: err.message });
    }
});

// Get a specific cottage
router.get('/:id', async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT cottage_id as id, name, status FROM lesbaza.cottages WHERE cottage_id = $1',
            [req.params.id]
        );
        
        if (rows.length === 0) {
            return res.status(404).json({ message: 'Cottage not found' });
        }
        
        const cottage = {
            id: rows[0].id.toString(),
            name: rows[0].name || '',
            description: '', // Устанавливаем пустую строку вместо null
            price: 0, // Устанавливаем 0 вместо null
            images: [], // Устанавливаем пустой массив вместо null
            capacity: 0, // Устанавливаем 0 вместо null
            status: rows[0].status
        };
        
        res.json(cottage);
    } catch (err) {
        console.error('Error fetching cottage:', err);
        res.status(500).json({ message: 'Error fetching cottage', error: err.message });
    }
});

// Get free cottages
router.get('/free', async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT cottage_id as id, name, description, price, images, capacity, status FROM lesbaza.cottages WHERE status = $1',
            ['free']
        );
        
        // Преобразуем данные для совместимости с Flutter моделью
        const cottages = rows.map(row => ({
            id: row.id.toString(),
            name: row.name || '',
            description: row.description || '',
            price: row.price || 0,
            images: row.images ? JSON.parse(row.images) : [],
            capacity: row.capacity || 0,
            status: row.status
        }));
        
        res.json(cottages);
    } catch (err) {
        console.error('Error fetching free cottages:', err);
        res.status(500).json({ message: 'Error fetching free cottages', error: err.message });
    }
});

// Update cottage status
router.put('/:id/status', async (req, res) => {
    try {
        const { status } = req.body;
        if (!status) {
            return res.status(400).json({ message: 'Status is required' });
        }

        const { rowCount } = await pool.query(
            'UPDATE lesbaza.cottages SET status = $1 WHERE cottage_id = $2',
            [status, req.params.id]
        );

        if (rowCount === 0) {
            return res.status(404).json({ message: 'Cottage not found' });
        }

        res.json({ message: 'Cottage status updated successfully' });
    } catch (err) {
        console.error('Error updating cottage status:', err);
        res.status(500).json({ message: 'Error updating cottage status', error: err.message });
    }
});

module.exports = router;