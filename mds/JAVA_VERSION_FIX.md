# ⚠️ КРИТИЧЕСКАЯ ПРОБЛЕМА: Java 8 вместо Java 17+

## Проблема обнаружена

```
Java version: 1.8.0_401
```

**Spring Boot 3.x требует Java 17 или выше!**

Ваш проект использует:
- Spring Boot 3.3.0 (из pom.xml)
- Требуется: Java 17+
- Установлено: Java 8

---

## ✅ РЕШЕНИЕ: Установить Java 17

### Вариант 1: Через Chocolatey (БЫСТРО)

```powershell
# Установить OpenJDK 17
choco install openjdk17

# Или Oracle JDK 17
choco install oraclejdk17
```

### Вариант 2: Вручную

1. **Скачать Java 17:**
   - OpenJDK: https://adoptium.net/temurin/releases/?version=17
   - Oracle JDK: https://www.oracle.com/java/technologies/downloads/#java17

2. **Установить** (выбрать путь, например `C:\Program Files\Java\jdk-17`)

3. **Настроить JAVA_HOME:**
   ```powershell
   # Установить JAVA_HOME
   [Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Java\jdk-17", "Machine")
   
   # Добавить в PATH
   $javaPath = "C:\Program Files\Java\jdk-17\bin"
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$javaPath", "Machine")
   ```

4. **Перезапустить PowerShell**

5. **Проверить:**
   ```powershell
   java -version
   ```
   
   Должно показать:
   ```
   openjdk version "17.0.x"
   ```

---

## Вариант 3: Использовать существующую Java 17 (если установлена)

### Проверить все установленные версии Java:

```powershell
Get-ChildItem "C:\Program Files\Java" | Select-Object Name
```

### Если Java 17 уже есть:

```powershell
# Установить JAVA_HOME на Java 17
$jdk17Path = "C:\Program Files\Java\jdk-17"  # Замените на реальный путь
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk17Path, "User")

# Перезапустить PowerShell
exit
```

---

## После установки Java 17

### 1. Проверить версию:
```powershell
java -version
mvnd --version
```

Должно показать Java 17.x.x

### 2. Запустить приложение:
```powershell
cd D:\projects_shit\ais_taxi\backend
mvnd spring-boot:run
```

### 3. Если всё равно использует Java 8:

```powershell
# Явно указать JAVA_HOME для mvnd
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
mvnd spring-boot:run
```

---

## Временное решение (без установки Java 17)

Если не можете установить Java 17 прямо сейчас, можно:

### Вариант A: Понизить версию Spring Boot до 2.7.x

Изменить в `pom.xml`:
```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>2.7.18</version>  <!-- Вместо 3.3.0 -->
    <relativePath/>
</parent>
```

**НО:** Это не рекомендуется, так как код написан для Spring Boot 3.x

### Вариант B: Использовать Docker

```powershell
# Создать Dockerfile в backend/
docker build -t ais-taxi-backend .
docker run -p 8080:8080 ais-taxi-backend
```

---

## Проверка после установки

```powershell
# 1. Проверить Java
java -version
# Ожидается: openjdk version "17.0.x" или java version "17.0.x"

# 2. Проверить JAVA_HOME
echo $env:JAVA_HOME
# Ожидается: C:\Program Files\Java\jdk-17

# 3. Проверить mvnd
mvnd --version
# Ожидается: Java version: 17.0.x

# 4. Запустить приложение
cd D:\projects_shit\ais_taxi\backend
mvnd spring-boot:run
```

---

## Быстрая установка (копировать целиком)

```powershell
# Установить OpenJDK 17 через Chocolatey
choco install openjdk17 -y

# Обновить переменные окружения
refreshenv

# Проверить
java -version

# Запустить приложение
cd D:\projects_shit\ais_taxi\backend
mvnd spring-boot:run
```

---

## Если Chocolatey не установлен

### Установить Chocolatey:
```powershell
# Запустить PowerShell от имени администратора
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### Затем установить Java:
```powershell
choco install openjdk17 -y
```

---

## Ошибки, которые вы увидите с Java 8

```
Unsupported class file major version 61
```

или

```
java.lang.UnsupportedClassVersionError
```

Это означает, что код скомпилирован для Java 17, а запускается на Java 8.

---

## ✅ ИТОГО: Что нужно сделать

1. **Установить Java 17** (через Chocolatey или вручную)
2. **Настроить JAVA_HOME** на Java 17
3. **Перезапустить PowerShell**
4. **Проверить:** `java -version` → должно быть 17.x.x
5. **Запустить:** `mvnd spring-boot:run`

---

**Создано:** 2026-05-11T16:50:40Z
**Приоритет:** КРИТИЧЕСКИЙ
**Без Java 17 приложение не запустится!**
