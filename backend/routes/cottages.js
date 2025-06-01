const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

// PostgreSQL connection configuration
const pool = new Pool({
    connectionString: 'postgres://postgres:L0kijuhy!@192.168.0.104:5432/BD_LesBaza?sslmode=disable'
});

// Get all cottages
router.get('/', async (req, res) => {
    try {
        const { rows } = await pool.query('SELECT * FROM cottages');
        res.json(rows);
    } catch (err) {
        console.error('Error fetching cottages:', err);
        res.status(500).json({ message: 'Error fetching cottages' });
    }
});

// Get a specific cottage
router.get('/:id', async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT * FROM cottages WHERE id = $1',
            [req.params.id]
        );
        if (rows.length === 0) {
            return res.status(404).json({ message: 'Cottage not found' });
        }
        res.json(rows[0]);
    } catch (err) {
        console.error('Error fetching cottage:', err);
        res.status(500).json({ message: 'Error fetching cottage' });
    }
});

module.exports = router;
