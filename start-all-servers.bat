@echo off
chcp 65001 >nul
title KidPro - Quan ly Khoi dong Backend & AI Server

:MENU
cls
echo ========================================================
echo        KIDPRO - KHOI DONG BACKEND VA AI SERVER
echo ========================================================
echo.
echo [Thong tin mang LAN Wi-Fi hien tai cua Laptop]:
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address" /c:"IPv4" /c:"Dia chi IPv4"') do (
    echo   ==^> IP Wi-Fi: %%a
)
echo.
echo   Spring Boot Backend : http://192.168.10.51:8080
echo   Python AI Server    : http://192.168.10.51:8000
echo.
echo ========================================================
echo   [1] Khoi dong TAT CA (Spring Boot + Python AI)
echo   [2] Khoi dong chi Spring Boot Backend (Port 8080)
echo   [3] Khoi dong chi Python AI Server (Port 8000)
echo   [4] Mo Windows Firewall (Port 8080 & 8000)
echo   [5] Kiem tra trang thai Ports (8080 & 8000)
echo   [6] Thoat
echo ========================================================
set /p choice="Nhap lua chon cua ban (1-6): "

if "%choice%"=="1" goto START_ALL
if "%choice%"=="2" goto START_BE
if "%choice%"=="3" goto START_AI
if "%choice%"=="4" goto OPEN_FW
if "%choice%"=="5" goto CHECK_PORTS
if "%choice%"=="6" exit /b
goto MENU

:START_ALL
echo.
echo [1/2] Dang khoi dong Spring Boot Backend trong cua so moi...
start "KidPro - Spring Boot Backend (Port 8080)" cmd /k "title Spring Boot (8080) && cd /d D:\KidPro\KidPro_BE\kidpro-be && .\mvnw.cmd spring-boot:run"

echo [2/2] Dang khoi dong Python AI Server trong cua so moi...
start "KidPro - Face Attendance AI Engine (Port 8000)" cmd /k "title AI Engine (8000) && cd /d d:\kidpro_app\kidpro-app\ai_backend && (if exist venv\Scripts\activate.bat call venv\Scripts\activate.bat) && python main.py"

echo.
echo ========================================================
echo [DA MO 2 CUA SO SERVER!]
echo 1. Hay doi khoang 15-30 giay de ca 2 server khoi dong xong.
echo 2. Cua so Spring Boot bao: 'Started KidProBackendApplication'.
echo 3. Cua so AI Server bao: 'Uvicorn running on http://0.0.0.0:8000'.
echo 4. Sau do tren App dien thoai, bam nut 'Kiem tra ket noi'!
echo ========================================================
pause
goto MENU

:START_BE
echo.
echo Dang khoi dong Spring Boot Backend...
start "KidPro - Spring Boot Backend (Port 8080)" cmd /k "title Spring Boot (8080) && cd /d D:\KidPro\KidPro_BE\kidpro-be && .\mvnw.cmd spring-boot:run"
pause
goto MENU

:START_AI
echo.
echo Dang khoi dong Python AI Server...
start "KidPro - Face Attendance AI Engine (Port 8000)" cmd /k "title AI Engine (8000) && cd /d d:\kidpro_app\kidpro-app\ai_backend && (if exist venv\Scripts\activate.bat call venv\Scripts\activate.bat) && python main.py"
pause
goto MENU

:OPEN_FW
call open-firewall-rules.bat
goto MENU

:CHECK_PORTS
echo.
echo [Kiem tra trang thai Ports tren Laptop]:
echo --------------------------------------------------------
netstat -ano | findstr ":8080 :8000"
if %ERRORLEVEL% equ 0 (
    echo   ==^> Ports 8080 / 8000 DANG HOAT DONG!
) else (
    echo   ==^> CHUA CO SERVER NAO CHAY tren cong 8080 hoac 8000!
)
echo --------------------------------------------------------
pause
goto MENU
