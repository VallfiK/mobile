const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const NodeCache = require('node-cache');

// Создаем кэш с временем жизни 5 минут
const bookingsCache = new NodeCache({ stdTTL: 300 });

// PostgreSQL connection configuration
const pool = new Pool({
    connectionString: 'postgres://postgres:L0kijuhy!@192.168.0.104:5432/BD_LesBaza?sslmode=disable'
});

// SQL для создания таблицы бронирований
const createBookingsTableSQL = `
    CREATE TABLE IF NOT EXISTS lesbaza.bookings (
        booking_id SERIAL PRIMARY KEY,
        cottage_id INTEGER REFERENCES lesbaza.cottages(cottage_id),
        guest_name VARCHAR(100) NOT NULL,
        phone VARCHAR(20),
        email VARCHAR(100),
        check_in_date TIMESTAMP NOT NULL,
        check_out_date TIMESTAMP NOT NULL,
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        guests INTEGER DEFAULT 1,
        cancelled_at TIMESTAMP,
        tariff_id INTEGER REFERENCES lesbaza.tariffs(tariff_id),
        prepayment DECIMAL(10, 2) DEFAULT 0,
        total_paid DECIMAL(10, 2) DEFAULT 0 
    );
`;

// Добавляем таблицу тарифов и обновляем таблицу бронирований
const setupTablesSQL = `
    CREATE TABLE IF NOT EXISTS lesbaza.tariffs (
        tariff_id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        price_per_day DECIMAL(10, 2) NOT NULL
    );
`;

// SQL для добавления полей prepayment и total_paid в существующую таблицу
const addPaymentsColumnsSQL = `
    ALTER TABLE lesbaza.bookings 
    ADD COLUMN IF NOT EXISTS prepayment DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_paid DECIMAL(10, 2) DEFAULT 0;
`;

// Выполняем SQL при старте сервера
pool.query(createBookingsTableSQL)
    .then(() => console.log('Bookings table created successfully'))
    .catch(err => console.error('Error creating bookings table:', err));

pool.query(setupTablesSQL)
    .then(() => console.log('Tables and tariffs set up successfully'))
    .catch(err => console.error('Error setting up tables:', err));

// Добавляем поля для платежей, если их еще нет
pool.query(addPaymentsColumnsSQL)
    .then(() => console.log('Payment columns added successfully'))
    .catch(err => console.error('Error adding payment columns:', err));

// Добавляем индексы для оптимизации запросов
const createIndexesSQL = `
    CREATE INDEX IF NOT EXISTS idx_bookings_cottage_id ON lesbaza.bookings(cottage_id);
    CREATE INDEX IF NOT EXISTS idx_bookings_status ON lesbaza.bookings(status);
    CREATE INDEX IF NOT EXISTS idx_bookings_check_in ON lesbaza.bookings(check_in_date);
    CREATE INDEX IF NOT EXISTS idx_bookings_check_out ON lesbaza.bookings(check_out_date);
`;

// Выполняем SQL при старте сервера
pool.query(createIndexesSQL)
    .then(() => console.log('Indexes created successfully'))
    .catch(err => console.error('Error creating indexes:', err));

// Функция для очистки кэша при изменении бронирований
const invalidateCache = (cottageId) => {
    bookingsCache.del(`bookings_${cottageId}`);
    bookingsCache.del('all_bookings');
};

