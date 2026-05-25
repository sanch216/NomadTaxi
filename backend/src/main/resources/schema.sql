-- 1. Таблица пользователей (переименована во избежание конфликтов)
CREATE TABLE IF NOT EXISTS app_users (
    id BIGSERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    role VARCHAR(20) NOT NULL, -- 'CLIENT', 'DRIVER'
    rating DOUBLE PRECISION DEFAULT 0.0,
    rating_count INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Детали водителей (Связь 1-к-1 с users)
CREATE TABLE IF NOT EXISTS driver_details (
    user_id BIGINT PRIMARY KEY REFERENCES app_users(id),
    car_model VARCHAR(50) NOT NULL,
    car_number VARCHAR(20) NOT NULL,
    car_class VARCHAR(20) NOT NULL, -- 'ECONOMY', 'COMFORT', 'BUSINESS'
    status VARCHAR(20) NOT NULL,    -- 'OFFLINE', 'AVAILABLE', 'BUSY'
    current_lat DOUBLE PRECISION,
    current_lon DOUBLE PRECISION
);

-- Индекс для быстрого поиска свободных водителей
CREATE INDEX IF NOT EXISTS idx_driver_status ON driver_details(status);

-- 3. Таблица поездок
CREATE TABLE IF NOT EXISTS rides (
    id BIGSERIAL PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES app_users(id),
    driver_id BIGINT REFERENCES app_users(id),
    status VARCHAR(20) NOT NULL, -- 'SEARCHING', 'ACCEPTED', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
    pickup_address VARCHAR(255) NOT NULL,
    pickup_lat DOUBLE PRECISION NOT NULL,
    pickup_lon DOUBLE PRECISION NOT NULL,
    dropoff_address VARCHAR(255) NOT NULL,
    dropoff_lat DOUBLE PRECISION NOT NULL,
    dropoff_lon DOUBLE PRECISION NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    requested_car_class VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    version BIGINT DEFAULT 0 -- Для Optimistic Locking (защита от двойного взятия заказа)
);

-- Индекс, чтобы быстро находить активные заказы
CREATE INDEX IF NOT EXISTS idx_ride_status ON rides(status);

-- 4. Таблица заработка водителей (добавлено для Earnings Module)
CREATE TABLE IF NOT EXISTS driver_earnings (
    id BIGSERIAL PRIMARY KEY,
    driver_id BIGINT NOT NULL,
    ride_id BIGINT NOT NULL UNIQUE,
    total_amount DECIMAL(10, 2) NOT NULL,
    driver_share DECIMAL(10, 2) NOT NULL,
    platform_fee DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_driver_earnings_ride FOREIGN KEY (ride_id) REFERENCES rides(id),
    CONSTRAINT fk_driver_earnings_driver FOREIGN KEY (driver_id) REFERENCES app_users(id)
);

-- Индекс для быстрого подсчета заработка за период
CREATE INDEX IF NOT EXISTS idx_driver_earnings_driver_date ON driver_earnings(driver_id, created_at);
