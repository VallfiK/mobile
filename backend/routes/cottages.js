const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const NodeCache = require('node-cache');

// Создаем кэш с временем жизни 5 минут
const cottagesCache = new NodeCache({ stdTTL: 300 });

// PostgreSQL connection configuration
const pool = new Pool({
    connectionString: 'postgres://postgres:L0kijuhy!@192.168.0.104:5432/BD_LesBaza?sslmode=disable',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// GET /api/cottages - получить список всех коттеджей
router.get('/', async (req, res) => {
    console.log('GET /api/cottages - Fetching all cottages');
    try {
        // Проверяем кэш
        const cachedCottages = cottagesCache.get('all_cottages');
        if (cachedCottages) {
            console.log('Returning cached cottages');
            return res.json(cachedCottages);
        }

        console.log('Cache miss, querying database...');
        const client = await pool.connect();
        try {
            const query = `
                SELECT 
                    cottage_id,
                    name,
                    description,
                    status,
                    images
                FROM lesbaza.cottages 
                ORDER BY cottage_id`;
            
            console.log('Executing query:', query);
            const { rows } = await client.query(query);
            console.log('Query result:', rows);

            // Преобразуем данные для Flutter
            const cottages = rows.map(row => ({
                id: row.cottage_id?.toString() || '',
                name: row.name || '',
                description: row.description || '',
                status: row.status || 'free',
                images: row.images || []
            }));

            console.log('Transformed cottages:', cottages);
            
            // Сохраняем в кэш
            cottagesCache.set('all_cottages', cottages);
            
            res.json(cottages);
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Error fetching cottages:', err);
        res.status(500).json({ message: 'Error fetching cottages', error: err.message });
    }
});

// GET /api/cottages/:id - получить конкретный коттедж
router.get('/:id', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT 
                cottage_id,
                name,
                description,
                status,
                images
            FROM lesbaza.cottages 
            WHERE cottage_id = $1`,
            [req.params.id]
        );

        if (rows.length === 0) {
            return res.status(404).json({ message: 'Cottage not found' });
        }

        const cottage = {
            id: rows[0].cottage_id?.toString() || '',
            name: rows[0].name || '',
            description: rows[0].description || '',
            status: rows[0].status || 'free',
            images: rows[0].images || []
        };

        res.json(cottage);
    } catch (err) {
        console.error('Error fetching cottage:', err);
        res.status(500).json({ message: 'Error fetching cottage', error: err.message });
    }
});

// POST /api/cottages - создать новый коттедж
router.post('/', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { name, description, status } = req.body;
        const { rows } = await client.query(
            `INSERT INTO lesbaza.cottages 
            (name, description, status) 
            VALUES ($1, $2, $3) 
            RETURNING cottage_id`,
            [name, description, status || 'free']
        );

        await client.query('COMMIT');

        // Очищаем кэш
        cottagesCache.del('all_cottages');

        res.status(201).json({
            id: rows[0].cottage_id.toString(),
            name,
            description,
            status: status || 'free'
        });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error creating cottage:', err);
        res.status(500).json({ message: 'Error creating cottage', error: err.message });
    } finally {
        client.release();
    }
});

// PUT /api/cottages/:id - обновить коттедж
router.put('/:id', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { name, description, status, images } = req.body;
        const { rows } = await client.query(
            `UPDATE lesbaza.cottages 
            SET name = $1, description = $2, status = $3, images = $4
            WHERE cottage_id = $5
            RETURNING cottage_id`,
            [name, description, status, images, req.params.id]
        );

        if (rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Cottage not found' });
        }

        await client.query('COMMIT');

        // Очищаем кэш
        cottagesCache.del('all_cottages');

        res.json({
            id: rows[0].cottage_id.toString(),
            name,
            description,
            status,
            images
        });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error updating cottage:', err);
        res.status(500).json({ message: 'Error updating cottage', error: err.message });
    } finally {
        client.release();
    }
});

// DELETE /api/cottages/:id - удалить коттедж
router.delete('/:id', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { rowCount } = await client.query(
            'DELETE FROM lesbaza.cottages WHERE cottage_id = $1',
            [req.params.id]
        );

        if (rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Cottage not found' });
        }

        await client.query('COMMIT');

        // Очищаем кэш
        cottagesCache.del('all_cottages');

        res.status(204).send();
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error deleting cottage:', err);
        res.status(500).json({ message: 'Error deleting cottage', error: err.message });
    } finally {
        client.release();
    }
});

// Add description column if it doesn't exist
router.post('/init-description', async (req, res) => {
    try {
        await pool.query(`
            DO $$ 
            BEGIN 
                IF NOT EXISTS (
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_schema = 'lesbaza' 
                    AND table_name = 'cottages' 
                    AND column_name = 'description'
                ) THEN 
                    ALTER TABLE lesbaza.cottages 
                    ADD COLUMN description TEXT;
                END IF;
            END $$;
        `);
        res.json({ message: 'Description column added successfully' });
    } catch (error) {
        console.error('Error adding description column:', error);
        res.status(500).json({ error: 'Failed to add description column' });
    }
});

// Add images column if it doesn't exist
router.post('/init-images', async (req, res) => {
    try {
        await pool.query(`
            DO $$ 
            BEGIN 
                IF NOT EXISTS (
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_schema = 'lesbaza' 
                    AND table_name = 'cottages' 
                    AND column_name = 'images'
                ) THEN 
                    ALTER TABLE lesbaza.cottages 
                    ADD COLUMN images TEXT[];
                END IF;
            END $$;
        `);
        res.json({ message: 'Images column added successfully' });
    } catch (error) {
        console.error('Error adding images column:', error);
        res.status(500).json({ error: 'Failed to add images column' });
    }
});

module.exports = router;