// Функция проверки доступности
const checkAvailability = async (cottageId, startDate, endDate) => {
    const cacheKey = `availability_${cottageId}_${startDate}_${endDate}`;
    const cachedResult = bookingsCache.get(cacheKey);
    
    if (cachedResult) {
        return cachedResult;
    }

    // Convert dates to UTC for database comparison
    const utcStartDate = new Date(startDate);
    const utcEndDate = new Date(endDate);
    
    console.log('Checking availability for dates:');
    console.log('  Start date:', startDate);
    console.log('  End date:', endDate);
    console.log('  UTC start date:', utcStartDate.toISOString());
    console.log('  UTC end date:', utcEndDate.toISOString());
    
    const { rows } = await pool.query(
        `SELECT 
            EXISTS (
                SELECT 1 FROM lesbaza.bookings 
                WHERE cottage_id = $1 
                AND status NOT IN ('cancelled', 'completed')
                AND (
                    -- Проверяем пересечение дат
                    ($2::date, $3::date) OVERLAPS 
                    ((check_in_date AT TIME ZONE 'UTC')::date, (check_out_date AT TIME ZONE 'UTC')::date)
                )
            ) as is_booked,
            ARRAY_AGG(
                json_build_object(
                    'booking_id', booking_id,
                    'check_in_date', (check_in_date AT TIME ZONE 'UTC')::date,
                    'check_out_date', (check_out_date AT TIME ZONE 'UTC')::date,
                    'status', status
                )
            ) FILTER (WHERE booking_id IS NOT NULL) as conflicting_bookings
        FROM lesbaza.bookings 
        WHERE cottage_id = $1 
        AND status NOT IN ('cancelled', 'completed')
        AND DATE($2::timestamp) >= DATE(check_in_date AT TIME ZONE 'UTC')
        AND DATE($3::timestamp) < DATE(check_out_date AT TIME ZONE 'UTC')`,
        [cottageId, startDate, endDate]
    );

    const result = {
        isBooked: rows[0].is_booked,
        conflicts: (rows[0].conflicting_bookings || []).filter(b => b !== null)
    };

    bookingsCache.set(cacheKey, result);
    return result;
};

// Get all bookings
router.get('/', async (req, res) => {
    console.log('GET /api/bookings - Fetching all bookings');
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
                b.guests,
                b.prepayment,
                b.total_paid,
                c.name as cottage_name,
                t.name as tariff_name,
                t.price_per_day
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            LEFT JOIN lesbaza.tariffs t ON b.tariff_id = t.tariff_id
            ORDER BY b.check_in_date DESC`
        );
        
        // Преобразуем данные для Flutter
        const bookings = rows.map(row => ({
            id: row.id?.toString() || '',
            cottageId: row.cottage_id?.toString() || '',
            startDate: row.check_in_date,
            endDate: row.check_out_date,
            guests: row.guests || 1,
            status: row.status || 'pending',
            guestName: row.guest_name || '',
            phone: row.phone || '',
            email: row.email || '',
            cottageName: row.cottage_name || '',
            tariff: {
                name: row.tariff_name || 'Стандартный',
                pricePerDay: parseFloat(row.price_per_day) || 5000.00
            }
        }));
        
        res.json(bookings);
    } catch (err) {
        console.error('Error fetching bookings:', err);
        res.status(500).json({ message: 'Error fetching bookings', error: err.message });
    }
});

// Get bookings by cottage
router.get('/cottage/:cottageId', async (req, res) => {
    console.log(`GET /api/bookings/cottage/${req.params.cottageId} - Fetching bookings for cottage`);
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
                b.guests,
                b.notes,
                b.total_cost,
                b.prepayment,
                b.total_paid,
                b.tariff_id,
                c.name as cottage_name,
                t.name as tariff_name,
                t.price_per_day
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            LEFT JOIN lesbaza.tariffs t ON b.tariff_id = t.tariff_id
            WHERE b.cottage_id = $1 
            AND b.status != 'cancelled'
            ORDER BY b.check_in_date DESC`,
            [req.params.cottageId]
        );
        
        console.log('\n=== Raw Database Results ===');
        console.log('Found bookings:', rows.length);
        rows.forEach(row => {
            console.log(`Booking ${row.id}:`);
            console.log('  Raw check_in_date:', row.check_in_date);
            console.log('  Raw check_out_date:', row.check_out_date);
            console.log('  Status:', row.status);
            console.log('  Total cost:', row.total_cost);
            console.log('  Prepayment:', row.prepayment);
            console.log('  Total paid:', row.total_paid);
        });
        
        // Преобразуем данные для Flutter, правильно конвертируя UTC в московское время
        const bookings = rows.map(row => {
            // Конвертируем UTC даты в московское время
            const checkInDateUTC = new Date(row.check_in_date);
            const checkOutDateUTC = new Date(row.check_out_date);
            
            // Добавляем 3 часа для московского времени
            const checkInDateMoscow = new Date(checkInDateUTC.getTime() + 3 * 60 * 60 * 1000);
            const checkOutDateMoscow = new Date(checkOutDateUTC.getTime() + 3 * 60 * 60 * 1000);
            
            // Извлекаем только дату в формате YYYY-MM-DD
            const checkInDateOnly = checkInDateMoscow.toISOString().split('T')[0];
            const checkOutDateOnly = checkOutDateMoscow.toISOString().split('T')[0];
            
            // Рассчитываем суммы
            const totalCost = parseFloat(row.total_cost || 0);
            const prepayment = parseFloat(row.prepayment || 0);
            const totalPaid = parseFloat(row.total_paid || 0);
            const remainingAmount = totalCost - totalPaid;
            
            console.log(`Processing booking ${row.id}:`);
            console.log('  Raw UTC checkInDate:', row.check_in_date);
            console.log('  Raw UTC checkOutDate:', row.check_out_date);
            console.log('  Moscow checkInDate:', checkInDateMoscow.toISOString());
            console.log('  Moscow checkOutDate:', checkOutDateMoscow.toISOString());
            console.log('  Extracted checkInDateOnly:', checkInDateOnly);
            console.log('  Extracted checkOutDateOnly:', checkOutDateOnly);
            console.log('  Payment info - Total:', totalCost, 'Prepayment:', prepayment, 'Total paid:', totalPaid, 'Remaining:', remainingAmount);
            
            return {
                id: row.id?.toString() || '',
                cottageId: row.cottage_id?.toString() || '',
                startDate: checkInDateOnly,
                endDate: checkOutDateOnly,
                guests: row.guests || 1,
                status: row.status || 'booked',
                guestName: row.guest_name || '',
                phone: row.phone || '',
                email: row.email || '',
                notes: row.notes || '',
                totalCost: totalCost,
                prepayment: prepayment,
                totalPaid: totalPaid,
                remainingAmount: remainingAmount,
                tariffId: row.tariff_id?.toString() || '1',
                cottageName: row.cottage_name || '',
                tariff: {
                    name: row.tariff_name || 'Стандартный',
                    pricePerDay: parseFloat(row.price_per_day) || 5000.00
                }
            };
        });
        
        console.log('\n=== Final Response ===');
        bookings.forEach(booking => {
            console.log(`Booking ${booking.id}:`);
            console.log('  startDate (date only):', booking.startDate);
            console.log('  endDate (date only):', booking.endDate);
            console.log('  status:', booking.status);
            console.log('  totalCost:', booking.totalCost);
            console.log('  prepayment:', booking.prepayment);
            console.log('  totalPaid:', booking.totalPaid);
            console.log('  remainingAmount:', booking.remainingAmount);
        });
        console.log('=== Sending to Client ===');
        console.log('Sending bookings:', bookings.length);
        
        res.json(bookings);
    } catch (err) {
        console.error('Error fetching cottage bookings:', err);
        res.status(500).json({ message: 'Error fetching cottage bookings', error: err.message });
    }
});

