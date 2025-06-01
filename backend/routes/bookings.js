const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

// PostgreSQL connection configuration
const pool = new Pool({
    connectionString: 'postgres://postgres:L0kijuhy!@192.168.0.104:5432/BD_LesBaza?sslmode=disable'
});

// Get all bookings
router.get('/', async (req, res) => {
    try {
        const { rows } = await pool.query('SELECT * FROM bookings');
        res.json(rows);
    } catch (err) {
        console.error('Error fetching bookings:', err);
        res.status(500).json({ message: 'Error fetching bookings' });
    }
});

// Create a new booking
router.post('/', async (req, res) => {
    try {
        const { startDate, endDate, guests, cottageId } = req.body;
        const { rows } = await pool.query(
            'INSERT INTO bookings (start_date, end_date, guests, cottage_id) VALUES ($1, $2, $3, $4) RETURNING *',
            [startDate, endDate, guests, cottageId]
        );
        res.status(201).json(rows[0]);
    } catch (err) {
        console.error('Error creating booking:', err);
        res.status(500).json({ message: 'Error creating booking' });
    }
});

// Get a specific booking
router.get('/:id', async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT * FROM bookings WHERE id = $1',
            [req.params.id]
        );
        if (rows.length === 0) {
            return res.status(404).json({ message: 'Booking not found' });
        }
        res.json(rows[0]);
    } catch (err) {
        console.error('Error fetching booking:', err);
        res.status(500).json({ message: 'Error fetching booking' });
    }
});

// Delete a booking
router.delete('/:id', async (req, res) => {
    try {
        const { rowCount } = await pool.query('DELETE FROM bookings WHERE id = $1', [req.params.id]);
        if (rowCount === 0) {
            return res.status(404).json({ message: 'Booking not found' });
        }
        res.json({ message: 'Booking deleted successfully' });
    } catch (err) {
        console.error('Error deleting booking:', err);
        res.status(500).json({ message: 'Error deleting booking' });
    }
});

// Update a booking
router.put('/:id', async (req, res) => {
    try {
        const { startDate, endDate, guests, cottageId } = req.body;
        const { rowCount } = await pool.query(
            'UPDATE bookings SET start_date = $1, end_date = $2, guests = $3, cottage_id = $4 WHERE id = $5',
            [startDate, endDate, guests, cottageId, req.params.id]
        );
        if (rowCount === 0) {
            return res.status(404).json({ message: 'Booking not found' });
        }
        res.json({ message: 'Booking updated successfully' });
    } catch (err) {
        console.error('Error updating booking:', err);
        res.status(500).json({ message: 'Error updating booking' });
    }
});

module.exports = router;

module.exports = router;
