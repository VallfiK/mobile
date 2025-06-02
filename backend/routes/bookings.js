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
            `SELECT b.*, c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            ORDER BY b.check_in_date DESC`
        );
        res.json(rows);
    } catch (err) {
        console.error('Error fetching bookings:', err);
        res.status(500).json({ message: 'Error fetching bookings', error: err.message });
    }
});

// Get bookings by cottage
router.get('/cottage/:cottageId', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT b.*, c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            WHERE b.cottage_id = $1 
            ORDER BY b.check_in_date DESC`,
            [req.params.cottageId]
        );
        res.json(rows);
    } catch (err) {
        console.error('Error fetching bookings by cottage:', err);
        res.status(500).json({ message: 'Error fetching bookings', error: err.message });
    }
});

// Get calendar data for a date range
router.get('/calendar/:cottageId/:startDate/:endDate', async (req, res) => {
    try {
        const { cottageId, startDate, endDate } = req.params;
        
        // Get bookings for the cottage in the date range
        const { rows: bookings } = await pool.query(
            `SELECT b.*, c.name as cottage_name, t.name as tariff_name, t.price as tariff_price
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            LEFT JOIN lesbaza.tariffs t ON b.tariff_id = t.tariff_id
            WHERE b.cottage_id = $1 
            AND (
                ($2::date BETWEEN check_in_date AND check_out_date) 
                OR ($3::date BETWEEN check_in_date AND check_out_date)
                OR (check_in_date BETWEEN $2::date AND $3::date)
            )
            ORDER BY b.check_in_date`,
            [cottageId, startDate, endDate]
        );

        // Initialize calendar data
        const calendar = {};
        
        // Add all dates to calendar
        const start = new Date(startDate);
        const end = new Date(endDate);
        
        for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
            const date = d.toISOString().split('T')[0];
            calendar[date] = {};
        }

        // Fill calendar with booking data
        bookings.forEach(booking => {
            const checkIn = new Date(booking.check_in_date);
            const checkOut = new Date(booking.check_out_date);
            const checkInDate = checkIn.toISOString().split('T')[0];
            const checkOutDate = checkOut.toISOString().split('T')[0];

            // Mark all days of the booking period
            for (let d = new Date(checkIn); d <= checkOut; d.setDate(d.getDate() + 1)) {
                const date = d.toISOString().split('T')[0];
                if (calendar[date]) {
                    calendar[date][booking.cottage_id] = {
                        status: booking.status,
                        bookingId: booking.id,
                        guestName: booking.guest_name,
                        phone: booking.phone,
                        email: booking.email,
                        checkIn: checkInDate,
                        checkOut: checkOutDate,
                        tariff: {
                            name: booking.tariff_name,
                            price: booking.tariff_price
                        },
                        totalCost: booking.total_cost,
                        notes: booking.notes,
                        isCheckIn: date === checkInDate,
                        isCheckOut: date === checkOutDate,
                        isPartDay: date === checkInDate || date === checkOutDate
                    };
                }
            }

            // Mark all days in between
            for (let d = new Date(checkIn); d < checkOut; d.setDate(d.getDate() + 1)) {
                const date = d.toISOString().split('T')[0];
                if (calendar[date]) {
                    calendar[date][booking.cottage_id] = {
                        status: booking.status,
                        bookingId: booking.id,
                        guestName: booking.guest_name,
                        isPartDay: false
                    };
                }
            }
        });

        res.json(calendar);
    } catch (err) {
        console.error('Error fetching calendar data:', err);
        res.status(500).json({ message: 'Error fetching calendar data', error: err.message });
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
        const { checkInDate, checkOutDate, guests, cottageId, guestName, phone, email, notes, tariffId } = req.body;
        
        // Check if the cottage is available
        const { rows: availability } = await pool.query(
            `SELECT EXISTS (
                SELECT 1 FROM lesbaza.bookings 
                WHERE cottage_id = $1 
                AND (
                    ($2::date BETWEEN check_in_date AND check_out_date) 
                    OR ($3::date BETWEEN check_in_date AND check_out_date)
                    OR (check_in_date BETWEEN $2::date AND $3::date)
                )
            ) as is_booked`,
            [cottageId, checkInDate, checkOutDate]
        );

        if (availability[0].is_booked) {
            return res.status(400).json({ message: 'Cottage is already booked for these dates' });
        }

        const { rows } = await pool.query(
            `INSERT INTO lesbaza.bookings 
            (cottage_id, guest_name, phone, email, check_in_date, check_out_date, 
             status, created_at, notes, tariff_id)
            VALUES ($1, $2, $3, $4, $5, $6, 'booked', NOW(), $7, $8)
            RETURNING *`,
            [cottageId, guestName, phone, email, checkInDate, checkOutDate, notes, tariffId]
        );
        res.status(201).json(rows[0]);
    } catch (err) {
        console.error('Error creating booking:', err);
        res.status(500).json({ message: 'Error creating booking', error: err.message });
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
        
        res.json({ message: 'Booking cancelled successfully' });
    } catch (err) {
        console.error('Error cancelling booking:', err);
        res.status(500).json({ message: 'Error cancelling booking', error: err.message });
    }
});

module.exports = router;

// Create a new booking
router.post('/', async (req, res) => {
    try {
        const { startDate, endDate, guests, cottageId, guestName, phone, email, notes, tariffId } = req.body;
        
        // Check if the cottage is available
        const { rows: availability } = await pool.query(
            `SELECT EXISTS (
                SELECT 1 FROM lesbaza.bookings 
                WHERE cottage_id = $1 
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

        const { rows } = await pool.query(
            `INSERT INTO lesbaza.bookings 
            (cottage_id, guest_name, phone, email, check_in_date, check_out_date, 
             status, created_at, notes, tariff_id)
            VALUES ($1, $2, $3, $4, $5, $6, 'booked', NOW(), $7, $8)
            RETURNING *`,
            [cottageId, guestName, phone, email, startDate, endDate, notes, tariffId]
        );
        res.status(201).json(rows[0]);
    } catch (err) {
        console.error('Error creating booking:', err);
        res.status(500).json({ message: 'Error creating booking', error: err.message });
    }
});