// Get bookings by cottage (alternative route for frontend compatibility)
router.get('/by-cottage/:cottageId', async (req, res) => {
    console.log(`GET /api/bookings/by-cottage/${req.params.cottageId} - Fetching bookings for cottage`);
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
                b.guests,
                c.name as cottage_name,
                t.name as tariff_name,
                t.price_per_day
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            LEFT JOIN lesbaza.tariffs t ON b.tariff_id = t.tariff_id
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
            status: row.status || 'pending',
            guestName: row.guest_name || '',
            phone: row.phone || '',
            email: row.email || '',
            cottageName: row.cottage_name || '',
            tariff: {
                name: row.tariff_name || 'Стандартный',
                pricePerDay: parseFloat(row.price_per_day) || 5000.00
            }
        }));
        
        res.json(bookings);
    } catch (err) {
        console.error('Error fetching cottage bookings:', err);
        res.status(500).json({ message: 'Error fetching cottage bookings', error: err.message });
    }
});

// Check if a cottage is available for booking
router.get('/check-availability', async (req, res) => {
    try {
        const { startDate, endDate, cottageId } = req.query;
        if (!startDate || !endDate || !cottageId) {
            return res.status(400).json({ message: 'startDate, endDate, and cottageId are required' });
        }

        const result = await checkAvailability(cottageId, startDate, endDate);

        if (result.isBooked) {
            return res.status(400).json({ 
                message: 'Домик занят на выбранные даты',
                conflicts: result.conflicts
            });
        }

        res.json({ isAvailable: true });
    } catch (err) {
        console.error('Error checking availability:', err);
        res.status(500).json({ message: 'Error checking availability', error: err.message });
    }
});

