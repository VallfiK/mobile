require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Логирование всех запросов
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Routes
try {
    const cottagesRouter = require('./routes/cottages');
    app.use('/api/cottages', cottagesRouter);
    console.log('Cottages routes loaded successfully');
} catch (err) {
    console.error('Error loading cottages routes:', err);
}

try {
    const bookingsRouter = require('./routes/bookings');
    app.use('/api/bookings', bookingsRouter);
    console.log('Bookings routes loaded successfully');
} catch (err) {
    console.error('Error loading bookings routes:', err);
}

// Calendar routes
app.get('/api/calendar/:cottageId/:startDate/:endDate', async (req, res) => {
    try {
        const { cottageId, startDate, endDate } = req.params;
        
        // Get bookings for the cottage in the date range
        const { rows: bookings } = await pool.query(
            `SELECT b.*, c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            WHERE b.cottage_id = $1 
            AND (
                ($2::date BETWEEN check_in_date AND check_out_date) 
                OR ($3::date BETWEEN check_in_date AND check_out_date)
                OR (check_in_date BETWEEN $2::date AND $3::date)
            )`,
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
            
            // Mark check-in day
            const checkInDate = checkIn.toISOString().split('T')[0];
            if (calendar[checkInDate]) {
                calendar[checkInDate][booking.cottage_id] = {
                    status: booking.status,
                    bookingId: booking.id,
                    guestName: booking.guest_name,
                    isCheckIn: true,
                    isPartDay: true
                };
            }

            // Mark check-out day
            const checkOutDate = checkOut.toISOString().split('T')[0];
            if (calendar[checkOutDate]) {
                calendar[checkOutDate][booking.cottage_id] = {
                    status: booking.status,
                    bookingId: booking.id,
                    guestName: booking.guest_name,
                    isCheckOut: true,
                    isPartDay: true
                };
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

// Test route
app.get('/', (req, res) => {
    res.json({ 
        message: 'API is running',
        endpoints: [
            'GET /api/cottages',
            'GET /api/cottages/:id',
            'GET /api/bookings',
            'POST /api/bookings',
            'GET /api/calendar/:cottageId/:startDate/:endDate'
        ]
    });
});

// Handle 404
app.use((req, res) => {
    res.status(404).json({ message: `Route ${req.url} not found` });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({ 
        message: 'Server error', 
        error: err.message 
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log(`API endpoints available at http://localhost:${PORT}/api`);
});