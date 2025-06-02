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
        const { rows } = await pool.query(
            `SELECT 
                b.booking_id as id,
                b.cottage_id,
                b.guest_name,
                b.phone,
                b.email,
                b.check_in_date,
                b.check_out_date,
                b.status,
                b.created_at,
                c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            ORDER BY b.check_in_date DESC`
        );
        
        // Преобразуем данные для Flutter
        const bookings = rows.map(row => ({
            id: row.id?.toString() || '',
            cottageId: row.cottage_id?.toString() || '',
            startDate: row.check_in_date,
            endDate: row.check_out_date,
            guests: row.guests || 1,
            userId: row.user_id?.toString() || 'admin',
            status: row.status || 'booked',
            guestName: row.guest_name || '',
            phone: row.phone || '',
            email: row.email || '',
            cottageName: row.cottage_name || ''
        }));
        
        res.json(bookings);
    } catch (err) {
        console.error('Error fetching bookings:', err);
        res.status(500).json({ message: 'Error fetching bookings', error: err.message });
    }
});

// Get bookings by cottage
router.get('/cottage/:cottageId', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT 
                b.booking_id as id,
                b.cottage_id,
                b.guest_name,
                b.phone,
                b.email,
                b.check_in_date,
                b.check_out_date,
                b.status,
                b.created_at,
                c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            WHERE b.cottage_id = $1 
            AND b.status != 'cancelled'
            ORDER BY b.check_in_date DESC`,
            [req.params.cottageId]
        );
        
        // Преобразуем данные для Flutter
        const bookings = rows.map(row => ({
            id: row.id?.toString() || '',
            cottageId: row.cottage_id?.toString() || '',
            startDate: row.check_in_date,
            endDate: row.check_out_date,
            guests: row.guests || 1,
            userId: row.user_id?.toString() || 'admin',
            status: row.status || 'booked',
            guestName: row.guest_name || '',
            phone: row.phone || '',
            email: row.email || '',
            cottageName: row.cottage_name || ''
        }));
        
        res.json(bookings);
    } catch (err) {
        console.error('Error fetching bookings by cottage:', err);
        res.status(500).json({ message: 'Error fetching bookings', error: err.message });
    }
});

// Check if a cottage is available for booking
router.get('/check-availability', async (req, res) => {
    try {
        const { startDate, endDate, cottageId } = req.query;
        if (!startDate || !endDate || !cottageId) {
            return res.status(400).json({ message: 'startDate, endDate, and cottageId are required' });
        }

        const { rows } = await pool.query(
            `SELECT EXISTS (
                SELECT 1 FROM lesbaza.bookings 
                WHERE cottage_id = $1 
                AND status != 'cancelled'
                AND (
                    ($2::date BETWEEN check_in_date AND check_out_date) 
                    OR ($3::date BETWEEN check_in_date AND check_out_date)
                    OR (check_in_date BETWEEN $2::date AND $3::date)
                )
            ) as is_booked`,
            [cottageId, startDate, endDate]
        );

        res.json({ isAvailable: !rows[0].is_booked });
    } catch (err) {
        console.error('Error checking availability:', err);
        res.status(500).json({ message: 'Error checking availability', error: err.message });
    }
});

// Create a new booking
router.post('/', async (req, res) => {
    try {
        const { startDate, endDate, guests, cottageId, guestName, phone, email, userId } = req.body;
        
        // Проверяем доступность домика
        const { rows: availability } = await pool.query(
            `SELECT EXISTS (
                SELECT 1 FROM lesbaza.bookings 
                WHERE cottage_id = $1 
                AND status != 'cancelled'
                AND (
                    ($2::date BETWEEN check_in_date AND check_out_date) 
                    OR ($3::date BETWEEN check_in_date AND check_out_date)
                    OR (check_in_date BETWEEN $2::date AND $3::date)
                )
            ) as is_booked`,
            [cottageId, startDate, endDate]
        );

        if (availability[0].is_booked) {
            return res.status(400).json({ message: 'Cottage is already booked for these dates' });
        }

        // Создаем бронирование
        const { rows } = await pool.query(
            `INSERT INTO lesbaza.bookings 
            (cottage_id, guest_name, phone, email, check_in_date, check_out_date, 
             status, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, 'booked', NOW())
            RETURNING *`,
            [cottageId, guestName || '', phone || '', email || '', startDate, endDate]
        );
        
        // Возвращаем в формате Flutter
        const booking = {
            id: rows[0].id?.toString() || '',
            cottageId: rows[0].cottage_id?.toString() || '',
            startDate: rows[0].check_in_date,
            endDate: rows[0].check_out_date,
            guests: rows[0].guests || 1,
            userId: rows[0].user_id || 'admin',
            status: rows[0].status,
            guestName: rows[0].guest_name || '',
            phone: rows[0].phone || '',
            email: rows[0].email || ''
        };
        
        res.status(201).json(booking);
    } catch (err) {
        console.error('Error creating booking:', err);
        res.status(500).json({ message: 'Error creating booking', error: err.message });
    }
});

// Get a specific booking
router.get('/:id', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT 
                b.booking_id as id,
                b.cottage_id,
                b.guest_name,
                b.phone,
                b.email,
                b.check_in_date,
                b.check_out_date,
                b.status,
                b.created_at,
                c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            WHERE b.booking_id = $1`,
            [req.params.id]
        );
        
        if (rows.length === 0) {
            return res.status(404).json({ message: 'Booking not found' });
        }
        
        // Преобразуем данные для Flutter
        const booking = {
            id: rows[0].id?.toString() || '',
            cottageId: rows[0].cottage_id?.toString() || '',
            guestName: rows[0].guest_name || '',
            phone: rows[0].phone || '',
            email: rows[0].email || '',
            startDate: rows[0].check_in_date,
            endDate: rows[0].check_out_date,
            status: rows[0].status,
            createdAt: rows[0].created_at,
            cottageName: rows[0].cottage_name || ''
        };
        
        res.json(booking);
    } catch (err) {
        console.error('Error fetching booking:', err);
        res.status(500).json({ message: 'Error fetching booking', error: err.message });
    }
});