// Get all tariffs
router.get('/tariffs', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT 
                tariff_id,
                name,
                price_per_day
            FROM lesbaza.tariffs 
            ORDER BY tariff_id`
        );

        // Преобразуем данные для Flutter
        const tariffs = rows.map(row => ({
            id: row.tariff_id.toString(),
            name: row.name,
            pricePerDay: parseFloat(row.price_per_day)
        }));

        res.json(tariffs);
    } catch (err) {
        console.error('Error fetching tariffs:', err);
        res.status(500).json({ message: 'Error fetching tariffs', error: err.message });
    }
});

// В routes/bookings.js - исправляем секцию создания бронирования
// Create a new booking with tariff support
router.post('/', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        console.log('\n=== BOOKING CREATION REQUEST ===');
        console.log('Raw request body:', req.body);
        
        const { 
            startDate, 
            endDate, 
            guests, 
            cottageId, 
            guestName, 
            phone, 
            email, 
            tariffId,
            prepayment = 0,
            notes = ''
        } = req.body; 
        
        console.log('Prepayment from request:', prepayment);

        // Validate required fields
        if (!startDate || !endDate || !cottageId || !guestName || !phone) {
            const missingFields = [];
            if (!startDate) missingFields.push('дата заезда');
            if (!endDate) missingFields.push('дата выезда');
            if (!cottageId) missingFields.push('ID домика');
            if (!guestName) missingFields.push('ФИО гостя');
            if (!phone) missingFields.push('телефон');
            
            return res.status(400).json({ 
                message: `Не заполнены обязательные поля: ${missingFields.join(', ')}` 
            });
        }

        // Parse dates - ожидаем ISO строки или даты в формате YYYY-MM-DD
        let parsedStartDate, parsedEndDate;
        try {
            if (startDate.includes('T')) {
                // Если это уже ISO строка с временем
                parsedStartDate = new Date(startDate);
            } else {
                // Если это дата в формате YYYY-MM-DD, добавляем время заезда (14:00 МСК)
                parsedStartDate = new Date(startDate + 'T14:00:00.000+03:00');
            }
            
            if (endDate.includes('T')) {
                // Если это уже ISO строка с временем
                parsedEndDate = new Date(endDate);
            } else {
                // Если это дата в формате YYYY-MM-DD, добавляем время выезда (12:00 МСК)
                parsedEndDate = new Date(endDate + 'T12:00:00.000+03:00');
            }
            
            if (isNaN(parsedStartDate.getTime()) || isNaN(parsedEndDate.getTime())) {
                throw new Error('Invalid date format');
            }

            console.log('\nParsed dates:');
            console.log('Start date (Moscow):', parsedStartDate.toISOString());
            console.log('End date (Moscow):', parsedEndDate.toISOString());
        } catch (error) {
            console.error('Date parsing error:', error);
            return res.status(400).json({
                message: 'Неверный формат даты. Пожалуйста, используйте формат ISO 8601 или YYYY-MM-DD'
            });
        }

        // Проверяем доступность
        const availability = await checkAvailability(cottageId, parsedStartDate.toISOString(), parsedEndDate.toISOString());
        if (availability.isBooked) {
            return res.status(400).json({ 
                message: 'Домик занят на выбранные даты',
                conflicts: availability.conflicts
            });
        }

        // Преобразуем tariffId в число или используем 1 по умолчанию
        const numericTariffId = tariffId ? parseInt(tariffId, 10) : 1;

        // Получаем стоимость тарифа
        const { rows: tariffRows } = await client.query(
            'SELECT price_per_day FROM lesbaza.tariffs WHERE tariff_id = $1',
            [numericTariffId]
        );

        const pricePerDay = tariffRows[0]?.price_per_day || 0;
        const days = Math.ceil((parsedEndDate - parsedStartDate) / (1000 * 60 * 60 * 24));
        const totalCost = pricePerDay * days;

        // Calculate remaining amount
        const prepaymentAmount = parseFloat(prepayment) || 0;
        const remainingAmount = totalCost - prepaymentAmount;

        const { rows } = await client.query(
            `INSERT INTO lesbaza.bookings 
            (cottage_id, guest_name, phone, email, check_in_date, check_out_date, guests, status, tariff_id, total_cost, notes, prepayment, total_paid, created_at) 
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, CURRENT_TIMESTAMP) 
            RETURNING 
                booking_id as id,
                cottage_id,
                guest_name,
                phone,
                email,
                check_in_date,
                check_out_date,
                status,
                guests,
                created_at,
                notes,
                total_cost,
                tariff_id,
                prepayment,
                total_paid`,
            [
                cottageId, 
                guestName.trim(), 
                phone.trim(), 
                email?.trim() || null, 
                parsedStartDate.toISOString(), 
                parsedEndDate.toISOString(), 
                guests || 1, 
                'booked', 
                numericTariffId,
                totalCost,
                notes.trim(),
                prepaymentAmount,
                remainingAmount
            ]
        );
        
        console.log('Booking created with prepayment:', prepaymentAmount, 'and remaining amount:', remainingAmount);
        
        console.log('Booking created with prepayment:', rows[0].prepayment);

        await client.query('COMMIT');

        // Очищаем кэш
        bookingsCache.del(`cottage_${cottageId}`);

        // Возвращаем бронирование с датами в московском времени в формате YYYY-MM-DD
        const checkInDateUTC = new Date(rows[0].check_in_date);
        const checkOutDateUTC = new Date(rows[0].check_out_date);
        
        // Конвертируем в московское время (+3 часа)
        const checkInDateMoscow = new Date(checkInDateUTC.getTime() + 3 * 60 * 60 * 1000);
        const checkOutDateMoscow = new Date(checkOutDateUTC.getTime() + 3 * 60 * 60 * 1000);
        
        const booking = {
            id: rows[0].id?.toString() || '',
            cottageId: rows[0].cottage_id?.toString() || '',
            startDate: checkInDateMoscow.toISOString().split('T')[0],
            endDate: checkOutDateMoscow.toISOString().split('T')[0],
            guests: rows[0].guests || 1,
            status: rows[0].status || 'booked',
            guestName: rows[0].guest_name || '',
            phone: rows[0].phone || '',
            email: rows[0].email || '',
            notes: rows[0].notes || '',
            totalCost: rows[0].total_cost || 0,
            prepayment: parseFloat(rows[0].prepayment) || 0,
            totalPaid: parseFloat(rows[0].total_paid) || 0,
            remainingAmount: (rows[0].total_cost || 0) - (parseFloat(rows[0].total_paid) || 0),
            tariffId: rows[0].tariff_id?.toString() || ''
        };

        console.log('Returning booking with prepayment:', booking.prepayment);
        console.log('\nBooking created successfully:', booking);
        res.status(201).json(booking);
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error creating booking:', err);
        res.status(500).json({ message: 'Error creating booking', error: err.message });
    } finally {
        client.release();
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
                b.guests,
                c.name as cottage_name,
                t.name as tariff_name,
                t.price_per_day
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            LEFT JOIN lesbaza.tariffs t ON b.tariff_id = t.tariff_id
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
            status: rows[0].status || 'pending',
            guests: rows[0].guests || 1,
            cottageName: rows[0].cottage_name || '',
            tariff: {
                name: rows[0].tariff_name || 'Стандартный',
                pricePerDay: parseFloat(rows[0].price_per_day) || 5000.00
            }
        };
        
        res.json(booking);
    } catch (err) {
        console.error('Error fetching booking:', err);
        res.status(500).json({ message: 'Error fetching booking', error: err.message });
    }
});

// Update booking status (check-in, check-out)
router.put('/:id/status', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        const bookingId = req.params.id;
        const { status } = req.body;

        // Если статус становится 'checked_in', сбрасываем остаток (total_paid = total_cost)
        if (status === 'checked_in') {
            // При заселении сбрасываем total_paid в 0
            await client.query(
                'UPDATE lesbaza.bookings SET total_paid = 0 WHERE booking_id = $1',
                [bookingId]
            );
        }

        // Проверяем, что статус допустимый
        const validStatuses = ['booked', 'checked_in', 'checked_out', 'cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({ 
                message: 'Недопустимый статус. Допустимые значения: ' + validStatuses.join(', ') 
            });
        }

        // Получаем текущий статус бронирования
        const { rows: currentBooking } = await client.query(
            'SELECT status FROM lesbaza.bookings WHERE booking_id = $1',
            [bookingId]
        );

        if (currentBooking.length === 0) {
            return res.status(404).json({ message: 'Бронирование не найдено' });
        }

        // Обновляем статус
        const { rows } = await client.query(
            `UPDATE lesbaza.bookings 
            SET status = CAST($1 AS VARCHAR)
            WHERE booking_id = $2
            RETURNING 
                booking_id as id,
                cottage_id,
                guest_name,
                phone,
                email,
                check_in_date as "startDate",
                check_out_date as "endDate",
                status,
                guests,
                created_at,
                notes,
                total_cost,
                tariff_id`,
            [status, bookingId]
        );

        await client.query('COMMIT');

        // Очищаем кэш для этого домика
        invalidateCache(rows[0].cottage_id);

        // Возвращаем обновленное бронирование
        const booking = {
            id: rows[0].id?.toString() || '',
            cottageId: rows[0].cottage_id?.toString() || '',
            startDate: rows[0].startDate,
            endDate: rows[0].endDate,
            guests: rows[0].guests || 1,
            status: rows[0].status,
            guestName: rows[0].guest_name || '',
            phone: rows[0].phone || '',
            email: rows[0].email || '',
            notes: rows[0].notes || '',
            totalCost: rows[0].total_cost || 0,
            tariffId: rows[0].tariff_id
        };
        
        res.json(booking);
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error updating booking status:', err);
        res.status(500).json({ 
            message: 'Ошибка при обновлении статуса бронирования', 
            error: err.message 
        });
    } finally {
        client.release();
    }
});

// DELETE /api/bookings/:id/checkout - завершить бронирование и удалить запись
router.delete('/:id/checkout', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        const bookingId = req.params.id;

        // Delete the booking
        await client.query(
            'DELETE FROM lesbaza.bookings WHERE booking_id = $1',
            [bookingId]
        );

        await client.query('COMMIT');
        invalidateCache();
        res.json({ message: 'Booking completed and removed successfully' });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error completing booking:', err);
        res.status(500).json({ message: 'Error completing booking', error: err.message });
    } finally {
        client.release();
    }
});

router.delete('/tariffs/:id', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // Проверяем, используется ли тариф в бронированиях
        const { rows: bookings } = await client.query(
            'SELECT COUNT(*) as count FROM lesbaza.bookings WHERE tariff_id = $1',
            [req.params.id]
        );

        if (bookings[0].count > 0) {
            await client.query('ROLLBACK');
            return res.status(400).json({ 
                message: 'Невозможно удалить тариф, так как он используется в существующих бронированиях. Сначала измените тариф в этих бронированиях.' 
            });
        }

        const { rowCount } = await client.query(
            'DELETE FROM lesbaza.tariffs WHERE tariff_id = $1',
            [req.params.id]
        );

        if (rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Тариф не найден' });
        }

        await client.query('COMMIT');
        res.status(204).send();
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error deleting tariff:', err);
        res.status(500).json({ message: 'Ошибка при удалении тарифа', error: err.message });
    } finally {
        client.release();
    }
});

module.exports = router;

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
                b.guests,
                c.name as cottage_name,
                t.name as tariff_name,
                t.price_per_day
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            LEFT JOIN lesbaza.tariffs t ON b.tariff_id = t.tariff_id
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
            cottageName: rows[0].cottage_name || '',
            tariff: {
                name: rows[0].tariff_name || 'Стандартный',
                pricePerDay: parseFloat(rows[0].price_per_day) || 5000.00
            }
        };
        
        res.json(booking);
    } catch (err) {
        console.error('Error fetching booking:', err);
        res.status(500).json({ message: 'Error fetching booking', error: err.message });
    }
});

// Cancel a booking
router.delete('/:id', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { rows } = await client.query(
            'DELETE FROM lesbaza.bookings WHERE booking_id = $1 RETURNING cottage_id',
            [req.params.id]
        );

        if (rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Booking not found' });
        }

        await client.query('COMMIT');

        // Очищаем кэш
        invalidateCache(rows[0].cottage_id);

        res.status(204).send();
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error deleting booking:', err);
        res.status(500).json({ message: 'Error deleting booking', error: err.message });
    } finally {
        client.release();
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
                    check_in_date::date,
                    check_out_date::date - INTERVAL '1 day',
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

// Get bookings by date
router.get('/cottage/:cottageId/date/:date', async (req, res) => {
    try {
        console.log(`\n=== GET /api/bookings/cottage/${req.params.cottageId}/date/${req.params.date} ===`);
        console.log('Request date:', req.params.date);
        
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
                b.guests,
                b.notes,
                b.total_cost,
                b.prepayment,
                b.total_paid,
                b.tariff_id,
                c.name as cottage_name 
            FROM lesbaza.bookings b 
            JOIN lesbaza.cottages c ON b.cottage_id = c.cottage_id 
            WHERE b.cottage_id = $1 
            AND b.status != 'cancelled'
            AND DATE($2) >= DATE(b.check_in_date)
            AND DATE($2) < DATE(b.check_out_date)
            ORDER BY b.check_in_date DESC`,
            [req.params.cottageId, req.params.date]
        );
        
        console.log('\n=== Database Results ===');
        console.log('Found bookings:', rows.length);
        rows.forEach(row => {
            console.log(`Booking ${row.id}:`);
            console.log('  check_in_date:', row.check_in_date);
            console.log('  check_out_date:', row.check_out_date);
            console.log('  status:', row.status);
            console.log('  total_cost:', row.total_cost);
            console.log('  prepayment:', row.prepayment);
            console.log('  total_paid:', row.total_paid);
        });
        
        // Преобразуем данные, правильно конвертируя UTC в московское время
        const bookings = rows.map(row => {
            // Конвертируем UTC даты в московское время
            const checkInDateUTC = new Date(row.check_in_date);
            const checkOutDateUTC = new Date(row.check_out_date);
            
            // Добавляем 3 часа для московского времени
            const checkInDateMoscow = new Date(checkInDateUTC.getTime() + 3 * 60 * 60 * 1000);
            const checkOutDateMoscow = new Date(checkOutDateUTC.getTime() + 3 * 60 * 60 * 1000);
            
            // Извлекаем только дату в формате YYYY-MM-DD
            const checkInDateOnly = checkInDateMoscow.toISOString().split('T')[0];
            const checkOutDateOnly = checkOutDateMoscow.toISOString().split('T')[0];
            
            // Рассчитываем суммы
            const totalCost = parseFloat(row.total_cost || 0);
            const prepayment = parseFloat(row.prepayment || 0);
            const totalPaid = parseFloat(row.total_paid || 0);
            const remainingAmount = totalCost - totalPaid;
            
            return {
                id: row.id?.toString() || '',
                cottageId: row.cottage_id?.toString() || '',
                startDate: checkInDateOnly,
                endDate: checkOutDateOnly,
                guests: row.guests || 1,
                status: row.status || 'booked',
                guestName: row.guest_name || '',
                phone: row.phone || '',
                email: row.email || '',
                notes: row.notes || '',
                totalCost: totalCost,
                prepayment: prepayment,
                totalPaid: totalPaid,
                remainingAmount: remainingAmount,
                tariffId: row.tariff_id?.toString() || '1',
                cottageName: row.cottage_name || ''
            };
        });
        
        console.log('\n=== Final Response ===');
        bookings.forEach(booking => {
            console.log(`Booking ${booking.id}:`);
            console.log('  startDate:', booking.startDate);
            console.log('  endDate:', booking.endDate);
            console.log('  status:', booking.status);
            console.log('  payment info:', {
                totalCost: booking.totalCost,
                prepayment: booking.prepayment,
                totalPaid: booking.totalPaid,
                remainingAmount: booking.remainingAmount
            });
        });
        
        res.json(bookings);
    } catch (err) {
        console.error('Error fetching bookings by date:', err);
        res.status(500).json({ message: 'Error fetching bookings', error: err.message });
    }
});

