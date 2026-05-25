# 🧪 Пошаговая инструкция по тестированию

## Вариант 1: Быстрый тест через curl (5 минут)

### Предварительные требования:
- Java 17+
- PostgreSQL запущен
- База данных создана

### Шаг 1: Запустить приложение
```bash
cd backend
mvn spring-boot:run
```

Дождаться сообщения:
```
Started TaxiApplication in X.XXX seconds
```

### Шаг 2: Проверить, что админ создан
В логах должно быть:
```
Admin user created: +996700000000 / admin123
```

### Шаг 3: Войти как админ
```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"phone\":\"+996700000000\",\"password\":\"admin123\"}"
```

**Ожидаемый результат:**
```json
{
  "token": "eyJhbGc...",
  "phone": "+996700000000",
  "role": "ADMIN",
  "fullName": "System Admin"
}
```

**Сохраните токен!** Он понадобится для следующих запросов.

### Шаг 4: Подать заявку водителя (публичный endpoint)
```bash
curl -X POST http://localhost:8080/api/driver-applications \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "Тестовый Водитель",
    "phone": "+996700000001",
    "email": "test.driver@example.com",
    "licenseNumber": "TEST123456",
    "licenseExpiry": "2027-12-31",
    "vehicleMake": "Toyota",
    "vehicleModel": "Camry",
    "vehicleYear": 2020,
    "vehiclePlate": "01TEST123",
    "carClass": "COMFORT",
    "notes": "Тестовая заявка"
  }'
```

**Ожидаемый результат:**
```json
{
  "id": 1,
  "fullName": "Тестовый Водитель",
  "phone": "+996700000001",
  "status": "PENDING",
  "submittedAt": "2026-05-11T16:35:00",
  ...
}
```

### Шаг 5: Посмотреть заявки (админ)
```bash
curl -X GET "http://localhost:8080/api/admin/driver-applications?status=PENDING" \
  -H "Authorization: Bearer ВАШ_ТОКЕН"
```

**Ожидаемый результат:**
```json
[
  {
    "id": 1,
    "fullName": "Тестовый Водитель",
    "status": "PENDING",
    ...
  }
]
```

### Шаг 6: Одобрить заявку
```bash
curl -X POST http://localhost:8080/api/admin/driver-applications/1/approve \
  -H "Authorization: Bearer ВАШ_ТОКЕН"
```

**Ожидаемый результат:**
```json
{
  "id": 1,
  "status": "APPROVED",
  "reviewedAt": "2026-05-11T16:36:00",
  "reviewedByName": "System Admin"
}
```

### Шаг 7: Активировать водителя
```bash
curl -X POST http://localhost:8080/api/admin/driver-applications/1/activate \
  -H "Authorization: Bearer ВАШ_ТОКЕН"
```

**Ожидаемый результат:**
```json
{
  "message": "Driver activated successfully",
  "driverId": 2,
  "phone": "+996700000001"
}
```

**В консоли приложения увидите:**
```
=== DRIVER ACTIVATED ===
Phone: +996700000001
Temporary Password: aB3dE7gH
========================
```

### Шаг 8: Проверить audit logs
```bash
curl -X GET http://localhost:8080/api/admin/audit-logs \
  -H "Authorization: Bearer ВАШ_ТОКЕН"
```

**Ожидаемый результат:**
```json
[
  {
    "id": 1,
    "adminPhone": "+996700000000",
    "action": "APPROVE_DRIVER_APPLICATION",
    "targetEntity": "DriverApplication:1",
    "performedAt": "2026-05-11T16:36:00"
  },
  {
    "id": 2,
    "adminPhone": "+996700000000",
    "action": "ACTIVATE_DRIVER",
    "targetEntity": "User:2",
    "details": "Activated driver from application #1, temp password: aB3dE7gH",
    "performedAt": "2026-05-11T16:37:00"
  }
]
```

### Шаг 9: Верифицировать документы водителя
```bash
curl -X POST http://localhost:8080/api/admin/drivers/2/verify-documents \
  -H "Authorization: Bearer ВАШ_ТОКЕН"
```

**Ожидаемый результат:**
```json
{
  "message": "Documents verified successfully",
  "driverId": 2
}
```

### Шаг 10: Проверить dashboard метрики
```bash
curl -X GET http://localhost:8080/api/admin/dashboard/metrics \
  -H "Authorization: Bearer ВАШ_ТОКЕН"
```

**Ожидаемый результат:**
```json
{
  "activeRides": 0,
  "searchingRides": 0,
  "onlineDrivers": 0,
  "totalUsers": 2,
  "totalDrivers": 1,
  "totalClients": 0
}
```

---

## Вариант 2: Тест через Postman (10 минут)

### Шаг 1: Импортировать коллекцию
1. Открыть Postman
2. File → Import
3. Выбрать файл `POSTMAN_COLLECTION.json`
4. Коллекция "AIS Taxi Admin Panel" появится в списке

### Шаг 2: Настроить переменные
1. Открыть коллекцию
2. Variables tab
3. Проверить `baseUrl = http://localhost:8080`

### Шаг 3: Запустить приложение
```bash
cd backend
mvn spring-boot:run
```

### Шаг 4: Выполнить запросы по порядку

**Папка 1: Authentication**
1. ✅ Login as Admin
   - Токен автоматически сохранится в переменную `adminToken`

