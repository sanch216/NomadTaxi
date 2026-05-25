# 🔧 Решение проблемы с Maven

## Проблема
У вас установлен **maven-mvnd** (daemon версия), но нет стандартного Maven или Maven wrapper.

## Решение 1: Использовать mvnd (БЫСТРО - рекомендуется)

Maven Daemon (mvnd) - это более быстрая версия Maven. Можно использовать его вместо mvn.

### Запустить приложение:
```powershell
cd D:\projects_shit\ais_taxi\backend
mvnd spring-boot:run
```

### Скомпилировать:
```powershell
mvnd clean compile
```

### Запустить тесты:
```powershell
mvnd test
```

**mvnd работает точно так же как mvn, но быстрее!**

---

## Решение 2: Установить стандартный Maven

### Вариант A: Через Chocolatey (если установлен)
```powershell
choco install maven
```

### Вариант B: Вручную
1. Скачать Maven с https://maven.apache.org/download.cgi
2. Распаковать в `C:\Program Files\Apache\maven`
3. Добавить в PATH:
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Apache\maven\bin", "Machine")
   ```
4. Перезапустить PowerShell
5. Проверить: `mvn --version`

---

## Решение 3: Создать Maven Wrapper (для проекта)

Если у вас есть доступ к Maven на другой машине или через mvnd:

```powershell
# Используя mvnd для создания wrapper
cd D:\projects_shit\ais_taxi\backend
mvnd wrapper:wrapper
```

Это создаст файлы:
- `mvnw.cmd` (для Windows)
- `mvnw` (для Linux/Mac)
- `.mvn/wrapper/` (конфигурация)

После этого можно использовать:
```powershell
.\mvnw.cmd spring-boot:run
```

---

## ✅ РЕКОМЕНДАЦИЯ: Используйте mvnd

Поскольку mvnd уже установлен и работает, просто используйте его:

```powershell
# Перейти в backend
cd D:\projects_shit\ais_taxi\backend

# Запустить приложение
mvnd spring-boot:run

# Или скомпилировать
mvnd clean install -DskipTests
```

**mvnd = Maven Daemon = Быстрая версия Maven**
- Совместим со всеми Maven командами
- Работает быстрее обычного Maven
- Использует daemon процесс для ускорения

---

## Проверка установки

### Проверить mvnd:
```powershell
mvnd --version
```

Должно показать:
```
Apache Maven Daemon (mvnd) 1.0.5
Maven home: D:\dev\maven-mvnd-1.0.5-windows-amd64\...
Java version: 17.x.x
```

### Проверить Java:
```powershell
java -version
```

Должно быть Java 17 или выше.

---

## Быстрый старт с mvnd

```powershell
# 1. Перейти в backend
cd D:\projects_shit\ais_taxi\backend

# 2. Запустить приложение
mvnd spring-boot:run

# 3. Дождаться сообщения:
# "Started TaxiApplication in X.XXX seconds"

# 4. Тестировать API
# См. TESTING_GUIDE.md или QUICK_START.md
```

---

## Если mvnd не работает

### Проверить PATH:
```powershell
$env:PATH -split ';' | Select-String -Pattern 'mvnd'
```

### Добавить в PATH (если нужно):
```powershell
$mvndPath = "D:\dev\maven-mvnd-1.0.5-windows-amd64\maven-mvnd-1.0.5-windows-amd64\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$mvndPath", "User")
```

### Перезапустить PowerShell и проверить:
```powershell
mvnd --version
```

---

## Альтернатива: Запуск через IDE

Если ничего не работает, можно запустить через IntelliJ IDEA:

1. Открыть проект в IntelliJ IDEA
2. Найти класс `TaxiApplication.java`
3. Нажать правой кнопкой → Run 'TaxiApplication'
4. Приложение запустится на порту 8080

---

**Создано:** 2026-05-11T16:49:40Z
**Рекомендация:** Используйте `mvnd` вместо `mvn`