// Update booking status (check-in, check-out)
router.put('/:id/status', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        const { status } = req.body;
        const bookingId = req.params.id;
        
        // Проверяем, что статус допустимый
        const validStatuses = ['booked', 'checked_in', 'checked_out', 'cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({ 
                message: 'Недопустимый статус. Допустимые значения: ' + validStatuses.join(', ') 
            });
        }

        // Получаем текущий статус бронирования
        const { rows: currentBooking } = await client.query(
            'SELECT status FROM lesbaza.bookings WHERE booking_id = $1',
            [bookingId]
        );

        if (currentBooking.length === 0) {
            return res.status(404).json({ message: 'Бронирование не найдено' });
        }

        // Обновляем статус
        const { rows } = await client.query(
            `UPDATE lesbaza.bookings 
            SET status = CAST($1 AS VARCHAR)
            WHERE booking_id = $2
            RETURNING 
                booking_id as id,
                cottage_id,
                guest_name,
                phone,
                email,
                check_in_date as "startDate",
                check_out_date as "endDate",
                status,
                guests,
                created_at,
                notes,
                total_cost,
                tariff_id`,
            [status, bookingId]
        );

        await client.query('COMMIT');

        // Очищаем кэш для этого домика
        invalidateCache(rows[0].cottage_id);

        // Возвращаем обновленное бронирование
        const booking = {
            id: rows[0].id?.toString() || '',
            cottageId: rows[0].cottage_id?.toString() || '',
            startDate: rows[0].startDate,
            endDate: rows[0].endDate,
            guests: rows[0].guests || 1,
            status: rows[0].status,
            guestName: rows[0].guest_name || '',
            phone: rows[0].phone || '',
            email: rows[0].email || '',
            notes: rows[0].notes || '',
            totalCost: rows[0].total_cost || 0,
            tariffId: rows[0].tariff_id
        };
        
        res.json(booking);
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error updating booking status:', err);
        res.status(500).json({ 
            message: 'Ошибка при обновлении статуса бронирования', 
            error: err.message 
        });
    } finally {
        client.release();
    }
});

