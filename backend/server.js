require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
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

// PostgreSQL connection configuration
const pool = new Pool({
    connectionString: 'postgres://postgres:L0kijuhy!@192.168.0.104:5432/BD_LesBaza?sslmode=disable'
});

// Test the connection
pool.query('SELECT NOW()')
    .then(() => console.log('Connected to PostgreSQL'))
    .catch(err => console.error('Error connecting to PostgreSQL:', err));

// Routes
app.use('/api/bookings', require('./routes/bookings'));
app.use('/api/cottages', require('./routes/cottages'));

// Handle preflight requests
app.options('*', cors());

// Set up server to listen on all interfaces
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
});
