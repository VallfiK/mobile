require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 8080; // Фиксированный порт

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

// Роуты
app.get('/api/apiping', (req, res) => {
    console.log('Ping request received');
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
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
    res.json({ message: 'API is running' });
});

// Обработка 404
app.use((req, res) => {
    res.status(404).json({ message: 'Route not found' });
});

// Обработчик ошибок
app.use((err, req, res, next) => {
    console.error('Server error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

// Запуск сервера с обработкой ошибок порта
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
    console.log(`API endpoints available at http://0.0.0.0:${PORT}/api`);
    console.log('Public IP: 178.234.13.110');
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