// Cancel a booking
router.delete('/:id', async (req, res) => {
    try {
        const { rowCount } = await pool.query(
            `UPDATE lesbaza.bookings 
            SET status = 'cancelled', cancelled_at = NOW()
            WHERE id = $1`,
            [req.params.id]
        );
        
        if (rowCount === 0) {
            return res.status(404).json({ message: 'Booking not found' });
        }
        
        res.status(204).send();
    } catch (err) {
        console.error('Error cancelling booking:', err);
        res.status(500).json({ message: 'Error cancelling booking', error: err.message });
    }
});

// Update booking (for check-out)
router.get('/cottage/:cottageId/available-dates', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT 
                generate_series(
                    CURRENT_DATE,
                    CURRENT_DATE + INTERVAL '1 year',
                    '1 day'
                )::date as date
            EXCEPT
            SELECT 
                generate_series(
                    check_in_date,
                    check_out_date - INTERVAL '1 day',
                    '1 day'
                )::date as date
            FROM lesbaza.bookings
            WHERE cottage_id = $1
            AND status IN ('booked', 'occupied')
            AND check_in_date >= CURRENT_DATE
            ORDER BY date`,
            [req.params.cottageId]
        );
        
        res.json(rows.map(row => row.date.toISOString().split('T')[0]));
    } catch (err) {
        console.error('Error fetching available dates:', err);
        res.status(500).json({ message: 'Error fetching available dates', error: err.message });
    }
});

router.put('/:id/check-out', async (req, res) => {
    try {
        const { checkOutDate, notes } = req.body;
        const { rowCount } = await pool.query(
            `UPDATE lesbaza.bookings 
            SET check_out_date = $1, notes = $2 
            WHERE booking_id = $3`,
            [checkOutDate || new Date(), notes || '', req.params.id]
        );
        
        if (rowCount === 0) {
            return res.status(404).json({ message: 'Booking not found' });
        }
        
        res.json({ message: 'Booking checked out successfully' });
    } catch (err) {
        console.error('Error checking out booking:', err);
        res.status(500).json({ message: 'Error checking out booking', error: err.message });
    }
});

module.exports = router;