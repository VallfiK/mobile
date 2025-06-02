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
            'SELECT cottage_id, name, status FROM lesbaza.cottages ORDER BY cottage_id'
        );
        
        // Преобразуем данные для совместимости с Flutter моделью
        const cottages = rows.map(row => ({
            id: row.cottage_id.toString(),
            name: row.name || `Домик ${row.cottage_id}`,
            description: 'Уютный домик для отдыха',
            price: 5000, // Фиксированная цена, так как в БД нет этого поля
            images: [], // Пустой массив изображений
            capacity: 4, // Фиксированная вместимость
            status: row.status || 'free'
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
            'SELECT cottage_id, name, status FROM lesbaza.cottages WHERE cottage_id = $1',
            [req.params.id]
        );
        
        if (rows.length === 0) {
            return res.status(404).json({ message: 'Cottage not found' });
        }
        
        const cottage = {
            id: rows[0].cottage_id.toString(),
            name: rows[0].name || `Домик ${rows[0].cottage_id}`,
            description: 'Уютный домик для отдыха на берегу озера. Идеально подходит для семейного отдыха.',
            price: 5000, // Фиксированная цена
            images: [], // Пустой массив изображений
            capacity: 4, // Фиксированная вместимость
            status: rows[0].status || 'free'
        };
        
        res.json(cottage);
    } catch (err) {
        console.error('Error fetching cottage:', err);
        res.status(500).json({ message: 'Error fetching cottage', error: err.message });
    }
});

// Get free cottages
router.get('/status/free', async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT cottage_id, name, status FROM lesbaza.cottages WHERE status = $1',
            ['free']
        );
        
        // Преобразуем данные для совместимости с Flutter моделью
        const cottages = rows.map(row => ({
            id: row.cottage_id.toString(),
            name: row.name || `Домик ${row.cottage_id}`,
            description: 'Уютный домик для отдыха',
            price: 5000,
            images: [],
            capacity: 4,
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