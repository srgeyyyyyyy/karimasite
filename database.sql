-- Karima Restaurant Database Schema
-- PostgreSQL Database

-- Создание базы данных (если нужно)
-- CREATE DATABASE karima_restaurant;

-- Подключение к базе
-- \c karima_restaurant;

-- Включение расширения для UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Таблица пользователей (администраторы)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'admin' CHECK (role IN ('admin', 'manager', 'staff')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица филиалов ресторана
CREATE TABLE IF NOT EXISTS locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    hours TEXT NOT NULL,
    parking_info TEXT,
    coordinates_lat DECIMAL(10, 8),
    coordinates_lng DECIMAL(11, 8),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица категорий меню
CREATE TABLE IF NOT EXISTS menu_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL,
    description TEXT,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица позиций меню
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES menu_categories(id) ON DELETE SET NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    image_url TEXT,
    preparation_time INTEGER, -- в минутах
    is_spicy BOOLEAN DEFAULT false,
    is_vegetarian BOOLEAN DEFAULT false,
    allergens TEXT, -- JSON массив аллергенов
    nutritional_info TEXT, -- JSON информация о питательности
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица бронирований
CREATE TABLE IF NOT EXISTS reservations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    location_id UUID REFERENCES locations(id) ON DELETE RESTRICT,
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    customer_email VARCHAR(100),
    reservation_date DATE NOT NULL,
    reservation_time TIME NOT NULL,
    guest_count INTEGER NOT NULL CHECK (guest_count > 0 AND guest_count <= 50),
    occasion VARCHAR(50), -- повод: день рождения, деловая встреча и т.д.
    special_requests TEXT,
    status VARCHAR(20) DEFAULT 'new' CHECK (status IN ('new', 'confirmed', 'cancelled', 'completed', 'no_show')),
    table_number VARCHAR(10),
    server_name VARCHAR(100), -- официант
    notes TEXT, -- внутренние заметки персонала
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица отзывов
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    location_id UUID REFERENCES locations(id) ON DELETE SET NULL,
    customer_name VARCHAR(100) NOT NULL,
    customer_email VARCHAR(100),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    visit_date DATE,
    would_recommend BOOLEAN,
    service_rating INTEGER CHECK (service_rating >= 1 AND service_rating <= 5),
    food_rating INTEGER CHECK (food_rating >= 1 AND food_rating <= 5),
    ambiance_rating INTEGER CHECK (ambiance_rating >= 1 AND ambiance_rating <= 5),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    admin_response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица заказов (для будущего расширения)
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reservation_id UUID REFERENCES reservations(id) ON DELETE SET NULL,
    location_id UUID REFERENCES locations(id) ON DELETE RESTRICT,
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    order_type VARCHAR(20) DEFAULT 'dine_in' CHECK (order_type IN ('dine_in', 'takeaway', 'delivery')),
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    payment_method VARCHAR(20) CHECK (payment_method IN ('cash', 'card', 'mobile')),
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'refunded')),
    status VARCHAR(20) DEFAULT 'new' CHECK (status IN ('new', 'preparing', 'ready', 'completed', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица позиций заказа
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID REFERENCES menu_items(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    special_instructions TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица сессий администраторов
CREATE TABLE IF NOT EXISTS admin_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица логов действий
CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(50),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Индексы для оптимизации производительности
CREATE INDEX IF NOT EXISTS idx_reservations_date ON reservations(reservation_date);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_reservations_location_date ON reservations(location_id, reservation_date);
CREATE INDEX IF NOT EXISTS idx_reviews_status ON reviews(status);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_active ON menu_items(is_active);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_token ON admin_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_expires ON admin_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created ON activity_logs(created_at);

-- Триггеры для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Применение триггера к таблицам
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_locations_updated_at BEFORE UPDATE ON locations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_menu_items_updated_at BEFORE UPDATE ON menu_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_reservations_updated_at BEFORE UPDATE ON reservations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Политика безопасности (Row Level Security)
-- Включаем RLS для важных таблиц
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Создаем базового администратора
INSERT INTO users (username, email, password_hash, role) 
VALUES ('admin', 'admin@karima.kz', '$2a$10$ckgTpMDCP68z.zrUBRExN.UQD3rpBLPBEXJWHQf0PBqECTzr05hQW', 'admin')
ON CONFLICT (username) DO NOTHING;

-- Добавляем филиалы
INSERT INTO locations (name, address, phone, email, hours, parking_info) VALUES
('Флагманский', 'Достык, 12/1 (ТРЦ Керуен)', '+7 700 883 00 00', 'flagship@karima.kz', 'Круглосуточно', '24 парковки'),
('Есиль', 'Мангилик Ел, 54', '+7 700 883 00 01', 'esil@karima.kz', 'Ежедневно 10:00-23:00', '12 парковок'),
('Левый берег', 'Мангилик Ел, 29/2', '+7 700 883 00 02', 'leftbank@karima.kz', 'Ежедневно 10:00-01:00', '15 парковок'),
('Сатпаев', 'Каныш Сатпаев, 20', '+7 700 883 00 03', 'satpaev@karima.kz', 'Ежедневно 10:00-23:00', '8 парковок'),
('Омаров', 'Илияс Омаров, 17/1', '+7 700 883 00 04', 'omarov@karima.kz', 'Ежедневно 10:00-23:00', '10 парковок'),
('Дукенулы', 'Ыкылас Дукенулы, 22', '+7 700 883 00 05', 'dukenuly@karima.kz', 'Ежедневно 10:00-23:00', '6 парковок')
ON CONFLICT DO NOTHING;

-- Добавляем категории меню
INSERT INTO menu_categories (name, description, display_order) VALUES
('Плов', 'Традиционные узбекские пловы', 1),
('Горячее', 'Основные блюда', 2),
('Шашлыки', 'Мясо на мангале', 3),
('Лагман', 'Азиатская лапша', 4),
('Турецкое Пиде', 'Турецкая выпечка', 5),
('Салаты', 'Свежие салаты', 6),
('Напитки', 'Безалкогольные напитки', 7),
('Десерты', 'Сладости', 8)
ON CONFLICT DO NOTHING;

-- Добавляем позиции меню
INSERT INTO menu_items (category_id, name, description, price, preparation_time, display_order) VALUES
((SELECT id FROM menu_categories WHERE name = 'Плов'), 'Ташкентский плов', 'Длиннозерновой рис, нут, изюм, сладкая морковь с говядиной и бараниной', 2590.00, 25, 1),
((SELECT id FROM menu_categories WHERE name = 'Плов'), 'Ханский плов', 'Праздничный плов с казы', 2990.00, 30, 2),
((SELECT id FROM menu_categories WHERE name = 'Горячее'), 'Казан Кебаб', 'Нежные кусочки мяса с румяной корочкой', 3490.00, 20, 1),
((SELECT id FROM menu_categories WHERE name = 'Горячее'), 'Манты с говядиной', 'Традиционные манты с ароматной начинкой', 2390.00, 15, 2),
((SELECT id FROM menu_categories WHERE name = 'Шашлыки'), 'Шашлык из баранины', 'Важнейший продукт национальных кухонь', 2690.00, 25, 1),
((SELECT id FROM menu_categories WHERE name = 'Шашлыки'), 'Люля Кебаб', 'Мясное блюдо кавказской и азиатской кухни', 2390.00, 20, 2),
((SELECT id FROM menu_categories WHERE name = 'Лагман'), 'Гуйру Лагман', 'Домашняя лапша под соусом из тушёных овощей с мясом', 2490.00, 18, 1),
((SELECT id FROM menu_categories WHERE name = 'Турецкое Пиде'), 'Пиде с мясом 100 см', 'Лодочка с нежным мясом, запечённая в печи', 3290.00, 22, 1)
ON CONFLICT DO NOTHING;

-- Создаем view для статистики
CREATE OR REPLACE VIEW reservation_stats AS
SELECT 
    DATE_TRUNC('day', r.created_at) as date,
    COUNT(*) as total_reservations,
    COUNT(CASE WHEN r.status = 'confirmed' THEN 1 END) as confirmed_reservations,
    COUNT(CASE WHEN r.status = 'cancelled' THEN 1 END) as cancelled_reservations,
    SUM(r.guest_count) as total_guests,
    AVG(r.guest_count) as avg_guests,
    l.name as location_name
FROM reservations r
LEFT JOIN locations l ON r.location_id = l.id
GROUP BY DATE_TRUNC('day', r.created_at), l.name
ORDER BY date DESC;

-- Создаем view для рейтингов
CREATE OR REPLACE VIEW location_ratings AS
SELECT 
    l.id as location_id,
    l.name as location_name,
    COUNT(r.id) as review_count,
    AVG(r.rating) as avg_rating,
    AVG(r.service_rating) as avg_service_rating,
    AVG(r.food_rating) as avg_food_rating,
    AVG(r.ambiance_rating) as avg_ambiance_rating
FROM locations l
LEFT JOIN reviews r ON l.id = r.location_id AND r.status = 'approved'
GROUP BY l.id, l.name
ORDER BY avg_rating DESC;

COMMENT ON TABLE users IS 'Пользователи системы (администраторы)';
COMMENT ON TABLE locations IS 'Филиалы ресторана';
COMMENT ON TABLE menu_categories IS 'Категории меню';
COMMENT ON TABLE menu_items IS 'Позиции меню';
COMMENT ON TABLE reservations IS 'Бронирования столиков';
COMMENT ON TABLE reviews IS 'Отзывы посетителей';
COMMENT ON TABLE orders IS 'Заказы';
COMMENT ON TABLE order_items IS 'Позиции заказов';
COMMENT ON TABLE admin_sessions IS 'Сессии администраторов';
COMMENT ON TABLE activity_logs IS 'Лог действий пользователей';

-- Права доступа
-- GRANT CONNECT ON DATABASE karima_restaurant TO karima_user;
-- GRANT USAGE ON SCHEMA public TO karima_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO karima_user;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO karima_user;
