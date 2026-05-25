# JDK Installation Required

## Problem
Maven compilation fails with error: "No compiler is provided in this environment. Perhaps you are running on a JRE rather than a JDK?"

This means only Java Runtime Environment (JRE) is installed, but Java Development Kit (JDK) is required for compilation.

## Solution

### Option 1: Install JDK 17 via Chocolatey (Recommended)

1. Install Chocolatey if not installed:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

2. Install OpenJDK 17:
```powershell
choco install openjdk17 -y
```

3. Set JAVA_HOME environment variable:
```powershell
[System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\OpenJDK\jdk-17', [System.EnvironmentVariableTarget]::Machine)
```

4. Restart terminal and verify:
```powershell
java -version
javac -version
```

### Option 2: Manual Installation

1. Download JDK 17 from:
   - Oracle: https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html
   - Eclipse Temurin: https://adoptium.net/temurin/releases/?version=17

2. Install to default location (e.g., `C:\Program Files\Java\jdk-17`)

3. Set JAVA_HOME:
   - Open System Properties → Environment Variables
   - Add new System Variable:
     - Name: `JAVA_HOME`
     - Value: `C:\Program Files\Java\jdk-17` (or your installation path)

4. Add to PATH:
   - Edit System Variable `Path`
   - Add: `%JAVA_HOME%\bin`

5. Restart terminal and verify:
```powershell
java -version
javac -version
```

### Option 3: Use Existing JDK (if already installed elsewhere)

If JDK is already installed but not in PATH:

1. Find JDK location:
```powershell
Get-ChildItem -Path "C:\Program Files" -Filter "jdk*" -Recurse -ErrorAction SilentlyContinue -Directory
```

2. Set JAVA_HOME to that location

## After Installation

Run compilation again:
```bash
cd backend
mvnd compile -DskipTests
```

## Current Status

- JRE is installed (java command works)
- JDK is NOT installed (javac compiler not found)
- JAVA_HOME is not set
- Compilation cannot proceed until JDK is installed

## Next Steps

1. Install JDK 17 using one of the options above
2. Verify installation with `javac -version`
3. Run `mvnd compile -DskipTests` to compile the project