**Папка 2: Driver Applications (Public)**
2. ✅ Submit Driver Application
3. ✅ Get Application Status

**Папка 3: Admin - Dashboard**
4. ✅ Get Dashboard Metrics

**Папка 4: Admin - Driver Applications**
5. ✅ Get All Applications
6. ✅ Get Pending Applications
7. ✅ Get Application by ID
8. ✅ Approve Application
9. ✅ Activate Driver (смотрите консоль для временного пароля)

**Папка 5: Admin - Driver Management**
10. ✅ Verify Driver Documents
11. ✅ Terminate Driver (опционально)
12. ✅ Reactivate Driver (если терминировали)

**Папка 6: Admin - User Management**
13. ✅ Get All Users
14. ✅ Get Drivers Only
15. ✅ Ban User (Temporary)
16. ✅ Unban User

**Папка 7: Admin - Audit Logs**
17. ✅ Get All Audit Logs
18. ✅ Get Logs by Action

---

## Вариант 3: Автоматический тест (Newman)

### Установить Newman
```bash
npm install -g newman
```

### Запустить тесты
```bash
newman run POSTMAN_COLLECTION.json \
  --environment postman-environment.json \
  --reporters cli,json
```

---

## Проверка базы данных

### Подключиться к PostgreSQL
```bash
psql -U postgres -d taxi_db
```

### Проверить созданные таблицы
```sql
-- Проверить заявки водителей
SELECT id, full_name, phone, status, submitted_at 
FROM driver_applications;

-- Проверить пользователей
SELECT id, phone, full_name, role, enabled, is_documents_verified 
FROM app_users;

-- Проверить детали водителей
SELECT user_id, car_model, car_number, car_class, status 
FROM driver_details;

-- Проверить audit logs
SELECT id, action, target_entity, details, performed_at 
FROM admin_action_logs 
ORDER BY performed_at DESC;

-- Проверить историю банов
SELECT id, user_id, reason, banned_at, unbanned_at 
FROM user_bans;
```

---

## Ожидаемые результаты

### ✅ Успешный сценарий:

1. **Админ создан автоматически** при старте приложения
2. **Заявка подана** → статус PENDING
3. **Заявка одобрена** → статус APPROVED, reviewedAt заполнен
4. **Водитель активирован** → создан User (id=2) + DriverDetails
5. **Временный пароль** выведен в консоль
6. **Документы верифицированы** → isDocumentsVerified = true
7. **Все действия залогированы** в admin_action_logs

### ❌ Возможные ошибки:

**Ошибка 1: Connection refused**
```
Error: connect ECONNREFUSED 127.0.0.1:8080
```
**Решение:** Приложение не запущено. Запустить `mvn spring-boot:run`

**Ошибка 2: 401 Unauthorized**
```json
{"error": "Unauthorized"}
```
**Решение:** Токен не передан или истек. Получить новый токен через `/auth/login`

**Ошибка 3: Phone number already registered**
```json
{"error": "Phone number already registered"}
```
**Решение:** Использовать другой номер телефона или очистить базу данных

**Ошибка 4: Application not found**
```json
{"error": "Application not found"}
```
**Решение:** Проверить ID заявки в базе данных

**Ошибка 5: Application cannot be approved in current status**
```json
{"error": "Application cannot be approved in current status: APPROVED"}
```
**Решение:** Заявка уже одобрена, нельзя одобрить повторно

---

## Проверка функционала по чек-листу

### Система заявок водителей
- [ ] Публичная подача заявки работает без токена
- [ ] Дубликаты телефонов отклоняются
- [ ] Дубликаты номеров авто отклоняются
- [ ] Админ видит список заявок
- [ ] Админ может фильтровать по статусу
- [ ] Админ может одобрить заявку
- [ ] Админ может отклонить заявку с причиной
- [ ] Статус заявки меняется корректно

### Активация водителей
- [ ] Активация создает User с ролью DRIVER
- [ ] Активация создает DriverDetails
- [ ] Генерируется временный пароль (8 символов)
- [ ] Пароль выводится в консоль
- [ ] Заявка связывается с созданным User
- [ ] Повторная активация блокируется

### Управление водителями
- [ ] Верификация документов работает
- [ ] Отклонение документов с причиной работает
- [ ] Терминация водителя работает
- [ ] Реактивация водителя работает
- [ ] Терминированный водитель не может войти

### Audit logging
- [ ] Все действия админа логируются
- [ ] Логи содержат adminId, action, targetEntity
- [ ] Логи можно фильтровать по админу
- [ ] Логи можно фильтровать по типу действия
- [ ] Временные метки корректны

### Безопасность
- [ ] Публичные endpoints работают без токена
- [ ] Admin endpoints требуют токен
- [ ] Admin endpoints требуют роль ADMIN
- [ ] Невалидный токен отклоняется
- [ ] Истекший токен отклоняется

---

## Следующие шаги после проверки

1. ✅ Если все работает → можно пушить в репозиторий
2. ⚠️ Если есть ошибки → исправить и повторить тест
3. 📝 Добавить unit тесты (см. NEXT_STEPS_PLAN.md)
4. 🚀 Развернуть на тестовом сервере

---

**Создано:** 2026-05-11T16:34:44Z
**Время тестирования:** ~10-15 минут
**Требуется:** Java 17+, PostgreSQL, Maven
