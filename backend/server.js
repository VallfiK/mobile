require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 8081; // Changed back to port 8080

// Middleware
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Логирование запросов
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Ping routes
app.get('/api/ping', (req, res) => {
    console.log('Ping request received at /api/ping');
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/api/apiping', (req, res) => {
    console.log('Ping request received at /api/apiping');
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Health check route
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', uptime: process.uptime() });
});

// Подключаем роутеры
const cottagesRouter = require('./routes/cottages');
const bookingsRouter = require('./routes/bookings');

app.use('/api/cottages', cottagesRouter);
app.use('/api/bookings', bookingsRouter);

// Calendar route
app.get('/api/calendar/:cottageId/:startDate/:endDate', async (req, res) => {
    try {
        // ... ваша реализация
        res.json({ message: 'Calendar endpoint' }); // временная заглушка
    } catch (err) {
        console.error('Error in calendar:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Тестовый роут
app.get('/', (req, res) => {
    res.json({ 
        message: 'API is running',
        endpoints: {
            ping: '/api/ping',
            apiping: '/api/apiping',
            health: '/health',
            cottages: '/api/cottages',
            bookings: '/api/bookings',
            calendar: '/api/calendar/:cottageId/:startDate/:endDate'
        }
    });
});

// Обработка OPTIONS запросов для CORS
app.options('*', cors());

// Обработка 404
app.use((req, res) => {
    console.log(`404 - Route not found: ${req.method} ${req.url}`);
    res.status(404).json({ 
        message: 'Route not found',
        requestedUrl: req.url,
        method: req.method,
        availableEndpoints: {
            ping: '/api/ping',
            apiping: '/api/apiping',
            health: '/health',
            cottages: '/api/cottages',
            bookings: '/api/bookings',
            calendar: '/api/calendar/:cottageId/:startDate/:endDate'
        }
    });
});

// Обработчик ошибок
app.use((err, req, res, next) => {
    console.error('Server error:', err);
    res.status(500).json({ 
        error: 'Internal server error',
        message: err.message,
        path: req.url
    });
});

// Запуск сервера с обработкой ошибок порта
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
    console.log(`API endpoints available at http://0.0.0.0:${PORT}/api`);
    console.log('Available endpoints:');
    console.log('- GET /api/ping');
    console.log('- GET /api/apiping');
    console.log('- GET /health');
    console.log('- GET /api/cottages');
    console.log('- GET /api/bookings');
    console.log('Public IP: 178.234.13.110');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received. Shutting down gracefully...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});

server.on('error', error => {
    if (error.code === 'EADDRINUSE') {
        console.error(`⚠️ Port ${PORT} is already in use!`);
        console.error('Please try one of these solutions:');
        console.log('1. Find and kill the process:');
        console.log(`   netstat -ano | findstr :${PORT}`);
        console.log('   taskkill /PID <PID> /F');
        console.log('2. Change PORT value in your code');
        console.log('3. Wait 1-2 minutes for the OS to release the port');
    } else {
        console.error('Server error:', error);
    }
    process.exit(1);
});