router.put('/tariffs/:id', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { name, pricePerDay } = req.body;
        const { rows } = await client.query(
            `UPDATE lesbaza.tariffs 
            SET name = $1, price_per_day = $2
            WHERE tariff_id = $3
            RETURNING tariff_id`,
            [name, pricePerDay, req.params.id]
        );

        if (rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Tariff not found' });
        }

        await client.query('COMMIT');

        res.json({
            id: rows[0].tariff_id.toString(),
            name,
            pricePerDay
        });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error updating tariff:', err);
        res.status(500).json({ message: 'Error updating tariff', error: err.message });
    } finally {
        client.release();
    }
});

// DELETE /api/bookings/tariffs/:id - удалить тариф
router.delete('/tariffs/:id', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // Проверяем, используется ли тариф в бронированиях
        const { rows: bookings } = await client.query(
            'SELECT COUNT(*) as count FROM lesbaza.bookings WHERE tariff_id = $1',
            [req.params.id]
        );

        if (bookings[0].count > 0) {
            await client.query('ROLLBACK');
            return res.status(400).json({ 
                message: 'Невозможно удалить тариф, так как он используется в существующих бронированиях. Сначала измените тариф в этих бронированиях.' 
            });
        }

        const { rowCount } = await client.query(
            'DELETE FROM lesbaza.tariffs WHERE tariff_id = $1',
            [req.params.id]
        );

        if (rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Тариф не найден' });
        }

        await client.query('COMMIT');
        res.status(204).send();
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error deleting tariff:', err);
        res.status(500).json({ message: 'Ошибка при удалении тарифа', error: err.message });
    } finally {
        client.release();
    }
});

// DELETE /api/bookings/:id/checkout - завершить бронирование и удалить запись
router.delete('/:id/checkout', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        const bookingId = req.params.id;

        // Delete the booking
        await client.query(
            'DELETE FROM lesbaza.bookings WHERE booking_id = $1',
            [bookingId]
        );

        await client.query('COMMIT');
        invalidateCache();
        res.json({ message: 'Booking completed and removed successfully' });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error completing booking:', err);
        res.status(500).json({ message: 'Error completing booking', error: err.message });
    } finally {
        client.release();
    }
});

module.exports = router;