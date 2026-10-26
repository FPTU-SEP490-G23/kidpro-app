@echo off
setlocal
chcp 65001 >nul
title KidPro - Setup USB Port Forwarding (adb reverse)
echo ========================================================
echo   KIDPRO - THIET LAP KET NOI MAY THAT QUA CAP USB (ADB)
echo ========================================================
echo.

:: Tim duong dan adb.exe
set "ADB_BIN="
where adb >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set "ADB_BIN=adb"
) else if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_BIN=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
) else if exist "D:\Android_SDK\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_BIN=D:\Android_SDK\Android\Sdk\platform-tools\adb.exe"
) else if exist "C:\Android\platform-tools\adb.exe" (
    set "ADB_BIN=C:\Android\platform-tools\adb.exe"
)

if "%ADB_BIN%"=="" (
    echo [LOI] Khong tim thay cong cu adb tren may tinh!
    echo Vui long kiem tra lai Android SDK hoac them vao bien moi truong PATH.
    pause
    exit /b 1
)

echo [1/3] Kiem tra thiet bi Android ket noi qua cap USB...
"%ADB_BIN%" devices -l
echo.

echo [2/3] Dang bat che do reverse port 8080 (Backend Spring Boot)...
"%ADB_BIN%" reverse tcp:8080 tcp:8080
if %ERRORLEVEL% equ 0 (
    echo     ==^> [OK] Da chuyen huong cong 8080 qua cap USB thanh cong!
) else (
    echo     ==^> [CANH BAO] Khong the reverse cong 8080. Hay dam bao da bat USB Debugging tren dien thoai.
)

echo [3/3] Dang bat che do reverse port 8000 (AI Server Face Attendance)...
"%ADB_BIN%" reverse tcp:8000 tcp:8000
if %ERRORLEVEL% equ 0 (
    echo     ==^> [OK] Da chuyen huong cong 8000 qua cap USB thanh cong!
)

echo.
echo ========================================================
echo   DANH SACH REVERSE PORT DANG HOAT DONG:
echo ========================================================
"%ADB_BIN%" reverse --list
echo.
echo ========================================================
echo [HUONG DAN SU DUNG APP TREN DIEN THOAI THAT]:
echo 1. Tren app dien thoai, tai man hinh Dang nhap:
echo    - Chon: "USB (127.0.0.1:8080)"
echo    - Bam nut "Kiem tra ket noi" de dam bao thanh cong.
echo 2. Doi voi man hinh Diem danh khuon mat AI:
echo    - URL chon: "http://127.0.0.1:8000"
echo ========================================================
echo.
pause
