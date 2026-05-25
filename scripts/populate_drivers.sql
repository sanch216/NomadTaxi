-- Очистка старых мок-данных
DELETE FROM driver_details WHERE user_id IN (SELECT id FROM app_users WHERE phone LIKE '7773%');
DELETE FROM app_users WHERE phone LIKE '7773%';

DO $$
DECLARE
    uid1 INT; uid2 INT; uid3 INT; uid4 INT; uid5 INT;
    pass TEXT := '$2a$10$8.UnVuG9HHgffUDAlk8qfOuVGkqRzgVymGe07xdqD1RphLqcSota.'; -- 'password123'
BEGIN
    -- Создаем пользователей-водителей (Бишкек)
    INSERT INTO app_users (phone, password, full_name, role, rating, rating_count, created_at)
    VALUES ('7773001', pass, 'Азамат (Эконом)', 'DRIVER', 4.9, 10, NOW()) RETURNING id INTO uid1;
    
    INSERT INTO app_users (phone, password, full_name, role, rating, rating_count, created_at)
    VALUES ('7773002', pass, 'Мирлан (Комфорт)', 'DRIVER', 5.0, 5, NOW()) RETURNING id INTO uid2;
    
    INSERT INTO app_users (phone, password, full_name, role, rating, rating_count, created_at)
    VALUES ('7773003', pass, 'Бакыт (Бизнес)', 'DRIVER', 4.8, 20, NOW()) RETURNING id INTO uid3;
    
    INSERT INTO app_users (phone, password, full_name, role, rating, rating_count, created_at)
    VALUES ('7773004', pass, 'Улан (Эконом)', 'DRIVER', 4.7, 15, NOW()) RETURNING id INTO uid4;
    
    INSERT INTO app_users (phone, password, full_name, role, rating, rating_count, created_at)
    VALUES ('7773005', pass, 'Чынгыз (Комфорт)', 'DRIVER', 5.0, 2, NOW()) RETURNING id INTO uid5;

    -- Добавляем детализированную информацию (Машины KG и координаты в Бишкеке)
    -- Бишкек Центр: 42.8746, 74.5698
    INSERT INTO driver_details (user_id, car_model, car_number, car_class, status, current_lat, current_lon)
    VALUES (uid1, 'Toyota Camry 50', '01KG 123 ADG', 'ECONOMY', 'AVAILABLE', 42.8746, 74.5698);
    
    INSERT INTO driver_details (user_id, car_model, car_number, car_class, status, current_lat, current_lon)
    VALUES (uid2, 'Hyundai Sonata', '01KG 456 BEF', 'COMFORT', 'AVAILABLE', 42.8640, 74.5850);
    
    INSERT INTO driver_details (user_id, car_model, car_number, car_class, status, current_lat, current_lon)
    VALUES (uid3, 'Mercedes-Benz S-Class', '01KG 789 GHH', 'BUSINESS', 'AVAILABLE', 42.8820, 74.6000);
    
    INSERT INTO driver_details (user_id, car_model, car_number, car_class, status, current_lat, current_lon)
    VALUES (uid4, 'Honda Fit', '01KG 012 JKL', 'ECONOMY', 'AVAILABLE', 42.8500, 74.5500);
    
    INSERT INTO driver_details (user_id, car_model, car_number, car_class, status, current_lat, current_lon)
    VALUES (uid5, 'Toyota Prius', '01KG 345 MNO', 'COMFORT', 'AVAILABLE', 42.8900, 74.5700);

    RAISE NOTICE '5 drivers successfully created and scattered across Bishkek.';
END $$;
