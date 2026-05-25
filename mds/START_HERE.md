# ⚡ ФИНАЛЬНАЯ ИНСТРУКЦИЯ ПО ЗАПУСКУ

## 🚨 ВАЖНО: Обнаружены проблемы

### Проблема 1: Java 8 вместо Java 17+
**Статус:** ❌ КРИТИЧЕСКАЯ  
**Решение:** Установить Java 17

### Проблема 2: Maven wrapper отсутствует
**Статус:** ✅ РЕШЕНА (используйте mvnd)

---

## 🎯 ШАГ ЗА ШАГОМ (5 минут)

### Шаг 1: Установить Java 17

**Быстрый способ (Chocolatey):**
```powershell
# Запустить PowerShell от имени администратора
choco install openjdk17 -y
refreshenv
```

**Проверить:**
```powershell
java -version
```

Должно показать: `openjdk version "17.0.x"`

---

### Шаг 2: Запустить приложение

```powershell
# Перейти в backend
cd D:\projects_shit\ais_taxi\backend

# Запустить через mvnd (уже установлен у вас)
mvnd spring-boot:run
```

**Ожидаемый вывод:**
```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v3.3.0)

...
Admin user created: +996700000000 / admin123
...
Started TaxiApplication in 8.234 seconds
```

---

### Шаг 3: Проверить, что работает

**Открыть новый PowerShell и выполнить:**

```powershell
# Войти как админ
curl -X POST http://localhost:8080/auth/login `
  -H "Content-Type: application/json" `
  -d '{\"phone\":\"+996700000000\",\"password\":\"admin123\"}'
```

**Ожидаемый результат:**
```json
{
  "token": "eyJhbGc...",
  "phone": "+996700000000",
  "role": "ADMIN"
}
```

✅ **Если получили токен - всё работает!**

---

## 🔧 Если что-то не работает

### Ошибка: "mvnd: command not found"

**Решение:**
```powershell
# Проверить путь к mvnd
$env:PATH -split ';' | Select-String -Pattern 'mvnd'

# Если не найден, добавить:
$mvndPath = "D:\dev\maven-mvnd-1.0.5-windows-amd64\maven-mvnd-1.0.5-windows-amd64\bin"
$env:PATH += ";$mvndPath"

# Проверить:
mvnd --version
```

### Ошибка: "Unsupported class file major version 61"

**Причина:** Используется Java 8 вместо Java 17

**Решение:**
```powershell
# Установить Java 17
choco install openjdk17 -y

# Перезапустить PowerShell
exit

# Проверить
java -version
```

### Ошибка: "Connection refused" при тестировании

**Причина:** Приложение не запущено или запускается на другом порту

**Решение:**
```powershell
# Проверить, что приложение запущено
# В логах должно быть: "Started TaxiApplication"

# Проверить порт
netstat -ano | findstr :8080
```

### Ошибка: База данных не подключается

**Проверить PostgreSQL:**
```powershell
# Проверить, что PostgreSQL запущен
Get-Service -Name postgresql*

# Если не запущен:
Start-Service postgresql-x64-14  # Замените на вашу версию
```

**Проверить настройки в `application.properties`:**
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/taxi_db
spring.datasource.username=postgres
spring.datasource.password=ваш_пароль
```

---

## 📋 Полный чек-лист запуска

- [ ] Java 17 установлена (`java -version`)
- [ ] PostgreSQL запущен
- [ ] База данных `taxi_db` создана
- [ ] mvnd работает (`mvnd --version`)
- [ ] Приложение запущено (`mvnd spring-boot:run`)
- [ ] Админ создан (в логах: "Admin user created")
- [ ] API отвечает (curl на `/auth/login`)

---

## 🚀 После успешного запуска

### Вариант 1: Тестирование через curl
См. **QUICK_START.md**

### Вариант 2: Тестирование через Postman
1. Импортировать `POSTMAN_COLLECTION.json`
2. Выполнить запросы по порядку
3. См. **TESTING_GUIDE.md**

---

## 📚 Документация

| Файл | Описание |
|------|----------|
| **QUICK_START.md** | Шпаргалка для быстрого старта |
| **TESTING_GUIDE.md** | Полная инструкция по тестированию |
| **JAVA_VERSION_FIX.md** | Решение проблемы с Java 8 |
| **MAVEN_SETUP_FIX.md** | Решение проблемы с Maven |
| **ADMIN_PANEL_SUMMARY.md** | Обзор реализации |
| **CODE_VERIFICATION_REPORT.md** | Отчет о проверке кода |
| **NEXT_STEPS_PLAN.md** | План дальнейшей разработки |

---

## ⏱️ Время выполнения

- **Установка Java 17:** 2-3 минуты
- **Первый запуск приложения:** 1-2 минуты
- **Тестирование API:** 5-10 минут
- **Итого:** ~10-15 минут

---

## 💡 Полезные команды

```powershell
# Запустить приложение
mvnd spring-boot:run

# Остановить приложение
Ctrl+C

# Скомпилировать без запуска
mvnd clean compile

# Запустить тесты (когда будут написаны)
mvnd test

# Собрать JAR файл
mvnd clean package -DskipTests

# Запустить JAR
java -jar target/backend-0.0.1-SNAPSHOT.jar
```

---

## 🎉 Готово!

После выполнения всех шагов у вас будет:

✅ Работающее приложение на http://localhost:8080  
✅ Админ-панель с 21 endpoint  
✅ Система заявок водителей  
✅ Управление жизненным циклом водителей  
✅ Audit logging  
✅ Dashboard с метриками  

**Можно тестировать и разрабатывать дальше!**

---

**Создано:** 2026-05-11T16:52:52Z  
**Последнее обновление:** 2026-05-11T16:52:52Z  
**Статус:** Готово к запуску после установки Java 17