// Get all bookings
router.get('/', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT b.*, c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id
            ORDER BY b.check_in_date DESC`
        );
        res.json(rows);
    } catch (err) {
        console.error('Error fetching bookings:', err);
        res.status(500).json({ message: 'Error fetching bookings', error: err.message });
    }
});

// Get bookings by cottage
router.get('/cottage/:cottageId', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT * FROM lesbaza.bookings 
            WHERE cottage_id = $1
            ORDER BY check_in_date DESC`,
            [req.params.cottageId]
        );
        res.json(rows);
    } catch (err) {
        console.error('Error fetching bookings by cottage:', err);
        res.status(500).json({ message: 'Error fetching bookings', error: err.message });
    }
});

// Get a specific booking
router.get('/:id', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT b.*, c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            WHERE b.id = $1`,
            [req.params.id]
        );
        if (rows.length === 0) {
            return res.status(404).json({ message: 'Booking not found' });
        }
        res.json(rows[0]);
    } catch (err) {
        console.error('Error fetching booking:', err);
        res.status(500).json({ message: 'Error fetching booking', error: err.message });
    }
});

// Check out (complete) a booking
router.put('/:id/check-out', async (req, res) => {
    try {
        const { checkOutDate, notes } = req.body;
        const { rowCount } = await pool.query(
            `UPDATE lesbaza.bookings 
            SET status = 'completed', check_out_date = $1, notes = $2
            WHERE id = $3`,
            [checkOutDate, notes, req.params.id]
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
        res.json({ message: 'Booking updated successfully' });
    } catch (err) {
        console.error('Error updating booking:', err);
        res.status(500).json({ message: 'Error updating booking' });
    }
});

module.exports = router;