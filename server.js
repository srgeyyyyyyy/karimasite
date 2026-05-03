const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const { Pool } = require('pg');

// Инициализация Express
const app = express();
const PORT = process.env.PORT || 3001;

// Настройка подключения к PostgreSQL
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'karima_restaurant',
  password: process.env.DB_PASSWORD || 'password',
  port: process.env.DB_PORT || 5432,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Middleware
app.use(helmet());
app.use(compression());
app.use(morgan('combined'));
app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://127.0.0.1:5500',
    'http://localhost:5500',
    'file://',
    'null'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 минут
  max: 100, // максимум 100 запросов
  message: 'Слишком много запросов, попробуйте позже'
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Статические файлы
app.use(express.static(path.join(__dirname, 'public')));

// Проверка подключения к базе данных
async function checkDatabaseConnection() {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    console.log('✅ Подключение к PostgreSQL успешно');
    console.log('📅 Время базы данных:', result.rows[0].now);
    return true;
  } catch (error) {
    console.error('❌ Ошибка подключения к PostgreSQL:', error.message);
    return false;
  }
}

// Middleware для проверки подключения к БД
app.use(async (req, res, next) => {
  try {
    const client = await pool.connect();
    req.db = client;
    next();
  } catch (error) {
    console.error('Ошибка подключения к базе данных:', error);
    res.status(500).json({ 
      error: 'Ошибка подключения к базе данных',
      message: 'Сервер временно недоступен'
    });
  }
});

// Освобождение подключения после обработки запроса
app.use((req, res, next) => {
  const originalSend = res.send;
  res.send = function(data) {
    if (req.db) {
      req.db.release();
    }
    originalSend.call(this, data);
  };
  next();
});

// API Routes
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Аутентификация
const authRoutes = require('./routes/auth');
app.use('/api/auth', authRoutes);

// Упрощенные роуты для быстрого запуска
const reservationRoutes = require('./routes/reservations_simple');
app.use('/api/reservations', reservationRoutes);

const menuRoutes = require('./routes/menu_simple');
app.use('/api/menu', menuRoutes);

const locationRoutes = require('./routes/locations_simple');
app.use('/api/locations', locationRoutes);

const statsRoutes = require('./routes/stats_simple');
app.use('/api/stats', statsRoutes);

// Обработка ошибок
app.use((err, req, res, next) => {
  console.error('Ошибка:', err.stack);
  
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({
      error: 'Неверный формат JSON',
      message: 'Проверьте корректность отправляемых данных'
    });
  }
  
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' ? 'Внутренняя ошибка сервера' : err.message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  });
});

// 404
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Маршрут не найден',
    message: `Маршрут ${req.method} ${req.originalUrl} не существует`
  });
});

// Запуск сервера
async function startServer() {
  try {
    const dbConnected = await checkDatabaseConnection();
    
    if (!dbConnected) {
      console.log('⚠️  Сервер запускается без подключения к базе данных');
    }
    
    app.listen(PORT, () => {
      console.log(`🚀 Сервер запущен на порту ${PORT}`);
      console.log(`📍 API доступен по адресу: http://localhost:${PORT}/api`);
      console.log(`🏥 Проверка здоровья: http://localhost:${PORT}/api/health`);
      
      if (process.env.NODE_ENV === 'development') {
        console.log('🔧 Режим разработки');
        console.log('📊 Swagger документация: http://localhost:' + PORT + '/api-docs');
      }
    });
  } catch (error) {
    console.error('❌ Ошибка запуска сервера:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🔄 Получен SIGTERM, graceful shutdown...');
  
  try {
    await pool.end();
    console.log('✅ Подключения к базе данных закрыты');
    process.exit(0);
  } catch (error) {
    console.error('❌ Ошибка при закрытии подключений:', error);
    process.exit(1);
  }
});

process.on('SIGINT', async () => {
  console.log('🔄 Получен SIGINT, graceful shutdown...');
  
  try {
    await pool.end();
    console.log('✅ Подключения к базе данных закрыты');
    process.exit(0);
  } catch (error) {
    console.error('❌ Ошибка при закрытии подключений:', error);
    process.exit(1);
  }
});

// Запуск
startServer();

module.exports = app;
